<div align="center">

<img src="docs/media/icone.png" width="112" alt="Ícone da app ToDo">

# ToDo

### A lista de tarefas que se limpa sozinha.

O que não recebe atenção em 3 dias sai do caminho.<br>
A tua lista mostra só o que ainda importa, sem se tornar um arquivo de coisas por fazer.

[![CI](https://github.com/hroxo/todo/actions/workflows/ci.yml/badge.svg)](https://github.com/hroxo/todo/actions/workflows/ci.yml)
[![iOS 26+](https://img.shields.io/badge/iOS-26%2B-000000?logo=apple&logoColor=white)](#instalar-no-iphone)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%C2%B7%20SwiftData-F05138?logo=swift&logoColor=white)](#arquitetura)
[![Última versão](https://img.shields.io/badge/download-ToDo.ipa-0071E3)](https://github.com/hroxo/todo/releases/tag/ultima)
[![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-34C759)](LICENSE)

<img src="docs/media/principal.png" width="820" alt="Três ecrãs da app em modo escuro: Início com os espaços, uma lista com anéis de prazo e o detalhe de um ponto com o botão Manter">

</div>

---

## Porquê

As apps de tarefas crescem até ninguém as abrir. Cada ideia fica lá para sempre, e a lista deixa de dizer o que é importante.

O **ToDo** inverte isto: **cada ponto tem 3 dias de vida.** Se lhe tocas (editas, marcas um subtópico, acrescentas uma foto), o prazo recomeça. Se ainda importa mas não é para já, **Manter** dá-lhe mais tempo. Se não lhe tocas, sai da lista, mas fica 14 dias em **Expirados**, à espera, caso mudes de ideias.

- 🧹 **Dinâmica, não arquivo**: a lista ativa só tem o que ainda importa.
- 🛟 **Nada se perde por engano**: o que expira é recuperável.
- ⚡ **Registar em segundos**: escrever e guardar, com o teclado já aberto.
- 🔒 **Tudo no teu iPhone**: sem contas, sem servidor, sem rede, sem custos.
- ✨ **Simples e bonita**: nativa, com o liquid glass do iOS 26 e cores com significado.

## Funcionalidades

<table>
<tr>
<td width="50%" valign="top">

### ⏳ Um anel que conta o tempo
Cada ponto mostra um anel que se esvazia nos 3 dias e fica laranja no último. O Início junta o que expira hoje.

</td>
<td width="50%" align="center"><img src="docs/media/fluxo-navegacao.gif" width="240" alt="Do Início para uma lista e para o detalhe de um ponto"></td>
</tr>
<tr>
<td align="center"><img src="docs/media/fluxo-manter.gif" width="240" alt="O botão Manter divide-se em bolhas de +5 e +15 dias ao arrastar"></td>
<td valign="top">

### 💧 Manter, num gesto
Um toque dá **+5 dias**. Prime e arrasta: a gota de vidro divide-se em **+5** e **+15**, e soltas para escolher. Também funciona a partir da notificação, sem abrir a app.

</td>
</tr>
<tr>
<td valign="top">

### 📅 O teu dia ao lado das listas
Liga o calendário (Apple, Google, Outlook: as contas que já tens no iPhone) e vê os eventos de hoje no fundo do Início, cada um no seu espaço. Um **+** transforma um evento num ponto.

</td>
<td align="center"><img src="docs/media/fluxo-calendario.gif" width="240" alt="Cartão para ligar o calendário e, depois, os eventos de hoje por espaço"></td>
</tr>
<tr>
<td align="center"><img src="docs/media/fluxo-espacos.gif" width="240" alt="Seis espaços em duas páginas, com setas"></td>
<td valign="top">

### 🗂️ Até 8 espaços
Trabalho, Pessoal, Casa… cada espaço tem a sua cor e um ícone ou emoji. Com mais de 4, o Início mostra páginas com setas.

</td>
</tr>
<tr>
<td valign="top">

### 🌗 Claro ou escuro, como o teu iPhone
A app segue o tema do sistema, e o ícone também tem versões escura e tingida.

</td>
<td align="center"><img src="docs/media/fluxo-tema.gif" width="240" alt="O Início em modo escuro e em modo claro"></td>
</tr>
</table>

E ainda:
- **Subtópicos**: quando os concluis todos, a app sugere concluir o ponto.
- **Descrição curta** e até **4 fotos** em cada ponto.
- **Fixar** o que nunca deve expirar.
- **Captura rápida**, com subtópicos, fotos e escolha do espaço.
- **Concluídos** durante 7 dias, para reabrir se for preciso.
- **Notificações** 24 horas antes de um ponto expirar (nunca durante a noite).
- Cada gesto tem uma alternativa por menu, e a app suporta Dynamic Type e VoiceOver.

## Galeria

| | Início | Lista | Detalhe | Captura | Expirados | Definições |
|---|---|---|---|---|---|---|
| **Escuro** | <img src="docs/media/galeria-1-inicio-escuro.png" width="120"> | <img src="docs/media/galeria-2-lista-escuro.png" width="120"> | <img src="docs/media/galeria-3-detalhe-escuro.png" width="120"> | <img src="docs/media/galeria-6-captura-escuro.png" width="120"> | <img src="docs/media/galeria-8-expirados-escuro.png" width="120"> | <img src="docs/media/galeria-10-definicoes-escuro.png" width="120"> |
| **Claro** | <img src="docs/media/galeria-1-inicio-claro.png" width="120"> | <img src="docs/media/galeria-2-lista-claro.png" width="120"> | <img src="docs/media/galeria-3-detalhe-claro.png" width="120"> | <img src="docs/media/galeria-6-captura-claro.png" width="120"> | <img src="docs/media/galeria-8-expirados-claro.png" width="120"> | <img src="docs/media/galeria-10-definicoes-claro.png" width="120"> |

<sub>Capturas reais do simulador, tiradas pelo CI em cada versão.</sub>

## Como funciona

| Regra | |
|---|---|
| Ponto novo | Fica **ativo durante 3 dias** |
| Tocar num ponto (editar, subtópico, foto, descrição) | O prazo **recomeça**: mais 3 dias |
| **Manter** | **+5 dias** (toque) ou **+15 dias** (arrastar), a contar de agora |
| **Fixar** | Nunca expira |
| Sem ações até ao fim do prazo | Vai para **Expirados**, onde fica **14 dias** e se pode recuperar |
| **Concluir** | Vai para **Concluídos**, onde fica **7 dias** e se pode reabrir |

Todas as durações podem ser mudadas em Definições › Avançado › Prazos.

## Instalar no iPhone

A app é para uso pessoal e não está na App Store. Cada versão é compilada pelo CI e publicada como `.ipa`.

1. **[Descarregar `ToDo.ipa`](https://github.com/hroxo/todo/releases/download/ultima/ToDo.ipa)** (última compilação).
2. Instalar com um Apple ID gratuito, usando o [iloader](https://github.com/nab138/iloader) (Linux, macOS, Windows) por cabo, ou o SideStore.
3. No iPhone, ativar o **Modo de Programador** e confiar no programador em Ajustes › Geral › VPN e Gestão de Dispositivos.

> Com um Apple ID gratuito, a assinatura dura 7 dias: volta a instalar uma vez por semana. Os dados mantêm-se.

## Arquitetura

```
ToDo
├── App/                     Interface SwiftUI (ecrãs, componentes, notificações, calendário)
│   └── Resources/           Catálogo de cores (12 × 4 variantes) e ícone
├── Packages/ToDoCore/       Núcleo sem interface: modelos SwiftData, regras, testes
├── design/                  Guia de UI (DESIGN.md), ícone e mocks
├── scripts/                 Capturas de ecrã, mocks e imagens do README
└── project.yml              Projeto Xcode gerado pelo XcodeGen
```

- **SwiftUI** com liquid glass (`glassEffect`, `GlassEffectContainer`), **SwiftData** com o esquema versionado e migrações testadas, **EventKit** só para leitura, **UserNotifications** com ações, **PhotosPicker**.
- **O núcleo é testado à parte** (`swift test`): cada regra do produto tem testes, com um relógio injetável para as datas.
- **Sem dependências externas.**

## Desenvolvimento

Não é preciso Xcode local: **o CI é o compilador.**

```mermaid
flowchart LR
  A[push] --> B[GitHub Actions<br/>macOS]
  B --> C[testes do núcleo]
  B --> D[.ipa na release 'ultima']
  B --> E[capturas no simulador<br/>escuro + claro]
  E --> F[scripts/capturas.sh]
  D --> G[iloader → iPhone]
```

| Script | O que faz |
|---|---|
| `scripts/capturas.sh` | Descarrega as capturas do CI para `capturas/<versão>-<commit>/` (guarda as anteriores) |
| `scripts/mocks.sh` | Converte os mocks HTML de `design/mocks/html/` em PNG |
| `scripts/readme-media.py` | Gera as imagens e os GIFs deste README a partir das capturas |

A app tem um **modo de demonstração** (`-demo YES -ecra <nome>`), com dados de exemplo em memória, que o CI usa para fotografar cada ecrã.

## Roadmap

- [x] **M0** Pipeline: compilação no CI e instalação no iPhone
- [x] **M1** Listas, pontos, subtópicos, menu "…"
- [x] **M2** Expiração, Manter, notificações
- [x] **M3** Expirados, Concluídos, Definições, captura rápida e design
- [x] **M4** Descrição curta, Definições reorganizadas
- [x] **M5** Calendário (EventKit), espaços em páginas, calendário por espaço
- [ ] **M6** Importar CSV e backup JSON
- [ ] **M7** Acabamento visual, háptica e acessibilidade

## Design

O guia de UI está em [`design/DESIGN.md`](design/DESIGN.md) e os mocks em [`design/mocks/`](design/mocks). O ícone, *três linhas de lista que encolhem e desvanecem*, conta a ideia da app: a lista que se limpa sozinha.

<p align="center"><img src="design/icone/icone-preview.png" width="520" alt="O ícone nas versões clara, escura e tingida"></p>

## Licença

[MIT](LICENSE) © 2026 Hugo
