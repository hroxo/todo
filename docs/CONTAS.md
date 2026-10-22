# Ligar contas Google e Outlook

A app pode ler o calendário diretamente da Google e da Microsoft (Definições › Calendário › Contas Google e Outlook), além das contas que já estão no iPhone. Para isso, a app tem de estar registada em cada serviço. O registo é gratuito e faz-se uma vez.

Os identificadores de cliente não são segredos: a app usa OAuth com PKCE, como qualquer app nativa, sem segredo de cliente. Copiam-se para `App/Contas/RegistoApps.swift`.

## Google

1. Abrir a [Google Cloud Console](https://console.cloud.google.com/) e criar um projeto (por exemplo, "ToDo").
2. **APIs e serviços › Biblioteca**: ativar a **Google Calendar API**.
3. **APIs e serviços › Ecrã de consentimento OAuth**:
   - Tipo de utilizador: **Externo**.
   - Nome da app "ToDo", o teu email como apoio e como contacto.
   - Âmbitos: `openid`, `email` e `.../auth/calendar.readonly`.
   - **Utilizadores de teste**: acrescentar o teu email Google.
4. **APIs e serviços › Credenciais › Criar credenciais › ID de cliente OAuth**:
   - Tipo de aplicação: **iOS**.
   - ID do pacote: `com.hugo.todo`.
5. Copiar o **ID de cliente** (`123-abc.apps.googleusercontent.com`) para `googleClientId`.

> Enquanto o ecrã de consentimento estiver em modo **Teste**, a Google pede para voltar a ligar a conta de 7 em 7 dias (o mesmo ritmo da reassinatura). Para não expirar, publicar a app ("Em produção"): a Google mostra um aviso de "app não verificada" no login, mas funciona para uso pessoal.

## Microsoft (Outlook, Hotmail, Microsoft 365)

1. Abrir o [Microsoft Entra](https://entra.microsoft.com/) (ou o portal do Azure) com a conta Microsoft.
2. **Aplicações › Registos de aplicações › Novo registo**:
   - Nome "ToDo".
   - Tipos de conta suportados: **Contas em qualquer diretório organizacional e contas Microsoft pessoais**.
   - URI de redirecionamento: plataforma **Cliente público/nativo (móvel e ambiente de trabalho)**, `todo-hugo://auth`.
3. **Permissões de API**: confirmar que estão `User.Read`, e acrescentar **Microsoft Graph › Permissões delegadas › `Calendars.Read`** e `offline_access`.
4. **Autenticação**: em "Definições avançadas", **Permitir fluxos de cliente público: Sim**.
5. Copiar o **ID da aplicação (cliente)** (`00000000-1111-…`) para `microsoftClientId`.

> Numa conta de trabalho, o administrador da empresa pode ter de autorizar a app. Se o login disser "precisa de aprovação do administrador", fica a leitura pelo EventKit (Ajustes › Calendário › Contas).

## Depois

1. Fazer commit de `App/Contas/RegistoApps.swift` e push; o CI publica o `.ipa` novo.
2. Instalar com o iloader e, na app, **Definições › Calendário › Contas Google e Outlook › Ligar**.
3. Os calendários da conta aparecem em Definições › Calendários, cada um com o seu espaço (ou sem espaço, ou escondido).

Se a mesma conta também estiver no iPhone (Ajustes › Calendário › Contas), cada evento aparece uma só vez: fica a versão lida diretamente, que traz mais detalhes (participantes, link da reunião).
