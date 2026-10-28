# O dia da conta Apple Developer

Guia passo a passo para passar do `.ipa` sem assinatura (iloader, 7 dias) para a conta paga:
TestFlight, App Group a sério (widget com dados), iCloud contínuo (CloudKit) e iniciar sessão
com a Apple. A app e o CI já estão preparados; quase tudo aqui é clicar e colar.

Identificadores usados no projeto:

| O quê | Identificador |
| --- | --- |
| App | `com.hugo.todo` |
| Widget | `com.hugo.todo.widgets` |
| App Group | `group.com.hugo.todo` |
| Contentor iCloud | `iCloud.com.hugo.todo` |

## 0. Antes de tudo: exportar um backup

Na app instalada pelo iloader: **Definições › Backup › Exportar backup agora** e guardar o
ficheiro no iCloud Drive. A app nova (outra assinatura) pode não ver os dados da antiga.

## 1. Portal da Apple (developer.apple.com › Certificates, Identifiers & Profiles)

1. **Identifiers › App Groups › +**: `group.com.hugo.todo`.
2. **Identifiers › iCloud Containers › +**: `iCloud.com.hugo.todo`.
3. **Identifiers › App IDs › +** `com.hugo.todo`, com as capacidades:
   - App Groups → `group.com.hugo.todo`
   - iCloud → CloudKit → `iCloud.com.hugo.todo`
   - Push Notifications (o CloudKit usa-as para avisar de mudanças)
   - Sign in with Apple
4. **App IDs › +** `com.hugo.todo.widgets`, com App Groups → `group.com.hugo.todo`.
5. Anotar o **Team ID** (Membership).

## 2. App Store Connect (appstoreconnect.apple.com)

1. **Apps › +**: nova app iOS, nome "ToDo", bundle `com.hugo.todo`, SKU `todo`.
2. **Users and Access › Integrations › App Store Connect API › +**: chave com o papel
   **Admin** (precisa de criar certificados e perfis na nuvem). Descarregar o `.p8` (só dá
   uma vez) e anotar o **Key ID** e o **Issuer ID**.

## 3. Secrets do GitHub (repositório › Settings › Secrets and variables › Actions)

| Secret | Valor |
| --- | --- |
| `APPLE_TEAM_ID` | o Team ID |
| `ASC_KEY_ID` | o Key ID |
| `ASC_ISSUER_ID` | o Issuer ID |
| `ASC_KEY_P8` | o conteúdo do `.p8` em base64: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

## 4. Ligar as capacidades no projeto

No `project.yml`, nas `entitlements` do target `ToDo`, descomentar (estão escritas por cima):

```yaml
com.apple.developer.icloud-container-identifiers: [iCloud.com.hugo.todo]
com.apple.developer.icloud-services: [CloudKit]
aps-environment: production
com.apple.developer.applesignin: [Default]
```

e juntar `UIBackgroundModes: [remote-notification]` às propriedades do `Info.plist`. Também
`DEVELOPMENT_TEAM: <Team ID>` nas `settings.base` dos dois targets. Commit e push.

## 5. Primeira versão no TestFlight

GitHub › Actions › **TestFlight** › Run workflow. O workflow assina com a chave da API (a
Apple cria o certificado e os perfis sozinha), arquiva e envia. Em App Store Connect ›
TestFlight, a versão aparece ao fim de uns minutos; juntar-se como testador interno e
instalar a app TestFlight no iPhone.

## 6. Publicar a estrutura dos dados no iCloud (o passo que costuma falhar)

O TestFlight usa o ambiente de **produção** do CloudKit, que só aceita uma estrutura (tipos
de registo) publicada a partir do ambiente de **desenvolvimento**. Sem este passo, a
sincronização falha em silêncio.

1. No Mac, com o Xcode e a conta paga: correr uma compilação de desenvolvimento (Debug,
   assinada com a equipa) no simulador, com sessão iniciada no iCloud nos Ajustes do simulador.
2. Na app: **Definições › Programador › Criar estrutura no iCloud** (só existe em Debug).
3. Em icloud.developer.apple.com › CloudKit Console › `iCloud.com.hugo.todo` › Schema:
   confirmar os tipos `CD_Lista`, `CD_Item` e `CD_Foto` e carregar em **Deploy Schema
   Changes** para produção.
4. Repetir os passos 1 a 3 sempre que o esquema mudar (EsquemaV7…).

## 7. Restaurar e testar

1. Instalar pelo TestFlight, abrir, e (opcional) iniciar sessão com a Apple.
2. **Definições › Backup › Restaurar de um ficheiro** com o backup do passo 0.
3. Pôr o widget no ecrã principal: deve mostrar os pontos (App Group).
4. Sincronização: criar um ponto, apagar a app, reinstalar pelo TestFlight; o ponto volta
   ao fim de uns segundos. Com outro aparelho na mesma conta iCloud, aparece lá também.
5. Atualizar `docs/PROGRESSO.md` e o `CLAUDE.md` (12.2): o iloader deixa de ser o caminho.
