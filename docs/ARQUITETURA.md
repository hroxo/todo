# Arquitetura

Visão técnica do ToDo para quem vai mexer no código. O desenho visual está em [`design/DESIGN.md`](../design/DESIGN.md).

## Camadas

```
App/ (SwiftUI)            ──usa──▶  Packages/ToDoCore (Swift puro + SwiftData)
  Ecras/        ecrãs                  Modelos.swift     Lista, Item, Foto, enums
  Componentes/  peças reutilizáveis    Tarefas.swift     todas as operações e regras
  Contas/       OAuth + Keychain       Prazo.swift       tempo restante, rótulos, anel
  Calendario    EventKit + externos    Definicoes.swift  durações e avisos (UserDefaults)
  Notificacoes  avisos locais          BaseDados.swift   esquemas V1–V4 e migrações
  Demo          dados de exemplo       Filtro/Exportador/Espacos/Navegacao…
```

A UI não contém regras: chama `Tarefas` (que recebe `ModelContext`, `Relogio` e `Definicoes`). O núcleo compila e testa-se sem simulador (`swift test` em `Packages/ToDoCore`).

## Modelo de dados (esquema V4)

- **Lista** (um "espaço"): `id`, `nome`, `corRaw` (chave de `CorLista`), `ordem`, `icone` (SF Symbol), `emoji?`, `itens` (cascade).
- **Item**: `titulo`, `tipoRaw` (`tarefa` | `notaRapida`), `estadoRaw` (`ativo` | `concluido` | `expirado`), `fixado`, `criadoEm`, `ultimaAcaoEm`, `expiraEm?`, `expiradoEm?`, `concluidoEm?`, `ordem`, `nota?`, `eventoId?`, `eventoInicio?`, `lista?`, `pai?`, `subtopicos` (cascade), `fotos` (cascade).
  - Principal: tem `lista`, não tem `pai`. Subtópico: tem `pai`, não tem `lista` (usa `listaEfetiva`). Só um nível.
- **Foto**: `dados` (`externalStorage`, JPEG reduzido), `ordem`, `criadaEm`, `item?`.
- Enums guardados como `String` crua (`*Raw`) com computed property tipada, para migrações simples.
- **Definicoes** não está no SwiftData: `Codable` em UserDefaults, com `decodeIfPresent` para tolerar versões antigas.

### Migrações

`EsquemaV1…V4` são cópias congeladas; `PlanoMigracao` encadeia `lightweight`. Para mudar o modelo: criar `EsquemaV5` (cópia + alteração), acrescentar a etapa, apontar `BaseDados.contentor` para V5 e escrever teste de migração a partir de V4. Nunca editar um esquema existente.

## Ciclo de vida do prazo

1. `criarItem` → `expiraEm = agora + diasExpiracao`.
2. `registarAcao` (editar, subtópico, foto, nota) → `ultimaAcaoEm = agora`, prazo recomeça.
3. `manter(longo:)` → `expiraEm = agora + diasManterCurto|Longo`.
4. `avaliar()` (ao abrir a app e ao voltar ao primeiro plano): ativos vencidos → `expirado`; expirados e concluídos para lá da retenção → apagados.
5. `Prazo(item:agora:)` calcula `fracao` (anel), `ultimoDia` (< 24 h, laranja, "Hoje"), `dias` (com folga de 1 h para a mudança de hora).
6. `planoAvisos()` → `Notificacoes.reagendar()` (máx. 64 pendentes no iOS), ao passar a segundo plano.

## Calendário

- `Calendario` (`@Observable`) junta eventos do **EventKit** e das contas **Google/Microsoft** (`APICalendario`, `JuntarEventos` deduplica: fica a versão externa, com mais detalhe).
- Cada calendário tem um destino: um espaço, "sem espaço" ou escondido (`DestinoCalendario`); `Espacos.associarPorNome` faz a associação inicial por nome.
- Eventos viram pontos com `criarPontoDeEvento` (uma vez por `eventoId` + `eventoInicio`, para recorrentes).
- OAuth: PKCE, sem segredo de cliente; tokens no Keychain (`App/Contas/Keychain.swift`). Client IDs em `RegistoApps.swift` (vazios até seguir `docs/CONTAS.md`).

## Estado da UI

`EstadoApp` (`@Observable`, injetado por `.environment`) guarda separador, caminho de navegação, captura rápida, lista atual (para pré-selecionar na captura) e filtros de Concluídos/Expirados (só em memória). Vários campos "só para o modo demo" existem para o CI navegar até ecrãs específicos.

## Testes

`Packages/ToDoCore/Tests/ToDoCoreTests`: expiração, tarefas, notas, espaços, calendário/eventos externos, contas/OAuth, filtros, navegação, exportação CSV. `BaseTestes.swift` tem o contentor em memória e o relógio fixo. Não há testes de UI; a UI valida-se pelas capturas do CI e no iPhone.

## CI e scripts

| Peça | Função |
| --- | --- |
| `.github/workflows/ci.yml` | testes, build sem assinatura, `.ipa` na release `ultima`, capturas |
| `scripts/capturas-ci.sh` | no CI: arranca simulador, abre cada ecrã em modo demo, fotografa escuro e claro |
| `scripts/capturas.sh` | local: descarrega as capturas de uma execução do CI (precisa de `gh`) |
| `scripts/mocks.sh` | HTML dos mocks → PNG |
| `scripts/readme-media.py` | gera imagens e GIFs do README a partir das capturas |

## Convenções

- PT-PT em UI, identificadores, comentários e commits.
- Comentários curtos que explicam o porquê, com referência ao DESIGN.md/especificação quando existir.
- Datas sempre via `Relogio`; durações sempre via `Definicoes`.
- Sem dependências externas.
