# Arquitetura

Visão técnica do ToDo para quem vai mexer no código. O desenho visual está em [`design/DESIGN.md`](../design/DESIGN.md); o dia da conta Apple paga está em [`CONTA-DEVELOPER.md`](CONTA-DEVELOPER.md).

## Camadas

```
App/ (SwiftUI)              ──usa──▶  Packages/ToDoCore (Swift puro + SwiftData)
  Ecras/         ecrãs                   Modelos.swift      Lista, Item, Foto, enums (esquema V6)
  Componentes/   peças reutilizáveis     Tarefas.swift      operações e regras (expiração, listas vazias…)
  Contas/        OAuth, Keychain, Apple  BaseDados.swift    esquemas V1–V6, migrações, contentor
  Inteligencia/  modelo do iPhone        Prazo.swift        tempo restante, rótulos, anel
  Calendario     EventKit + externos     Definicoes.swift   durações e avisos (UserDefaults)
  Notificacoes   avisos + widget         TextoAviso.swift   textos dos avisos
  Backups        ficheiros e iCloud      ParaTi.swift       cartão "Para ti" do Início
  Demo           dados de exemplo        ResumoWidget.swift prioridades e resumo para o widget
                                         TemaMascote.swift  tema da Ampulheta (trabalho, pessoal, viagem…)
Widgets/ (extensão WidgetKit)            Partilha.swift     vista partilhada em ficheiro .todolista
  ToDoWidgets    widgets e controlo      Backup.swift       formato JSON e restauro
  VistaWidget    vistas (também na app)  Filtro/Exportador/Espacos/Navegacao/OAuth/Reunioes…
  Mascote        a Ampulheta (Canvas)
  Intents        concluir, nova nota
```

A UI não contém regras: chama `Tarefas` (que recebe `ModelContext`, `Relogio` e `Definicoes`). O núcleo compila e testa-se sem simulador (`swift test` em `Packages/ToDoCore`).

## Projeto (XcodeGen)

`project.yml` gera o `ToDo.xcodeproj`, os `Info.plist` e as `.entitlements` (todos fora do git). Ao criar um ficheiro novo, correr `xcodegen generate`.

- **Target `ToDo`** (app, iOS 26). Declara:
  - o tipo `.todolista` (`UTExportedTypeDeclarations` e `CFBundleDocumentTypes`);
  - o esquema de URL `todo://` (`todo://captura` abre a captura);
  - o App Group `group.com.hugo.todo`.
  - As capacidades da conta paga (iCloud/CloudKit, `aps-environment`, Sign in with Apple) estão escritas e comentadas.
- **Target `ToDoWidgets`** (app-extension, embutida na app). A app também compila `Widgets/VistaWidget.swift`, `Mascote.swift` e `Intents.swift`, para o ecrã de demo e para os intents.
- **Versão:** `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` (o CI usa o número da execução).

## Modelo de dados (esquema V6, pronto para o CloudKit)

- **Lista** (um "espaço"): `id`, `nome`, `corRaw`, `ordem`, `icone`, `emoji?`, `tipoRaw` (`normal` | `compras`, que na UI é a "vista partilhada"), `partilhaId?`, `permanente`, `vaziaDesde?`, `itensGuardados` (cascade).
- **Item**: `titulo`, `tipoRaw` (`tarefa` | `notaRapida`), `estadoRaw` (`ativo` | `concluido` | `expirado`), `fixado`, `criadoEm`, `ultimaAcaoEm`, `alteradoEm?`, `apagadoEm?`, `expiraEm?`, `expiradoEm?`, `concluidoEm?`, `ordem`, `nota?`, `eventoId?`, `eventoInicio?`, `lista?`, `pai?`, `subtopicosGuardados`, `fotosGuardadas` (cascade).
  - **Principal e subtópico:** o principal tem `lista` e não tem `pai`. O subtópico tem `pai` e não tem `lista` (usa `listaEfetiva`). Só há um nível.
  - **Lápides:** `apagadoEm` marca um ponto apagado numa vista partilhada, para a fusão não o ressuscitar. `itensAtivos` e `subtopicosOrdenados` escondem as lápides.
- **Foto**: `dados` (`externalStorage`, JPEG reduzido), `ordem`, `criadaEm`, `item?`.
- **Regras do CloudKit:**
  - nada de `.unique`;
  - todos os campos com valor por defeito;
  - relações opcionais, com `originalName` para o nome antigo;
  - propriedades calculadas `itens`, `subtopicos` e `fotos` por cima das relações guardadas.
- Enums guardados como `String` crua (`*Raw`) com computed property tipada.
- **Definicoes** não está no SwiftData: `Codable` em UserDefaults, com `decodeIfPresent` para tolerar versões antigas. Campos: as durações, a hora dos avisos, `avisosAtivos`, `inteligenciaAtiva` e `diasListaVazia`.

### Migrações

`EsquemaV1…V5` são cópias congeladas.

- **V4 → V5** é uma etapa própria (`migrarV4ParaV5`): marca as primeiras 4 listas como permanentes.
- **V5 → V6** é `lightweight`.

