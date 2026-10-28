# Guia de UI — App ToDo pessoal (v1)

Versão 1.1 · 21 de outubro de 2026 · Complementa o `CLAUDE.md` e a especificação funcional.

Novidades da 1.1: Definições reorganizadas (7.11), calendário no Início (7.12), descrição curta nos pontos (7.13), aparência a seguir o iPhone (1.6).

Este documento fixa as decisões visuais e de interação da v1. Quem implementa deve segui-lo à letra no que está **[Decidido]**. Nas **[Proposta]**, deve seguir o texto e assinalar dúvidas em vez de inventar.

Referência visual (mocks iteráveis): https://claude.ai/artifact/HUdHGgoDoZwCJDAjwnshfj

- Artboards 1–6: Início, Lista, Detalhe + Manter, Captura, Expirados, Personalizar lista. Também: ícone e os 4 estados do Manter.
- Artboards 7–10 (v1.1): 7 Início — ligar calendário · 8 Início — hoje no calendário · 9 Definições reorganizadas · 10 Detalhe com descrição.
- Artboards 11–14 (v1.2): 11 Início com 6 espaços (pág. 1) e calendário por espaço · 12 página 2 (máx. 8) · 13 Definições › Calendários por espaço · 14 escolher o espaço de um calendário.

---

## 1. Princípios visuais

1. **Nativo primeiro.** SwiftUI e componentes do sistema (TabView, NavigationStack, sheet, PhotosPicker, SF Symbols). Não desenhar à mão o que o iOS já dá. [Decidido]
2. **Liquid glass do sistema, com moderação.** O vidro nativo do iOS 26+ (nunca uma imitação com blur) só aparece em dois sítios: na **barra de navegação de baixo** (separadores) e nos **botões dos cantos do ecrã** (toolbar, "+", fechar, grupos de ações no topo). Cartões, linhas, cápsulas dentro do conteúdo e fundos ficam **sem vidro**: superfícies sólidas na cor da lista. O botão Manter (7.5) é a única exceção, por ser o gesto-assinatura. [Decidido 27/10/2026]
3. **Cor com significado.** Cada lista tem uma cor e um ícone. A cor pinta o cartão da lista, o fundo dos ecrãs dessa lista e o anel de cada item. [Decidido]
4. **O anel conta o tempo.** Cada item mostra um anel que se esvazia nos 3 dias. No último dia fica laranja. É o elemento-assinatura da app. [Decidido]
5. **Nada sai do ecrã.** Todo o conteúdo cabe na largura e altura disponíveis, respeita as safe areas e nunca fica por baixo da barra de separadores sem poder ser percorrido. [Decidido]
7. **Carinho em cada gesto.** A app distingue-se pela beleza e pelo cuidado das animações: o botão Manter (física de água, 7.5) é a referência. Cada ecrã e cada widget devem ter esse cuidado: molas em vez de durações fixas, transições que mostram de onde as coisas vêm e para onde vão, números que rolam, vibração nos momentos certos, e sempre uma versão calma com "Reduzir movimento". [Decidido 28/10/2026]
6. **Claro, vivo e minimalista.** Tema claro como referência, com cores saturadas nas listas e superfícies brancas. O modo escuro existe, derivado automaticamente das cores do catálogo (secção 3). [Decidido: claro como referência · Proposta: escuro derivado, sem desenho próprio na v1]
   A app segue o tema do iPhone por defeito (Definições › Aparência = Sistema). O dono usa o escuro: fundos e ícone da app têm de ficar escuros nesse caso (o ícone escuro depende de Ecrã principal › Personalizar › Escuro ou Automático). [Decidido 21/10/2026]

## 2. Stack e requisitos técnicos ligados à UI

### 2.1 Contexto da stack [Decidido — não alterar]

- **Desenvolvimento em Linux, em Swift.** Não há Xcode nem Mac na máquina de trabalho. Nada neste guia pode depender de abrir o Xcode, o simulador, os SwiftUI Previews ou o Icon Composer.
- O projeto é gerado com **XcodeGen** (`project.yml`) e compilado no **GitHub Actions**, num runner macOS. O resultado é um `.ipa` sem assinatura, instalado no iPhone com o **Sideloadly**.
- Consequências para a UI:
  - O catálogo `Assets.xcassets` é editado como ficheiros (pastas + `Contents.json`). É por isso que este pacote o entrega já montado.
  - A validação visual faz-se instalando no iPhone. Cada ecrã deve ser simples de testar à mão, e a lógica (expiração, durações, contagens) vive no módulo testável que corre no CI.
  - Quando houver dúvidas visuais, o Claude Code deve comparar com os mocks (link no topo) em vez de inventar.

### 2.2 Requisitos

- **Deployment target: iOS 26.0.** O liquid glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`) só existe a partir do iOS 26. O iPhone está no iOS 27, por isso não há perda. Isto **substitui** o "iOS 17.0" que estava no `CLAUDE.md`. [Proposta, a confirmar]
- O runner do CI tem de usar Xcode 26 ou superior (o workflow já escolhe a versão mais recente disponível).
- Tipografia: a fonte do sistema (SF Pro), sempre com estilos dinâmicos (`.largeTitle`, `.headline`…), para respeitar o Dynamic Type. Nunca tamanhos fixos em pontos.
- Ícones: só SF Symbols (secção 6). Nada de SVG ou PNG próprios dentro da UI.

## 3. Cores

Todas as cores estão no `Assets.xcassets` deste pacote, com variante clara e escura. Com os símbolos de assets do Xcode, usam-se como `Color(.listaAzul)`, `Color(.estadoExpira)`, etc.

### 3.1 Superfícies (cores do sistema, não estão no catálogo)

| Uso | Cor |
| --- | --- |
| Fundo dos ecrãs gerais (Início, Personalizar) | `Color(.systemGroupedBackground)` |
| Cartões e linhas de lista | `Color(.secondarySystemGroupedBackground)` |
| Texto principal / secundário | `.primary` / `.secondary` |
| Separadores | `Color(.separator)` |

### 3.2 Paleta das listas [Decidido: 12 cores fixas]

Cada cor tem 4 variantes no catálogo:

| Variante | Nome no catálogo | Para quê |
| --- | --- | --- |
| Base | `Lista<Cor>` | Preenchimento do cartão, círculo do ícone, anel, botão principal |
| Tinta | `Lista<Cor>Tinta` | Texto e ícones coloridos sobre branco ou sobre o fundo da lista (títulos, "Expira em 2 dias") |
| Fundo | `Lista<Cor>Fundo` | Fundo dos ecrãs Lista e Detalhe dessa lista |
| Texto | `Lista<Cor>Texto` | Texto e ícone **sobre** a cor base (branco ou quase-preto) |

Cores: Azul, Roxo, Amarelo, Vermelho, Laranja, Verde, Turquesa, Ceu, Indigo, Rosa, Castanho, Grafite.

Todas as combinações texto/base e tinta/fundo cumprem o contraste 4.5:1 (WCAG AA) no modo claro. **Regra:** nunca usar a cor base como cor de texto pequeno. Para texto, usa-se sempre a Tinta.

No modelo de dados, a lista guarda a **chave** da cor (`"azul"`, `"roxo"`…) e não um hexadecimal. Um `enum CorLista: String, CaseIterable` faz a ponte para as 4 variantes.

Listas iniciais: **Trabalho** = Azul + `briefcase.fill`, **Pessoal** = Roxo + `person.fill`. [Decidido]

### 3.3 Estados

| Nome | Uso |
| --- | --- |
| `AccentColor` (azul) | Tint global da app, botão "+" de captura |
| `EstadoExpira` | Anel no último dia, contador do separador Expirados |
| `EstadoExpiraTinta` | Texto "Hoje" e outros avisos de expiração |
| `EstadoExpiradosFundo` | Fundo do ecrã Expirados e do aviso no Início |
| `EstadoConcluido` | Botão Concluir e estado concluído |
| `AnelTrilho` | Parte vazia dos anéis nas linhas |

## 4. Tipografia

| Elemento | Estilo | Peso |
| --- | --- | --- |
| Título de ecrã ("Listas", "Trabalho") | `.largeTitle` | `.heavy` |
| Data no topo do Início | `.footnote`, maiúsculas | `.semibold`, `.secondary` |
| Nome da lista no cartão | `.headline` | `.bold` |
| Título de item | `.body` | `.semibold` |
| Metadados (subtópicos, fotos, tempo) | `.footnote` | `.regular`, `.secondary` |
| Cabeçalho de secção ("FIXADOS", "ATIVOS") | `.footnote`, maiúsculas | `.semibold` |
| "Expira em 2 dias" no Detalhe | `.title` | `.heavy`, cor Tinta |
| Texto na captura | `.title2` | `.semibold` |

## 5. Forma e espaçamento

- Margem lateral dos ecrãs: 20 pt.
- Espaço entre blocos: 14–16 pt. Entre cartões da grelha: 12 pt.
- Raios: cartões de lista 22 pt, grupos de linhas 18 pt, linhas soltas e miniaturas 14 pt, botões em cápsula = metade da altura. Usar `.rect(cornerRadius:, style: .continuous)`.
- Alvos de toque: mínimo 44×44 pt em tudo o que é tocável.
- Altura das linhas de item: 62 pt. Linhas de subtópico: 46 pt.
- **Nenhum ecrã define margens à mão; usa `Espaco` e `EcraBase`.** [Decidido 22/10/2026] `Espaco` (`App/Componentes/EcraBase.swift`) tem `margem` 20, `bloco` 16, `grelha` 12, `linhaItem` 62, `linhaSubtopico` 46 e, dentro dos componentes, `curto` 8, `fino` 4, `minimo` 2 e `fim` 24 (depois do último bloco). Os quatro separadores usam o mesmo cabeçalho do Início (linha pequena em maiúsculas + título `.largeTitle` `.heavy`): `EcraBase` sobre `ScrollView` (Listas, Expirados) ou `EcraBaseLista` sobre `List` agrupada (Concluídos, Definições). A linha pequena é a data no Início e fica reservada nos outros, para o título ficar sempre à mesma altura.

## 6. Ícones (SF Symbols)

### 6.1 Ícones de lista [Decidido: símbolos ou emoji, estilo modos de concentração]

O utilizador escolhe **um símbolo** da lista abaixo **ou um emoji**. O ícone aparece sempre dentro de um círculo da cor base, com o símbolo na cor Texto.

| Nome | SF Symbol | Nome | SF Symbol |
| --- | --- | --- | --- |
| Trabalho | `briefcase.fill` | Estrela | `star.fill` |
| Pessoa | `person.fill` | Lua | `moon.fill` |
| Casa | `house.fill` | Folha | `leaf.fill` |
| Lâmpada | `lightbulb.fill` | Presente | `gift.fill` |
| Coração | `heart.fill` | Música | `music.note` |
| Carrinho | `cart.fill` | Câmara | `camera.fill` |
| Livro | `book.fill` | Código | `chevron.left.forwardslash.chevron.right` |
| Haltere | `dumbbell.fill` | Calendário | `calendar` |
| Avião | `airplane` | Visto | `checkmark.circle.fill` |

No modelo: `icone: String` com o nome do SF Symbol, ou `emoji: String?`. Se `emoji` existir, tem prioridade. Para escolher o emoji usa-se um campo de texto com teclado de emoji, aceitando só um grafema. [Proposta]

### 6.2 Ícones da interface

| Onde | SF Symbol |
| --- | --- |
| Separador Listas | `list.bullet` |
| Separador Concluídos | `checkmark.circle` |
| Separador Expirados | `hourglass` |
| Separador Definições | `gearshape` |
| Captura rápida | `plus` |
| Fixar | `pin` / `pin.fill` |
| Manter | `arrow.clockwise` |
| Concluir | `checkmark.circle` |
| Mais opções | `ellipsis` |
| Foto da biblioteca | `photo.on.rectangle` |
| Tirar foto | `camera` |
| Subtópico | `checklist` |
| Recuperar | `arrow.uturn.backward` |
| Apagar | `trash` |
| Exportar CSV | `square.and.arrow.up` |
| Filtrar (Concluídos, Expirados) | `line.3.horizontal.decrease.circle` / `.fill` com filtro ativo |

## 7. Componentes

### 7.1 Barra de separadores (liquid glass) [Decidido]

- `TabView` nativa com 4 separadores: **Listas, Concluídos, Expirados, Definições**. No iOS 26+ ganha liquid glass automaticamente; não se estiliza à mão.
- O separador Expirados mostra um contador `.badge(n)` quando há itens.
- **Botão "+" de captura:** um botão circular de vidro, à direita da barra e separado dela, como nos mocks. Implementação: um `Button` em overlay com `.glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)`, alinhado com a barra. [Proposta: se o alinhamento com a barra nativa der problemas, usar `.tabViewBottomAccessory` com um botão "Nova nota"]
- `.tabBarMinimizeBehavior(.onScrollDown)` para a barra encolher ao percorrer listas longas. [Proposta]
- O conteúdo percorre **por baixo** da barra (é isso que dá o efeito de vidro), mas a última linha tem de ficar visível quando se chega ao fim.

### 7.2 Cartão de lista (Início)

- Grelha de 2 colunas. Cada cartão tem 148 pt de altura e é preenchido com a cor base, com uma sombra suave da mesma cor (opacidade ~30%, raio 16).
- Em cima à esquerda, o ícone num círculo de 40 pt (branco a 25%, ou preto a 12% nas cores claras). Em cima à direita, um mini-anel com a "frescura" da lista (proporção de itens longe de expirar).
- Em baixo, o nome (`.headline`) e "N ativos".
- O último lugar da grelha é sempre o cartão "Nova lista", com contorno tracejado, que abre Personalizar lista.

### 7.3 Anel de expiração

- Linha de item: anel de 34 pt, espessura 5. Detalhe: anel de 64 pt, espessura 10.
- Progresso = tempo restante / duração atual do item (3 dias por defeito, ou mais depois de Manter). Começa no topo e corre no sentido dos ponteiros do relógio, com pontas arredondadas.
- Cor: base da lista. **No último dia** (menos de 24 h): `EstadoExpira`, e o texto à direita passa a "Hoje" em `EstadoExpiraTinta`.
- À direita da linha: "3 d", "2 d", "Hoje". Itens fixados mostram o ícone `pin.fill` em vez do anel e o texto "Não expira".
- **Tocar no anel conclui o item** (na linha da Lista; também no `pin.fill` dos fixados). Alvo de 44 × 44 pt, que não abre o Detalhe. O anel enche-se até 100% na cor `EstadoConcluido`, aparece um visto e só depois a linha sai (`.snappy`), com vibração `.success`. Rótulo VoiceOver "Concluir", com o tempo restante como dica. [Decidido 22/10/2026]

### 7.4 Linha de item

Anel · título (1 linha, com reticências) · metadados ("2/4 subtópicos · 2 fotos", com o ícone `photo` quando há fotos) · tempo restante. Toque no anel conclui (7.3); toque no resto abre o Detalhe. Swipe para a esquerda: Apagar. Swipe para a direita: Manter +5 e Concluir. [Proposta para os swipes]

Depois de concluir na Lista (anel ou swipe), aparece no fundo, durante 4 s, um aviso de vidro em cápsula "✓ Concluído · Anular". Anular devolve o item à mesma secção, com o mesmo prazo e o mesmo anel (`Tarefas.anular`). [Proposta]

### 7.5 Botão Manter — "gotas de vidro" (Detalhe) [Decidido]

Conceito: o Manter é **uma gota de liquid glass que se divide em três**. Ao premir, nascem duas bolhas ("+5" à esquerda, "+15" à direita) que ficam ligadas à cápsula por pescoços de líquido. Ao arrastar para um lado, essa bolha cresce, enche-se de cor e funde-se com a cápsula; a do outro lado encolhe e solta-se. É exatamente o comportamento de fusão do `GlassEffectContainer`.

Estados (ver o quadro "Botão Manter — 4 estados" nos mocks):

| Estado | Aspeto | Ação |
| --- | --- | --- |
| 1 · Parado | Uma cápsula de vidro centrada (~200 × 64 pt), preenchida na cor base, com `arrow.clockwise` + "Manter" na cor Texto | Toque simples = **+5 dias** |
| 2 · Premido | A cápsula encolhe (~160 pt) e ficam visíveis duas bolhas de 60 pt, "+5 dias" e "+15 dias", ligadas por pescoços | Começa com um toque longo (~0,3 s), com vibração `.impact(.light)` |
| 3 · Arrastar ← | A cápsula desliza ~20 pt para a esquerda; a bolha +5 cresce para 68 pt, enche-se na cor base (texto na cor Texto) e funde-se; a bolha +15 encolhe para 48 pt e solta-se | Passar o limiar (40 pt) dá vibração `.selection`; soltar confirma **+5** |
| 4 · Arrastar → | Simétrico, para a bolha +15 | Soltar confirma **+15** |

Regras:
- Implementação: as três formas dentro de um `GlassEffectContainer(spacing: 20)`, cada uma com `.glassEffect(.regular.interactive())` e `glassEffectID(_:in:)` num `@Namespace`, para o sistema desenhar a separação e a fusão. A cor do estado ativo usa `.glassEffect(.regular.tint(cor).interactive())`. Gestos: `LongPressGesture(minimumDuration: 0.3).sequenced(before: DragGesture(minimumDistance: 0))`.
- **Física de água** (Melhoria 9, `AguaManter`): o movimento não usa animações de duração fixa, mas molas amortecidas calculadas a cada fotograma. A cápsula segue o dedo com inércia e ressalto; as bolhas nascem de dentro dela e seguem-na com atraso (o pescoço estica); cada gota estica na direção em que se mexe sem mudar de volume e treme como geleia ao nascer, ao passar o limiar e ao confirmar. Lá dentro há líquido na cor da lista: em Premido sobra um pouco no fundo da cápsula, ao arrastar passa para a bolha escolhida (cheia no limiar) e, ao soltar, volta a encher a cápsula; a superfície inclina-se com a aceleração e ondula. O texto muda para a cor Texto onde fica debaixo do líquido. Com "Reduzir movimento": sem ressalto, sem ondas nem inclinação. [Proposta]
- **Mais líquido no arrasto para +15** [Decidido 27/10/2026 · Melhoria 10]:
  - Arrastar logo abre as gotas, sem esperar pelo toque longo (antes, o gesto perdia-se).
  - A cápsula acompanha mais o dedo (40 pt).
  - A bolha escolhida incha até 82 pt, estica na direção da cápsula e encosta-se a ela.
  - A outra encolhe até 36 pt e afasta-se até se soltar.
  - Depois do alcance (80 pt), o dedo encontra uma resistência elástica em vez de parar a seco.
- Voltar ao centro antes de soltar cancela, e as bolhas recolhem para dentro da cápsula.
- A linha de ajuda acima do botão muda com o estado: "Toque: +5 dias · Premir e arrastar para escolher" → "Arrasta para um dos lados" → "Solta para manter mais 5/15 dias".
- Depois de confirmar: vibração `.success`, as bolhas recolhem e o anel do topo anima até ao novo valor.
- **Fixar, Concluir e "…"** saem da barra de baixo e vão para um grupo de vidro no canto superior direito da barra de navegação. À esquerda desse grupo, num grupo de vidro próprio, ficam **˄ ˅** (`chevron.up` / `chevron.down`) para o item anterior e o seguinte da lista, como no Mail; desativados no primeiro e no último. [Decidido 22/10/2026] No Detalhe, a barra de separadores fica escondida (`.toolbar(.hidden, for: .tabBar)`); o botão Manter ocupa o fundo do ecrã sozinho.

### 7.6 Captura rápida [Decidido]

- `.sheet` de altura total, aberta pelo "+". O teclado abre logo (`@FocusState`).
- Campo de texto grande (`.title2`), várias linhas, com o cursor na cor da lista escolhida.
- Fichas de lista, cada uma com o círculo do ícone. A selecionada enche-se com a cor base. Vem pré-selecionada a última usada.
- Barra de vidro por cima do teclado (`.toolbar { ToolbarItemGroup(placement: .keyboard) }`) com: Foto da biblioteca, Tirar foto, Subtópico e Fixar.
- Fotos anexadas aparecem como miniaturas de 72 pt com um botão para remover.
- Linha de ajuda: "Expira daqui a 3 dias se não lhe tocares".
- Guardar = botão em cápsula na cor da lista, no canto superior direito.

### 7.7 Fotos nas notas [Decidido: fotos da biblioteca]

- Escolha com `PhotosPicker` (não precisa de pedir permissão de acesso à biblioteca). Até 4 fotos por item. [Proposta]
- "Tirar foto" usa a câmara e precisa de `NSCameraUsageDescription` no Info.plist. [Proposta: pode sair da v1 se complicar]
- Guardar em JPEG reduzido (lado maior ≤ 2048 px, qualidade 0.8), com `@Attribute(.externalStorage)` no SwiftData.
- No Detalhe: secção "Fotos" com miniaturas de 76 pt e um quadrado tracejado "Biblioteca" para adicionar. Toque numa foto abre-a em ecrã inteiro.
- **Backup:** as fotos entram no backup JSON em base64. Isto torna o ficheiro maior. [Proposta, a confirmar]
- Adicionar ou remover uma foto conta como **ação** para a regra dos 3 dias. [Proposta]

### 7.8 Personalizar lista [Decidido]

Ecrã (ou sheet) aberto pelo "…" da lista ou por "Nova lista". De cima para baixo:

1. Pré-visualização: círculo de 92 pt com o ícone ou emoji, na cor escolhida.
2. Nome, num campo centrado.
3. Grelha de 12 cores (6 × 2), círculos de 40 pt. A selecionada tem um anel exterior.
4. Controlo segmentado **Símbolos | Emoji**.
5. Grelha de 18 opções (6 × 3), círculos de 44 pt. O selecionado enche-se com a cor da lista.

A pré-visualização atualiza-se a cada toque. "OK" grava; "Cancelar" descarta.

### 7.9 Expirados

- Fundo `EstadoExpiradosFundo`. Título "Expirados" como nos outros separadores (`EcraBase`) e, por baixo, o ícone `hourglass` num círculo laranja de 40 pt com o texto "Ficam aqui 14 dias antes de serem apagados".
- Cartão por item: em cima, ícone da lista, título e "Lista · apagado em N dias"; em baixo, o botão **Recuperar** (cápsula laranja clara, a toda a largura, numa só linha) e o botão Apagar (círculo cinzento). [22/10/2026: o "Recuperar" cortava-se ao lado da linha do prazo]
- No Início há um aviso permanente "N itens em Expirados" que leva a este ecrã, sempre que N > 0.
- **Filtros** [Decidido 22/10/2026]: botão `line.3.horizontal.decrease.circle` à direita do título (a barra de navegação está escondida nos separadores), com um menu de duas secções: **Lista** (Todas ou uma lista, com o ícone na cor da lista) e **Data de expiração** (Hoje, Últimos 7 dias, Últimos 30 dias, Tudo). Com um filtro ativo, o ícone passa a `.fill` e aparece por baixo do título uma ficha "Trabalho · Últimos 7 dias" com ✕ para limpar. Sem resultados: "Nada com estes filtros" + "Limpar filtros". Os filtros de cada ecrã são independentes e duram enquanto a app está aberta. A regra está em `FiltroItens` (núcleo): os dias contam desde a meia-noite, no fuso do iPhone.

### 7.10 Ecrãs Lista e Detalhe

- O fundo é a cor Fundo da lista. O título e o "voltar" usam a cor Tinta.
- Lista: cabeçalho com o círculo do ícone (56 pt) + nome + "N ativos · M expiram hoje"; depois as secções **Fixados** e **Ativos**.
- "…" da Lista: Personalizar lista, **Exportar CSV** (`square.and.arrow.up`: abre a folha de partilha normal do iPhone com o ficheiro `ToDo-<lista>-<AAAA-MM-DD>.csv`; "Guardar em Ficheiros" descarrega-o como CSV, e há também AirDrop, Mail, Numbers…) e Apagar lista. Em Definições › Avançado há "Exportar tudo (CSV)". Colunas: `lista;titulo;estado;criado_em;ultima_acao;expira_em;concluido_em;fixado;subtopicos;n_fotos`, separadas por `;` (o Excel em português usa `;`), UTF-8 com BOM, datas ISO 8601 e subtópicos "[x] …; [ ] …". As fotos não entram, só a contagem. [Decidido 22/10/2026 · `ExportadorCSV`]
- **Navegar entre itens no Detalhe** (Melhoria 5): a ordem é a da Lista (Fixados e depois Ativos, `NavegacaoItens`). Botões ˄ ˅ (7.5) e **puxão elástico nas pontas**: com o scroll no fim, puxar mais ~60 pt para cima passa ao seguinte; no topo, puxar para baixo passa ao anterior. Durante o puxão aparece uma cápsula de vidro "Seguinte: <título>" (no fundo) ou "Anterior: <título>" (no topo), que se enche na cor da lista ao passar o limiar, com vibração `.selection`; muda ao soltar. O scroll normal não muda de item. A troca é um deslize vertical curto (48 pt + fade; só fade com "Reduzir movimento"). Ações de acessibilidade "Item anterior" e "Item seguinte". [Decidido: navegar · Proposta: forma do gesto]
- Detalhe: grupo de vidro no topo direito (Fixar, Concluir, "…") · anel grande + "Expira em N dias" + "Última ação …" · título · Fotos · Subtópicos (com "+" no cabeçalho da secção) · botão Manter em gotas de vidro no fundo (7.5).

### 7.11 Concluídos e Definições

- Concluídos: sem mock. Fundo agrupado do sistema, `List` `.insetGrouped` (`EcraBaseLista`), ícone da lista em círculo, "Concluído hoje, 18:40", deslizar para Reabrir e Apagar. Filtros como em Expirados (7.9), com **Data de conclusão**.
- **Definições (mock 9)** [Decidido 21/10/2026: gerir listas primeiro; menos controlos de horários]. `Form` agrupado, por esta ordem:
  1. **Listas**: uma linha por lista (ícone em círculo de 30 pt, nome, número de ativos, pega para arrastar). Tocar abre Personalizar lista. Última linha "+ Nova lista" na cor de destaque. Ordenar arrastando, sem botão Editar.
  2. **Calendário**: "Calendários" (valor: as fontes ligadas, por exemplo "Apple, Outlook") leva à escolha dos calendários; interruptor "Mostrar eventos no Início". Sem ligação: uma só linha "Ligar calendário".
  3. **Notificações**: interruptor "Avisar antes de expirar" e "Hora dos avisos" (só a hora; nada de outros horários).
  4. **Aparência**: controlo segmentado Sistema · Claro · Escuro.
  5. **Avançado**: "Prazos" (valor resumido "3 · 5 · 15 dias"; abre um ecrã com as cinco durações) e "Importar e backup".
- Ícones das linhas em círculos coloridos de 30 pt, como nos Ajustes do iOS.

### 7.12 Calendário no Início (mocks 7 e 8)

- Lugar: logo a seguir à grelha de espaços; "Expiram hoje" fica no fundo do Início, por baixo do calendário. Quando há itens a expirar hoje, um aviso no topo ("N itens expiram hoje", `clock.badge.exclamationmark`) desce até essa secção. O conteúdo percorre por baixo da barra de separadores. [Decidido 22/10/2026]
- **Por ligar (mock 7)**: cartão branco de 18 pt de raio com o ícone `calendar` num círculo azul de 40 pt, o título "Junta o teu calendário", a frase "Vê os eventos de hoje por baixo das listas e cria pontos a partir deles.", três fichas (Apple, Google, Outlook, cada uma com um ponto da sua cor), o botão em cápsula "Ligar calendário" na cor de destaque e a nota "Lê só no iPhone: usa as contas Google e Outlook que já tens nos Ajustes." O cartão pode fechar-se ("Agora não") e volta a estar em Definições.
- **Ligado (mock 8)**: cabeçalho "HOJE NO CALENDÁRIO" com "Ver semana" à direita; grupo branco com uma linha por evento (58 pt): hora de início e fim, barra vertical de 4 pt na cor do calendário, título (`.body` semibold) e local ou calendário (`.footnote`), ficha vermelha "AGORA" no evento a decorrer e um botão "+" (círculo de 30 pt na cor Fundo da lista de destino, alvo de 44 pt) para criar um ponto a partir do evento.
- Sem eventos hoje: uma linha "Nada no calendário hoje".
- Ícones: `calendar`, `plus`. Cores dos calendários: as que o iOS dá a cada calendário.

### 7.12b Espaços com setas e calendário por espaço (mocks 11–14)

- **Mais de 4 espaços**: cartões de 128 pt (2 × 2 por página) e, por baixo, uma linha com duas setas de vidro (círculos de 44 pt, `chevron.left`/`chevron.right`; a do lado sem mais páginas fica esbatida), pontos de página e "Espaços 1–4 de 6". Deslizar na grelha também muda de página (`TabView` com `.page` ou `ScrollView` paginado). Até 4 espaços, sem setas, como antes.
- **Máximo de 8**: na última página, "Nova lista" só aparece se houver menos de 8; com 8, aparece a nota "Máximo de 8 espaços".
- **Hoje no calendário por espaço** [Decidido]: eventos de todos os espaços, num só grupo branco, por hora. Cabeçalho "HOJE NO CALENDÁRIO" com "4 eventos · todos os espaços". Cada linha (62 pt): horas, barra da cor do calendário, título e, por baixo, o espaço (círculo do ícone de 18 pt, nome em `.footnote` semibold) e o local. O "+" fica na cor do espaço e cria o ponto nesse espaço. Calendários sem espaço não aparecem.
- Imagens dos mocks: `design/mocks/*.png` (geradas com `scripts/mocks.sh` a partir de `design/mocks/html/`).
- **Eventos sem espaço** (Melhoria 6.1) [Decidido 22/10/2026, substitui "calendários sem espaço não aparecem"]: aparecem também, com um círculo tracejado de 18 pt e "Sem espaço" no lugar do espaço. O "+" de um evento sem espaço cria o ponto na última lista usada (pressão longa: escolher outra). Cada calendário tem três destinos: um espaço, **Sem espaço** (aparece) ou **Não mostrar** (escondido).
- **Tocar num evento abre-o** (Melhoria 6.2): folha (`.medium`/`.large`) com o título, "Quinta, 22 out · 14:30–15:30", o local e o calendário; o botão em cápsula "Entrar na reunião" (`video.fill`) quando há link (o URL do evento ou o primeiro link Teams/Zoom/Meet/Webex no local ou nas notas, `LigacaoReuniao`); "Espaço do calendário" com "Associar"/"Mudar" (abre a escolha do mock 14); "Criar ponto em" com fichas de lista como na captura (a do espaço do evento vem preenchida); "Organizado por …"; **Participantes** com a resposta (aceite `checkmark.circle.fill` verde, talvez `questionmark.circle.fill` laranja, recusado `xmark.circle.fill` vermelho, pendente `clock`), escondida quando a conta não os dá; **Notas** (o texto do convite; o EventKit não dá o email original).
- **O "+" só funciona uma vez por evento** (Melhoria 6.4): o ponto guarda o identificador externo do evento e o início da ocorrência (cada ocorrência de um evento recorrente conta à parte). Depois de adicionado, o "+" passa a ✓ num círculo da cor da lista; tocar no ✓ (ou tentar outra vez) mostra "Já está em <lista>" com "Abrir". Se o ponto for apagado ou expirar, o evento pode voltar a ser adicionado; se for concluído, não.
- **Definições › Calendários (mock 13)**: calendários agrupados por conta; cada linha mostra o ponto de cor do calendário, o nome e, à direita, o espaço escolhido (ponto da cor do espaço + nome, ou "Nenhum"). Tocar abre a escolha do espaço (mock 14): lista dos espaços com visto no escolhido e, numa secção à parte, "Sem espaço" e "Não mostrar no Início".

### 7.12c Contas Google e Outlook (Melhoria 7) [Decidido 22/10/2026: ler Google e Outlook diretamente; sem Sign in with Apple]

- Definições › Calendário › **Contas Google e Outlook** (ícone `person.crop.circle.badge.checkmark` em azul): uma linha por fornecedor (Google `g.circle.fill` verde, Outlook `envelope.fill` azul) com o email da conta ligada e "Desligar" (com confirmação), ou "Ligar" (abre a página de início de sessão do fornecedor, `ASWebAuthenticationSession`), ou "Por configurar" se a app ainda não estiver registada (`docs/CONTAS.md`). Erros por baixo, com `exclamationmark.triangle.fill`.
- Os calendários das contas ligadas aparecem em Definições › Calendários numa secção "Google · email (ligada aqui)", com o mesmo espaço / sem espaço / não mostrar.
- No Início, os eventos das contas ligadas juntam-se aos do iPhone; o mesmo evento (mesmo iCalUID e início) aparece uma vez, na versão da conta ligada.
- Só leitura (`calendar.readonly`, `Calendars.Read`). Tokens no Keychain, nunca no backup.

### 7.13 Descrição curta e Concluir (mock 10) [Decidido 21/10/2026]

- **Descrição**: logo abaixo do título do Detalhe, sem cabeçalho nem cartão, em `.body` `.secondary`, no máximo 3 linhas (200 caracteres). Edita-se no lugar; vazia mostra "Acrescentar descrição".
- **Subtópicos**: ficam como estão (círculo + texto); sem descrição, sem fotos. O + à esquerda do campo de novo subtópico também guarda.
- **Concluir**: o visto verde fica no grupo de vidro do topo e há também "Concluir" no menu "…".
- Na Lista, um ponto com descrição mostra "descrição" nos metadados ("2/4 subtópicos · descrição · 2 fotos").

### 7.14 Widgets [Decidido 27/10/2026: entram no âmbito · Proposta: tamanhos]

- **Visão [Decidido 28/10/2026]:** o widget é a porta de entrada da app, mais do que a própria app. Tem de ser tão bonito que apeteça pô-lo no ecrã principal, e **inteligente**: mostra o que importa agora, escolhido pelo modelo do iPhone (7.16) a partir do que a pessoa tem na app. O mesmo carinho de animação (princípio 7), dentro do que o WidgetKit permite: transições de conteúdo, números que rolam e o anel a animar entre estados.

- Estilo: **simples, claros, limpos e informativos.** Pouca informação, boa hierarquia de texto (título, contagem grande e arredondada, uma linha de prazo), sem decoração nem vidro. A cor da lista e o anel (7.3) são os únicos elementos gráficos.
- Pequeno: os próximos itens a expirar, com anel. Médio: uma lista escolhida (configurável), com 3 a 4 itens e a contagem. Ecrã bloqueado: circular (anel + itens que expiram hoje) e retangular (próximo item).
- Botões interativos: Concluir e Manter +5.
- Técnica: extensão WidgetKit e App Group `group.com.hugo.todo` para partilhar a base de dados. Validar primeiro com um widget mínimo que o sideload gratuito aceita a extensão e o App Group.

### 7.15 Listas de compras partilhadas [Decidido 28/10/2026 · Proposta: forma]

- Tipo de lista **Compras**: secções por loja (Continente, IKEA…) com "3 de 8". Tocar risca o artigo. Não tem anel nem prazo, porque os artigos não expiram.
- **Presença automática, como os avatares do Figma:** a cara (ou as iniciais) de cada pessoa aparece no cabeçalho da loja que ela tem aberta no ecrã naquele momento. Não diz onde a pessoa está fisicamente e ninguém escolhe nada: abrir a vista do IKEA põe lá a tua cara. Se ninguém mexer, a presença desaparece ao fim de uns minutos. [Decidido 28/10/2026]
- A foto do Apple ID não está acessível às apps. A cara é uma foto escolhida na app (PhotosPicker) ou as iniciais na cor da pessoa.
- A captura numa lista de compras escolhe a loja e aceita vários artigos seguidos.
- No menu "…": "Partilhar por AirDrop" envia um ficheiro `.todolista`. Abri-lo no outro iPhone cria a lista ou junta as duas cópias (por id, ganha a alteração mais recente). O tempo real vem depois, com o serviço escolhido.

### 7.17 Listas que desaparecem e listas permanentes [Decidido 28/10/2026 · Proposta: detalhes]

- No máximo 8 listas. Uma lista **sem pontos abertos** durante 5 dias (`Definicoes.diasListaVazia`) desaparece do Início, com o que lá estiver concluído.
- **Aviso 24 h antes**, com a mesma regra da noite: título "«Ideias» vai desaparecer", corpo "Sem pontos abertos há 4 dias. Sai amanhã às 15:30, a não ser que a mantenhas." Ações:
  - **Manter mais 5 dias**: a contagem recomeça;
  - **Tornar permanente**: com as 4 ocupadas, mantém mais 5 dias.
- **Permanentes:** até 4, no menu "…" da lista ("Tornar permanente", símbolo `infinity`). Nunca desaparecem.
- **No cartão do Início**, numa lista vazia que vai sair, o número grande passa a ser os dias que faltam ("3 dias para sair") e o anel esvazia ao longo dos 5 dias. Com a lista aberta e vazia, o ecrã diz quando sai e como a guardar.
- **[Proposta]** Itens em Expirados seguram a lista até serem recuperados ou apagados, porque nada se perde por engano. Trabalho e Pessoal nascem permanentes. Ao atualizar a app, as 4 primeiras listas existentes ficam permanentes.

### 7.16 Inteligência no iPhone [Decidido 28/10/2026 · Proposta: forma]

- Usa só o modelo da Apple no próprio iPhone (Foundation Models); nada sai do telemóvel.
- Nas Definições, a secção **Inteligência** tem um interruptor geral e um por função, e explica que tudo fica no iPhone.
- **Notificações:** título = item, subtítulo = lista, corpo = uma linha com contexto ("2 subtópicos por fazer · sem mexer desde segunda"). Sem modelo, usa-se um texto fixo.
- **Captura:** por baixo do campo aparece uma sugestão discreta ("Ideias?", "Dividir em 3 subtópicos?") que se aceita com um toque. Nunca muda nada sozinha.
- **Triagem do dia:** um cartão "Para hoje" no Início, com até 3 sugestões, cada uma com uma razão curta e o botão de ação (Manter, Concluir).
- Visual: um pequeno símbolo `sparkles` marca o que foi sugerido pela IA. Não há outra decoração.

## 8. Movimento e feedback

- Usar as animações por defeito do SwiftUI (`.snappy`, `.smooth`). Nada de animações longas.
- Anel: anima a mudança de progresso (`.animation(.smooth, value:)`).
- Vibração (`sensoryFeedback`): `.selection` ao passar o limiar do Manter, `.success` ao confirmar Manter ou concluir um item, `.warning` antes de apagar.
- Respeitar "Reduzir movimento": sem deslocações grandes, só fade.

## 9. Acessibilidade

- Dynamic Type em todo o texto. Os cartões da grelha podem crescer em altura; nunca cortar texto.
- `accessibilityLabel` em todos os botões só com ícone (Fixar, Concluir, "+", Apagar, "…").
- O anel tem um rótulo falado: "Expira em 2 dias".
- O gesto de arrastar do Manter tem alternativa: `accessibilityActions` com "Manter mais 5 dias" e "Manter mais 15 dias".
- A cor nunca é o único sinal: o último dia também mostra o texto "Hoje".

## 10. Ícone da app [Decidido: proposta B2 com efeito vidro]

- Conceito: três linhas de lista que encolhem e desvanecem; a primeira está feita. É a "lista que se limpa sozinha".
- Fundo em gradiente diagonal roxo (#A050E0) → azul (#0A60EE), com um brilho suave no canto superior esquerdo. Elementos em vidro branco translúcido, com reflexo no contorno.
- Três aparências no `AppIcon.appiconset`: **clara**, **escura** (fundo preto, elementos no gradiente roxo-azul) e **tingida** (cinzentos sobre preto; o iOS aplica a cor escolhida pelo utilizador).
- PNG de 1024 × 1024 sem transparência e sem cantos arredondados (o iOS aplica a máscara).
- O ícone usado na app são os 3 PNG do `AppIcon.appiconset`. A pasta `Design/icon-layers/` (camadas em SVG) é só arquivo: o Icon Composer da Apple só corre em macOS, por isso não faz parte do fluxo atual.

## 11. Ficheiros deste pacote

| Ficheiro | Onde colocar |
| --- | --- |
| `DESIGN.md` | Raiz do repositório, ao lado do `CLAUDE.md`. Acrescentar ao `CLAUDE.md`: "Segue o DESIGN.md para toda a UI." |
| `Assets.xcassets/` | Copiar a pasta inteira para dentro da pasta de fontes da app que o `project.yml` inclui (por exemplo `App/Resources/Assets.xcassets`). Se já existir um, juntar o conteúdo. Contém `AppIcon`, `AccentColor`, `Listas/` e `Estados/`. |
| `Design/icone-preview.png` | Só referência visual (as 3 aparências do ícone). Guardar em `docs/` ou `Design/`; não entra no target. |
| `Design/icon-layers/*.svg` | Só arquivo. Não entra no target. |

No `project.yml` (XcodeGen), confirmar que a pasta do `Assets.xcassets` está nas `sources` do target e que existem estas definições:

```yaml
settings:
  base:
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS: YES
    IPHONEOS_DEPLOYMENT_TARGET: "26.0"
```

Como não há Xcode local, o primeiro build no CI é o teste: se o ícone ou as cores não aparecerem, ver o log do passo `actool` com `gh run view --log-failed`.