Para mudar o modelo:
1. criar `EsquemaV7` (cópia mais a alteração);
2. acrescentar a etapa;
3. apontar `BaseDados.contentor` para o V7;
4. escrever um teste de migração a partir do V6;
5. publicar a estrutura no CloudKit (CONTA-DEVELOPER.md, passo 6).

Nunca editar um esquema existente.

### Onde fica a base de dados

`BaseDados.contentor()`:
- **na app:** usa a pasta do App Group quando existe, com `cloudKitDatabase: .automatic`. Na primeira vez copia o `.store`, o `-wal` e o `-shm` do sítio antigo e só depois os apaga;
- **sem App Group** (`.ipa` do iloader, sem assinatura): fica no sítio de sempre;
- **nos testes e na extensão:** usa `.none`.

O CloudKit só liga de facto com as capacidades da conta paga.

## Regras principais

### Ciclo de vida do prazo

1. `criarItem`: `expiraEm = agora + diasExpiracao`.
2. `registarAcao` (editar, subtópico, foto, nota): `ultimaAcaoEm` e `alteradoEm = agora`; o prazo recomeça e a lista deixa de estar vazia.
3. `manter(longo:)`: `expiraEm = agora + diasManterCurto` ou `diasManterLongo`.
4. `avaliar()` (ao abrir e ao voltar ao primeiro plano):
   - os ativos vencidos passam a `expirado`;
   - os expirados e os concluídos para lá da retenção são apagados;
   - as listas vazias são avaliadas.
5. `Prazo(item:agora:)` calcula `fracao` (o anel), `ultimoDia` (menos de 24 h: laranja, "Hoje") e `dias` (com folga de 1 h para a mudança de hora).
6. As vistas partilhadas não expiram.

### Listas (DESIGN.md 7.17)

- **Limites:** no máximo `maxListas = 8` e até `maxPermanentes = 4`.
- **Listas vazias:** uma lista não permanente sem pontos abertos ganha `vaziaDesde` e sai do Início ao fim de `diasListaVazia` (5). Espera pelos pontos expirados (ainda recuperáveis).
- **Funções:** `quandoDesaparece`, `manterLista`, `definirPermanente` e `podeSerPermanente`.

### Avisos

- `planoAvisos()` e `planoAvisosListas()` devolvem `Aviso`/`AvisoLista`, com o texto de `TextoAviso`.
- `Notificacoes.reagendar()` agenda até `maxAvisos = 60` (o iOS aceita 64).
- O modelo do iPhone reescreve o corpo dos 12 mais próximos.
- **Categorias:**
  - item: Manter +5, Manter +15 e Concluir;
  - lista vazia: Manter mais 5 dias e Tornar permanente.

### Para ti (DESIGN.md 7.21)

`Tarefas.paraTi(eventos:)` devolve um cartão ou `nil`. Por ordem de importância:
1. prazos no último dia;
2. uma lista que sai nas próximas 24 h;
3. um evento nas próximas 3 h cujo espaço tem um ponto com subtópicos por fazer;
4. uma vista partilhada a meio.

Tem `fraseBase`, `factos` (para o modelo do iPhone não inventar) e até 2 botões.

## Widgets (DESIGN.md 7.14)

- **`Tarefas.prioridades()`** ordena os pontos pelo que importa agora, cada um com uma razão curta.
- **`resumoWidget()`** gera o `ResumoWidget` (Codable): a frase, até 3 pontos e o tema da Ampulheta (`temaMascote()`, pela atividade dos últimos 7 dias).
- **A app** grava o resumo no App Group em `Notificacoes.atualizarWidget()`, com a frase do modelo do iPhone, e pede `reloadAllTimelines`.
- **A extensão** só lê o resumo. A timeline tem uma entrada a cada 20 min durante 6 h.
- **Widgets:**
  - `WidgetPontos` (médio);
  - `WidgetNovaNota` (ecrã bloqueado: circular e retangular);
  - `ControloNovaNota` (Centro de Controlo, ecrã bloqueado e Action Button).
- **Intents:** `ConcluirPontoIntent` abre a base de dados do grupo e conclui. `AbrirCapturaIntent` abre `todo://captura`.
- **Sem pontos** (ou sem App Group), o widget mostra a **Ampulheta** (`Mascote.swift`, desenhada em `Canvas`): 4 poses ao longo do dia e cenários por tema.
- O ecrã de demo `-ecra widget` (`DemoWidgetsView`) mostra as mesmas vistas dentro da app.

## Vista partilhada e AirDrop (DESIGN.md 7.15)

- **Estrutura:** uma lista `compras` tem secções (os itens) e pontos (os subtópicos).
- **Envio:** `ListaPartilhada.paraPartilhar` gera um ficheiro `.todolista` (JSON), enviado pela folha de partilha (`PartilhaCompras`).
- **Receção:** ao abrir o ficheiro, `juntar` funde por `partilhaId` e pelos ids. Ganha a alteração mais recente, e as lápides contam.
- **Ao vivo:** ainda não há partilha ao vivo. Precisa do CloudKit com `CKShare` (ver PROGRESSO).

## Backup (DESIGN.md 7.19)

- **Formato:** `Backup` (Codable, `versaoFormato` 1) leva listas, itens, subtópicos, estados, datas e definições.
- **Restauro:** `restaurar(aplicar:)` junta por id (e por nome nas listas). Ganha o mais recente e nada é apagado. Devolve um `ResumoRestauro` para a confirmação.
- **Na app:**
  - `Backups.swift` exporta para Ficheiros ou para o iCloud Drive (`iCloud.com.hugo.todo`) e lê o ficheiro escolhido;
  - Definições › Backup.
- Com a conta paga, a sincronização contínua passa a ser o CloudKit do SwiftData. Em Debug, `EsquemaICloud.swift` cria a estrutura no ambiente de desenvolvimento.

## Inteligência (DESIGN.md 7.16)

- **Onde corre:** `App/Inteligencia/Inteligencia.swift` usa o Foundation Models (modelo do iPhone, sem rede), só se `disponivel` e com o interruptor Definições › Inteligência ligado.
- **O que escreve:** `corpoAviso`, `fraseWidget` e `fraseParaTi` (até 90 caracteres), sempre a partir de factos do núcleo.
- **Sem modelo:** fica a frase de base.

## Conta Apple (DESIGN.md 7.20)

- **Opcional:** `ContaApple` (`@Observable`) faz o "Iniciar sessão com a Apple", guarda o utilizador no Keychain e confirma o estado da credencial ao abrir.
- **Onde aparece:** `BoasVindasView` (uma vez, no primeiro arranque) e `SecaoConta` no topo das Definições.
- Precisa da capacidade da conta paga para funcionar no iPhone.

## Calendário

- `Calendario` (`@Observable`) junta eventos do **EventKit** e das contas **Google/Microsoft**. Só lê: a app não cria eventos. `APICalendario` vai buscar os externos e `JuntarEventos` deduplica, ficando a versão externa, que tem mais detalhe.
- **Destinos:** cada calendário tem um destino: um espaço, "sem espaço" ou escondido (`DestinoCalendario`). `Espacos.associarPorNome` faz a associação inicial por nome.
- **Pontos:** um evento vira ponto com `criarPontoDeEvento` (uma vez por `eventoId` + `eventoInicio`, por causa dos recorrentes).
- **OAuth:**
  - PKCE, sem segredo de cliente;
  - tokens no Keychain (`App/Contas/Keychain.swift`);
  - client IDs em `RegistoApps.swift`, vazios até seguir `docs/CONTAS.md`.

## Estado da UI

`EstadoApp` (`@Observable`, injetado por `.environment`) guarda:
- o separador e o caminho de navegação;
- a captura rápida;
- a lista atual (para pré-selecionar na captura);
- os filtros de Concluídos e Expirados (só em memória).

`ToDoApp.onOpenURL` trata `todo://captura` e os ficheiros `.todolista`.

**Modo demo:** `-demo YES -ecra <nome>` abre um ecrã com dados de exemplo (`Demo.swift`). Ecrãs: `lista`, `detalhe`, `captura`, `personalizar`, `calendario`, `evento`, `expirados`, `concluidos`, `definicoes`, `compras` e `widget`. Serve o CI e o simulador.

## Testes

`Packages/ToDoCore/Tests/ToDoCoreTests` (171 testes):
- expiração, tarefas e notas;
- espaços e listas vazias;
- calendário e eventos externos, contas e OAuth;
- filtros, navegação e exportação CSV;
- partilha (mais a migração V4), widget (mais a base de dados no grupo), tema da mascote, backup (mais a migração V5) e Para ti.

`BaseTestes.swift` tem o contentor em memória e o relógio fixo. Não há testes de UI: a UI valida-se no simulador local, nas capturas do CI e no iPhone.

## CI e scripts

| Peça | Função |
| --- | --- |
| `.github/workflows/ci.yml` | testes, build sem assinatura, `.ipa` na release `ultima` (para o iloader), capturas; não corre só com `.md` |
| `.github/workflows/testflight.yml` | manual: assina com a chave da App Store Connect e envia para o TestFlight (precisa dos secrets, ver CONTA-DEVELOPER.md) |
| `scripts/capturas-ci.sh` | no CI: arranca o simulador, abre cada ecrã em modo demo e fotografa em escuro e claro |
| `scripts/capturas.sh` | local: descarrega as capturas de uma execução do CI (precisa do `gh`) |
| `scripts/mocks.sh` | HTML dos mocks → PNG |
| `scripts/readme-media.py` | gera as imagens e os GIFs do README a partir das capturas |

O ícone da app (`AppIcon-1024`, `-dark` e `-tinted`) é gerado a partir do código da Ampulheta com `ImageRenderer` (DESIGN.md 10).

## Convenções

- PT-PT na UI, nos identificadores, nos comentários e nos commits ("Melhoria N: …").
- Comentários curtos que explicam o porquê, com referência ao DESIGN.md ou à especificação quando existir.
- Datas sempre via `Relogio`; durações sempre via `Definicoes`.
- Sem dependências externas.
