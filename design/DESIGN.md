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

- **Desenvolvimento em Windows, em Swift.** Não há Xcode na máquina de trabalho. Nada neste guia pode depender de abrir o Xcode, o simulador, os SwiftUI Previews ou o Icon Composer.
- O projeto é gerado com **XcodeGen** (`project.yml`) e compilado no **GitHub Actions**, num runner macOS, que também tira as capturas de cada ecrã. Chega ao iPhone pelo **TestFlight**, ou com o `.ipa` sem assinatura da release `ultima` e o iloader.
- Consequências para a UI:
  - O catálogo `Assets.xcassets` é editado como ficheiros (pastas + `Contents.json`). É por isso que este pacote o entrega já montado.
  - A validação visual faz-se instalando no iPhone. Cada ecrã deve ser simples de testar à mão, e a lógica (expiração, durações, contagens) vive no módulo testável que corre no CI.
  - Quando houver dúvidas visuais, o Claude Code deve comparar com os mocks (link no topo) em vez de inventar.

### 2.2 Requisitos

- **Deployment target: iOS 26.0.** O liquid glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`) só existe a partir do iOS 26. [Decidido]
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

- `TabView` nativa com 4 separadores: **Listas, Arquivo, Streak (`flame`), Definições**, com a barra do sistema escondida. [Alterado 08/11/2026, Melhoria 35: Concluídos e Expirados juntam-se no Arquivo, para dar lugar ao Streak.] [Alterado 07/11/2026: o iOS 27 deixou de desenhar o separador de pesquisa à parte e o "+" passava a ser um 5.º separador dentro da barra.]
- **A barra é nossa** (`BarraSeparadores`), com vidro nativo num `GlassEffectContainer`: os 4 separadores numa cápsula `.glassEffect(.regular.interactive())` (ícone e rótulo; o escolhido na cor de destaque, com fundo leve) e, à direita, na mesma linha e separado dela, o **"+" de captura** num círculo de vidro de 62 pt. Fica em `safeAreaInset` em baixo, para o conteúdo nunca ficar escondido.
- O separador Arquivo mostra o contador vermelho dos Expirados quando há itens.
- **"+":** toque abre a Nova nota. **Manter premido** (meio segundo, com vibração) faz nascer por cima, alinhada à direita, uma cápsula de vidro com o quadrado com visto (`checkmark.square.fill`) e "Nova lista". **Arrastar o dedo até ela e largar** abre a Nova lista; com o dedo em cima a cápsula fica azul e cresce um pouco (vibração leve). Largar noutro sítio não faz nada. No VoiceOver, a ação "Nova lista". Com 8 espaços, mostra o aviso do máximo. [Decidido 07/11/2026: opção B, "bolha com nome"]
- O Detalhe esconde a barra (tem o Manter no fundo, 7.5).
- A barra deixa de encolher ao percorrer (era o `.tabBarMinimizeBehavior` da barra do sistema).
- O conteúdo percorre **por baixo** da barra (é isso que dá o efeito de vidro), mas a última linha tem de ficar visível quando se chega ao fim.

### 7.2 Cartão de lista (Início)

- Grelha de 2 colunas. Cada cartão tem 128 pt de altura [alterado 08/11/2026, Melhoria 35: era 148, para o Início ter mais ecrã] e é preenchido com a cor base, com uma sombra suave da mesma cor (opacidade ~30%, raio 16).
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
- Logo abaixo, título de secção "Descrição" e o campo "Acrescentar descrição" (até 3 linhas, como no Detalhe) e a fila de fotos com o quadrado tracejado "Biblioteca" de 72 pt, sempre à vista mesmo sem teclado.
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

- **[Decidido 08/11/2026, Melhoria 35] Arquivo:** Expirados e Concluídos (7.11) são os dois lados de uma só página "Arquivo", com um controlo segmentado **Concluídos | Expirados · N** por baixo do título. Cada lado guarda os seus filtros. Nos Expirados, com pontos a expirar hoje, aparece por cima o botão de vidro "Rever N pontos que expiram hoje" (7.25).

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
  3. **Notificações**: interruptor "Avisar antes de expirar", "Quando" (24 horas antes · De manhã · À noite, como no questionário, 7.20b) e "Hora dos avisos".
  4. **Aparência** [Decidido 07/11/2026]: controlo segmentado **Sistema · Claro · Escuro · Reativo**. Reativo é claro de dia e escuro depois do pôr do sol (o sol de Lisboa, sem localização). O widget continua a seguir o modo do iPhone.
  5. **O teu ritmo** [Decidido 07/11/2026, mock Questionário]: "Um ponto fica" (dias), "Avisos" ("De manhã, às 09:00") e "Responder outra vez às perguntas", que abre só o ritmo e os avisos.
  6. **Avançado**: "Prazos" (valor resumido "3 · 5 · 15 dias"; abre um ecrã com as cinco durações) e "Importar e backup".
- Ícones das linhas em círculos coloridos de 30 pt, como nos Ajustes do iOS.

### 7.12 Calendário no Início (mocks 7 e 8)

**O calendário nunca impede a app de abrir:** se a app morrer ou ficar bloqueada ao abrir com os eventos, durante a leitura ou nos 10 segundos seguintes, na abertura seguinte não volta a ler e mostra o cartão "Não foi possível ler o calendário", com "Tentar outra vez" e "Agora não".

**Revisão de 28/10/2026 [Decidido]:**
- **Recolher o que passou:** os eventos que já acabaram ficam recolhidos numa linha "2 já passaram", que abre com um toque e mostra-os esbatidos. O cabeçalho diz "3 por vir".
- **O que está a decorrer:** a barra na cor do evento fica mais grossa e pulsa devagar (fica parada com "Reduzir movimento"), com um fundo suave na mesma cor. Por baixo do título aparece "A decorrer · até 15:18 · local". Substitui a etiqueta vermelha "AGORA", que cortava o título.
- **O que vem a seguir:** os eventos das próximas 3 horas mostram "daqui a 20 min" ou "daqui a 1 h".
- **O "+" e o ✓:** o "+" passa a ser um ícone leve, sem círculo, na cor do destino. O ✓ de "já adicionado" fica na cor da lista.


- Lugar: logo a seguir à grelha de espaços; "Expiram hoje" fica no fundo do Início, por baixo do calendário. Quando há itens a expirar hoje, um aviso no topo ("N itens expiram hoje", `clock.badge.exclamationmark`) desce até essa secção. O conteúdo percorre por baixo da barra de separadores. [Decidido 22/10/2026]
- **Por ligar (mock 7)**: cartão branco de 18 pt de raio com o ícone `calendar` num círculo azul de 40 pt, o título "Junta o teu calendário", a frase "Vê os eventos de hoje por baixo das listas e cria pontos a partir deles.", três fichas (Apple, Google, Outlook, cada uma com um ponto da sua cor), o botão em cápsula "Ligar calendário" na cor de destaque e a nota "Lê só no iPhone: usa as contas Google e Outlook que já tens nos Ajustes." O cartão pode fechar-se ("Agora não") e volta a estar em Definições.
- **Ligado (mock 8)**: cabeçalho "HOJE NO CALENDÁRIO" com "Ver semana" à direita; grupo branco com uma linha por evento (58 pt): hora de início e fim, barra vertical de 4 pt na cor do calendário, título (`.body` semibold) e local ou calendário (`.footnote`), ficha vermelha "AGORA" no evento a decorrer e um botão "+" (círculo de 30 pt na cor Fundo da lista de destino, alvo de 44 pt) para criar um ponto a partir do evento.
- Sem eventos hoje: uma linha "Nada no calendário hoje".
- Ícones: `calendar`, `plus`. Cores dos calendários: as que o iOS dá a cada calendário.

### 7.12b Espaços com setas e calendário por espaço (mocks 11–14)

- **Mais de 4 espaços**: cartões de 112 pt, com ícone de 32 pt, anel de 34 pt e número de 30 pt [alterado 08/11/2026, Melhoria 35: era 128] (2 × 2 por página) e, por baixo, uma linha com duas setas de vidro (círculos de 44 pt, `chevron.left`/`chevron.right`; a do lado sem mais páginas fica esbatida), pontos de página e "Espaços 1–4 de 6". Deslizar na grelha também muda de página (`TabView` com `.page` ou `ScrollView` paginado). Até 3 espaços, sem setas, como antes.
- **Exatamente 4 espaços**: a primeira página fica cheia, por isso já há uma segunda página, só com o cartão "Nova lista" (rótulo "Nova lista" em vez de "Espaços 5–…").
- **Máximo de 8**: na última página, "Nova lista" só aparece se houver menos de 8; com 8, aparece a nota "Máximo de 8 espaços".
- **Manter premido o "+"** de baixo e arrastar até "Nova lista" (7.1); com 8, mostra o aviso do máximo. O toque curto continua a abrir a captura.
- **Hoje no calendário por espaço** [Decidido]: eventos de todos os espaços, num só grupo branco, por hora. Cabeçalho "HOJE NO CALENDÁRIO" com "4 eventos · todos os espaços". Cada linha (62 pt): horas, barra da cor do calendário, título e, por baixo, o espaço (círculo do ícone de 18 pt, nome em `.footnote` semibold) e o local. O "+" fica na cor do espaço e cria o ponto nesse espaço. Calendários sem espaço não aparecem. **Próximos dias** [Decidido a pedido do Hugo, 8/11]: por baixo de "Hoje" vêm "Amanhã" e os dias da semana seguintes (`JanelaEventos`; 3 dias por defeito, de 1 a 7 em Definições › Calendário › "Dias no Início", um `Stepper`), cada um num grupo branco igual, sempre à vista e com "Sem eventos" se vazio; só "Hoje" recolhe os que já passaram.
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

- **Médio "O que importa agora" [Decidido 28/10/2026: variante B]:**
  - À esquerda, o número grande e arredondado do dia ("1 expira hoje", em laranja; sem nada a expirar, os pontos ativos) e, por baixo, a frase em até 3 linhas: escrita pelo modelo do iPhone, ou a de base ("Nada urgente hoje").
  - À direita, os 3 pontos escolhidos pela prioridade do núcleo (`Tarefas.prioridades`: último dia, falta 1 subtópico, dias sem mexer). Cada um tem o anel na cor da lista (laranja no último dia), o título e a razão. **Tocar no anel conclui** sem abrir a app.
  - No canto, o "+" abre a captura (`todo://captura`).
  - Fundo em gradiente da cor de fundo da lista do primeiro ponto para o fundo do sistema.
  - Uma entrada por hora, para os anéis esvaziarem com animação; os pontos trocam com `push` de baixo.
- **A mascote, o Glassy [Decidido 04/11/2026, substitui o desenho de 28/10/2026]:** ampulheta 3D de vidro e madeira (`Widgets/Mascote.swift`), feita por camadas das imagens originais, que ficam fora do repositório, em `Glassy2/` (`scripts/glassy-assets.ps1`), com a areia desenhada entre elas. A areia é a pressão do tempo (`EstadoGlassy`): em cima sem nada a fechar, a descer com os pontos no último dia. Cada pose tem o seu cenário:
  - **manhã:** acena, em céu quente com sol;
  - **tarde:** vê a areia cair, em céu com nuvens;
  - **tudo em dia:** braços no ar e areia em cima, em verde com confettis;
  - **noite (23h–7h):** de pé, de olhos fechados, com os "z" e a areia parada, porque o tempo pára enquanto dormes, com lua e estrelas;
  - **preocupado:** metade da areia em baixo ou mais (3 pontos no último dia), mãos ao peito, em céu âmbar;
  - **ko:** expirou tudo, nada concluído em 24 horas e nenhum ponto ativo: vidro rachado, olho negro e areia toda em baixo, em cinzento. Vence a noite.

  A pose segue o dia, mas o cenário segue o modo do iPhone, como o céu da app (7.23): no modo escuro é sempre a noite com lua e estrelas, e no claro nunca é noite (o sono acontece debaixo do céu de nuvens). Só o ko mantém o cinzento nos dois.

  Com a app fechada, o widget continua certo: o resumo leva as datas de todos os prazos (`DatasGlassy`), e cada entrada da timeline calcula os pontos, as razões, os números e o Glassy dessa hora (`ResumoWidget.noMomento`). Assim chega ao ko sem a app abrir.

  Ao lado, um título e uma linha ("Bom dia! / Nada pendente por agora."), e "+ Nova nota" no canto. Com pontos, fica pequeno ao lado do número, só no modo a cores. O widget não toca animações contínuas (regra do iOS): tem uma entrada da timeline de 20 em 20 minutos, a pose e a areia mudam e o WidgetKit anima a troca. Na app está vivo: respira, pisca, mexe os braços e a areia corre, exceto com "Reduzir movimento".
- **A Ampulheta conhece a pessoa [Decidido 28/10/2026]:** de dia, as poses mudam de tema conforme o uso (`Tarefas.temaMascote`, tudo no iPhone):
  - **Tema de cada lista:** vem do ícone, do emoji ou do nome (maleta é trabalho; avião é viagem; haltere é desporto; pessoa, casa, livro ou coração é vida pessoal).
  - **Tema do widget:** o das listas com mais atividade nos últimos 7 dias. Uma viagem com pontos abertos ganha sempre.
  - **Trabalho:** escritório claro com janela e secretária, a Ampulheta ao portátil com café. "Foco no trabalho."
  - **Vida pessoal:** parque com sol, relva e árvore, a ler um livro. "Tempo para ti."
  - **Viagem:** cabine de avião, sentada ao lado da janela. "Boa viagem!"
  - O desporto usa, por agora, o cenário da vida pessoal. Celebrar e dormir são iguais em todos os temas.
- **Ecrã bloqueado:** um "+" circular e um retangular "Nova nota · 1 ponto expira hoje", e o controlo **Nova nota** (botões do ecrã bloqueado, Centro de Controlo, Action Button). Todos abrem a captura.
- **Dados:** a app grava `resumo-widget.json` no App Group `group.com.hugo.tudo` sempre que algo muda (`Notificacoes.atualizarWidget`). A base de dados também passa para o grupo, para o widget poder concluir. Demonstração: `-ecra widget`.
- Seguintes: o pequeno (um ponto, anel grande) e o grande.
- Estilo: **simples, claros, limpos e informativos.** Pouca informação, boa hierarquia de texto (título, contagem grande e arredondada, uma linha de prazo), sem decoração nem vidro. A cor da lista e o anel (7.3) são os únicos elementos gráficos.
- Pequeno: os próximos itens a expirar, com anel. Médio: uma lista escolhida (configurável), com 3 a 4 itens e a contagem. Ecrã bloqueado: circular (anel + itens que expiram hoje) e retangular (próximo item).
- Botões interativos: Concluir e Manter +5.
- Técnica: extensão WidgetKit e App Group `group.com.hugo.tudo` para partilhar a base de dados. Validar primeiro com um widget mínimo que o sideload gratuito aceita a extensão e o App Group.

### 7.15 Vistas partilhadas [Decidido 28/10/2026 · Proposta: forma]

- **Nome [Decidido 28/10/2026]:** "Vista partilhada", e não "Compras", que era demasiado nicho. Organiza-se por **secções** (uma loja, uma divisão da casa, um dia da viagem) com pontos que se riscam: "por fazer" e "feitos". No código e nos dados, o tipo continua a chamar-se `compras`.

- Tipo de lista **Compras**: secções por loja (Continente, IKEA…) com "3 de 8". Tocar risca o artigo. Não tem anel nem prazo, porque os artigos não expiram.
- **Presença automática, como os avatares do Figma:** a cara (ou as iniciais) de cada pessoa aparece no cabeçalho da loja que ela tem aberta no ecrã naquele momento. Não diz onde a pessoa está fisicamente e ninguém escolhe nada: abrir a vista do IKEA põe lá a tua cara. Se ninguém mexer, a presença desaparece ao fim de uns minutos. [Decidido 28/10/2026]
- A foto do Apple ID não está acessível às apps. A cara é uma foto escolhida na app (PhotosPicker) ou as iniciais na cor da pessoa.
- A captura numa lista de compras escolhe a loja e aceita vários artigos seguidos.
- No menu "…": "Partilhar por AirDrop" envia um ficheiro `.todolista`. Abri-lo no outro iPhone cria a lista ou junta as duas cópias (por id, ganha a alteração mais recente). O tempo real vem depois, com o serviço escolhido.

### 7.19 Backup e iCloud [Decidido 28/10/2026]

- **Se os dados não abrirem:** a app não se fecha. Mostra "Não foi possível abrir os teus dados", diz que nada foi alterado e deixa partilhar o texto do erro.
- **A cópia contínua é o iCloud:** a base de dados sincroniza sozinha com o iCloud privado da pessoa (SwiftData com CloudKit), sobrevive a apagar a app e passa para um iPhone novo. Precisa da conta Apple Developer paga.
  - **Pronto já:** o esquema V6, sem atributos únicos, com valores por defeito e relações opcionais, como o CloudKit exige, e o contentor em `.automatic`, que não sincroniza sem as entitlements.
  - **No dia da conta:** juntar as entitlements do iCloud e do CloudKit (comentadas no `project.yml`) e testar com dois aparelhos.
- **Cópia manual em JSON** (`Backup`, Definições › Backup):
  - **Exportar:** tudo (listas, itens, subtópicos, fotos e definições) para onde a pessoa quiser: iCloud Drive, Ficheiros ou AirDrop.
  - **Restaurar:** de um ficheiro, com um resumo antes de confirmar ("Entram 1 lista nova, 4 pontos novos… Nada é apagado"). Junta por id, e numa instalação nova junta as listas pelo nome. Ganha a alteração mais recente.
  - **Um backup antigo não apaga nada na abertura seguinte:** o que já venceu entra com tempo novo (um ponto ativo ganha um prazo novo; um expirado ou concluído recomeça a retenção; uma lista vazia recomeça a contagem).
  - **As definições passam a ser as do backup**, dentro dos limites dos ecrãs e sem encurtar as retenções nem o tempo das listas vazias.
  - **Máximo de 8 listas:** as listas locais vazias dão lugar às do backup, e o resumo diz quantas saem. Se mesmo assim não couberem, o restauro é recusado antes de mudar seja o que for.
  - Serve para mudar de instalação sem perder nada, por exemplo antes de reinstalar com a conta paga.
- Não há backup automático semanal: no iPhone, ia-se com a app; com o iCloud, deixa de ser preciso.
- As **listas de compras partilhadas ao vivo** precisam da partilha do CloudKit (`CKShare`), que o SwiftData ainda não faz sozinho: é trabalho à parte.

### 7.21 Cartão "Para ti" no Início [Decidido 28/10/2026]

- No topo do Início, logo a seguir à data: o que importa agora numa frase curta (até 2 linhas, com a hora antes dos nomes) e até 2 botões. É compacto: brilhos à esquerda, "x" à direita para o dispensar até o assunto mudar, e um contorno suave em gradiente (índigo, rosa, laranja) a marcar que é uma sugestão.
- **O núcleo decide o que é relevante** (`Tarefas.paraTi`), por esta ordem:
  1. pontos no último dia: "Rever" (abre as cartas, 7.25) e "Abrir" [alterado 08/11/2026, Melhoria 35: era "Abrir" e "Manter +5"]; conta os mesmos pontos que as cartas (`Tarefas.emRisco`);
  2. uma lista vazia que sai nas próximas 24 h: "Tornar permanente" e "Mais 5 dias";
  3. um evento nas próximas 3 h cujo espaço tem um ponto com subtópicos por fazer: "Ver subtópicos";
  4. uma vista partilhada a meio, mexida nos últimos 2 dias: "Abrir …".
- O modelo do iPhone só reescreve a frase, a partir dos factos; sem ele, fica a frase de base.
- **Sem nada relevante, o cartão não aparece.**
- Substitui os avisos antigos do topo ("4 itens em Expirados" e "3 itens expiram hoje"). O número de itens em Expirados continua no separador da barra de baixo.

### 7.22 A Ampulheta anfitriã no Início [Decidido 02/11/2026: direção A, com o final da B]
- A Ampulheta fica no topo do Início, com um balão no lugar do antigo cartão "Para ti". O balão diz, por esta ordem: "Boa! Menos um." com Anular durante 4 s, a sugestão de "Para ti", ou a frase do dia.
- **A areia é a pressão do tempo [Alterado 04/11/2026]:** desce com os pontos no último dia do prazo (`EstadoGlassy`). Sem pontos para hoje, fica toda em cima. A festa continua a depender de `ProgressoDia`: só com algo concluído.
- **Concluir:** o círculo salta, com faíscas; no Início, um grão de areia voa até ao bolbo de cima do Glassy, que salta ao recebê-lo, e a areia sobe. Tocar nele também o faz saltar.
- **Dia ganho:** uma vez por dia, em qualquer ecrã, saem confettis com vibração; o Início ganha o cenário verde e um fundo esverdeado. Com "Reduzir movimento" não há grão, faíscas, saltos nem confettis.
- "Expiram hoje" passa para cima do calendário, com o círculo de concluir na própria linha. As linhas da lista ganham um pouco da cor da lista.

### 7.23 O céu [Decidido 02/11/2026; alterado 04/11/2026: segue o modo do iPhone, não a hora]
- O preto sai de todos os ecrãs. O fundo é um céu (`CeuDoDia`) que depende só do modo do iPhone: o **claro é sempre dia** (azul, com sol) e o **escuro é sempre noite** (índigo, com lua e estrelas). O dia ganho fica verde, exceto no modo escuro.
- O Início tem a cena com colinas; os outros ecrãs só a cor do céu; as listas e os detalhes mantêm o fundo na cor da lista.
- Por defeito segue o modo do sistema; em Definições › Aparência pode ficar sempre claro, sempre escuro ou **Reativo** (7.11), e o céu acompanha.
- O Glassy saúda pelo relógio, em qualquer modo: "Bom dia!" das 6h às 12h, "Boa tarde!" até às 20h e "Boa noite!" depois.

### 7.24 Widget "O teu ritmo" [Decidido 07/11/2026, mock 2 em `design/mocks/html/Engagement.html`]
- Cada dia é **binário**: **verde** (✓, `EstadoConcluido`) se concluíste um ponto, **vermelho** (✕, `ListaVermelho`) se algo expirou e nada foi concluído, **neutro** (contorno tracejado) sem atividade. Num dia com as duas coisas, o verde ganha. Fechar 1 ponto ou mil dá o mesmo dia: nunca se mostram contagens de pontos, só de dias.
- **Pequeno:** "O teu ritmo", o número de dias verdes em 7 e uma linha de 7 dias com a inicial por baixo. **Médio:** 15 dias numa grelha de 5 × 3, o número à esquerda e o Glassy pequeno por baixo.
- Hoje tem um anel à volta. A marca (✓, ✕, tracejado) diz o mesmo que a cor, também no modo tingido; cada dia tem rótulo para o VoiceOver ("Quarta, 21 out: concluíste pontos").
- Contam os pontos principais fora das listas de compras. Dias sem registo ficam neutros.

### 7.25 Fecho do dia [Decidido 07/11/2026, mock 1B em `design/mocks/html/Engagement.html`]
- À hora escolhida (por defeito 21:00, sempre entre as 08:00 e as 22:00), quando há pontos no último dia do prazo: uma **notificação** "Fecho do dia · Fechas o dia? N pontos chegam ao fim.", a mesma frase no **Glassy** do Início com o botão "Fechar o dia" e, no **widget médio** "O teu ritmo", a cápsula "Fechar o dia" no lugar do Glassy. Sem pontos em risco, com os avisos desligados, ou depois de fechares o dia (sair do ecrã de cartas, mesmo a meio), nada aparece até ao fecho seguinte.
- Tocar abre o **ecrã de cartas**: um ponto de cada vez, com a lista, o anel laranja "Hoje", o título e "Expira amanhã às 06:38". Botões **Concluir** (verde, proeminente), **Manter +5**, **Manter +15** e **Deixar ir** (passa à frente: o ponto expira no prazo dele). Deslizar o cartão → mantém, ← deixa ir; os botões fazem o mesmo.
- No fim, o Glassy celebra ("Dia verde! Bom trabalho.") ou fica calmo ("Dia fechado."), com "Concluíste 1, mantiveste 1, deixaste ir 1."
- Em Definições › Notificações: "Fecho do dia" ligado ou desligado e a hora.
- **Rever [Decidido 08/11/2026, Melhoria 35]:** as mesmas cartas a qualquer hora, com o título "Rever": no Início, pelo botão "Rever" do balão do Glassy sempre que há pontos a expirar hoje (7.21; depois da hora do fecho, o balão mostra "Fechar o dia", que abre as mesmas cartas); e pelo botão dos Expirados. Mostra os pontos que expiram hoje; sair não dá o dia por fechado. No fim, "Tudo revisto." (ou "Dia verde!").

### 7.26 O teu mês [Decidido 08/11/2026, Melhoria 35]
- [Alterado 08/11/2026: o Início ficava cheio de mais; a vista de calendário fica só no Streak.] **"O teu mês"** vive no separador **Streak** (7.27), com as bolas do widget (7.24): ✓ verde, ✕ vermelho, tracejado neutro; os dias por vir são só uma sombra cinzenta, e hoje tem anel. Mostra a grelha do mês (segunda primeiro), o título "Novembro de 2026" com "N dias verdes", setas de vidro ‹ › e deslizar para mudar de mês, entre o primeiro mês com registo e o atual (sem futuro), e a legenda com as três marcas.

### 7.27 Streak: grãos e cenários [Decidido 08/11/2026, Melhoria 35; mock "O mundo do Glassy", B, em `design/mocks/html/Engagement.html`]
- **Grãos** de areia (não "pontos": ponto é uma tarefa): **1 por dia verde**, nunca por ponto. Gastam-se a desbloquear cenários; um grão ganho nunca se tira. O totalizador do Streak usa `hourglass.bottomhalf.filled` num círculo laranja.
- **Separador Streak** [Decidido 08/11/2026: o nome é "Streak", não "Cenários"]: é a página do teu ritmo. Por ordem: o totalizador ("7 grãos disponíveis", "N de 6 cenários são teus"), **O teu mês** (7.26) e **Cenários**, a coleção numa grelha de 2. No futuro, com backend, entra aqui o **ranking com amigos** (ideia 4B do Engagement.html), ainda por desenhar. O nome muda, a regra não: nada volta a zero, um dia falhado não tira grãos. Cada cenário: miniatura, nome e estado ("Em uso" com contorno verde e ✓, "Teu · tocar para usar", "Desbloquear · N grãos" ou "Faltam N grãos" com cadeado e a miniatura dessaturada). Comprar pede confirmação e passa logo a usar.
- **Catálogo (proposta de preços):** Céu (grátis, o de sempre), Parque 3, Praia 7, Biblioteca 10, Viagem 14, Montanha 21. Desenhados em SwiftUI, cada um com versão de dia e de noite, como o céu (7.23).
- O cenário escolhido é o **fundo do Início**; os outros ecrãs ficam com o céu. Com um cenário comprado, o dia ganho não pinta o fundo de verde (ficam os confettis).

### 7.20 Iniciar sessão com a Apple (opcional) [Decidido 28/10/2026]

- **Para que serve:** dá um identificador estável e privado, o mesmo em qualquer aparelho, que ligará os dados à pessoa se um dia houver outra forma de lá chegar (web, outra plataforma, um servidor). Não é o login que guarda os dados: isso é o iCloud (7.19).
- **Primeira abertura:** o botão do sistema "Iniciar sessão com a Apple" fica no fim do questionário (7.20b), por baixo de "Começar a usar". Não volta a aparecer.
- **Definições › Conta (no topo):** com sessão, a inicial, o nome e o email e "Terminar sessão" (não apaga nada); sem sessão, o botão.
- **Técnica:**
  - O identificador e o perfil (o nome e o email, que a Apple só dá na primeira vez) ficam no Keychain. "Terminar sessão" apaga só o identificador: o perfil volta quando a mesma conta entra outra vez. Uma conta diferente nunca herda o perfil da anterior.
  - Ao abrir e ao voltar à app, verifica se o acesso foi revogado nos Ajustes. Revogado, a sessão termina e o perfil é apagado. Se a verificação falhar (sem rede), a sessão fica.
  - Se o iOS não conseguir tratar do pedido, a app pede para confirmar nos Ajustes a conta Apple. Cancelar não mostra erro.
- **Capacidade:** `com.apple.developer.applesignin` está ligada no `project.yml` desde a conta paga (docs/CONTA-DEVELOPER.md).

### 7.20b Questionário da primeira abertura [Decidido 07/11/2026, mock `design/mocks/Questionario.png`]

- Ecrã inteiro no céu (`QuestionarioView`), com colinas e o Glassy na entrada e no fim. Três perguntas, todas com valores já escolhidos, para quem só quer carregar em Continuar; o passo aparece em três traços no topo.
  1. **Ritmo:** "Quanto tempo fica um ponto sem ações?", slider de 2 a 15 dias (3 é o sugerido; em Avançado continua até 30) e a prévia "Um ponto criado hoje sai na quinta, 12 nov."
  2. **Avisos:** 24 horas antes (à hora exata; de madrugada passa para a manhã) · De manhã (na véspera) · À noite (na véspera), com a hora dentro da opção escolhida. A hora fica sempre entre as 08:00 e as 22:00.
  3. **Uso:** grelha com Trabalho, Estudos, Casa e Compras ("Aqui nada expira"). Pessoal fica sempre. Cria os primeiros espaços (só os 4 primeiros nascem permanentes: com os 5, Compras não).
- **Entrada:** "Bem-vindo à ToDo", Começar e **Saltar** (fica com os valores de hoje e com Trabalho e Pessoal). **Fim:** "Está pronto", "Começar a usar" e o login opcional da Apple (7.20).
- **Quem já usa a app** vê uma vez o convite "Ajusta a ToDo ao teu ritmo" (ficha "Novo"), com Ajustar (só ritmo e avisos) e Agora não. Os espaços que já tem não mudam.
- Numa instalação nova, os primeiros espaços só se criam no fim do questionário (ou ao saltar).

### 7.18 Ecrãs vazios com a Ampulheta [Decidido 28/10/2026]

- Os ecrãs vazios usam a mesma mascote do widget (`EstadoVazio`), que flutua devagar como quem respira (fica parada com "Reduzir movimento"):
  - **Expirados vazio:** a celebrar, "Nada expirou. Estás em dia.";
  - **Concluídos vazio:** a ver a areia cair, "Ainda nada concluído";
  - **Lista vazia:** a acenar, "Nada por fazer", e, se a lista não for permanente, quando sai do Início.

### 7.17 Listas que desaparecem e listas permanentes [Decidido 28/10/2026 · Proposta: detalhes]

- No máximo 8 listas. Uma lista **sem pontos abertos** durante 5 dias (`Definicoes.diasListaVazia`) desaparece do Início. [Alterado 04/11/2026: já não leva o que lá estiver concluído, porque Concluir promete 7 dias para reabrir; a lista espera por eles.]
- **Aviso 24 h antes**, com a mesma regra da noite: título "«Ideias» vai desaparecer", corpo "Sem pontos abertos há 4 dias. Sai amanhã às 15:30, a não ser que a mantenhas." Ações:
  - **Manter mais 5 dias**: a contagem recomeça;
  - **Tornar permanente**: com as 4 ocupadas, mantém mais 5 dias.
- **Permanentes:** até 4, no menu "…" da lista ("Tornar permanente", símbolo `infinity`). Nunca desaparecem.
- **No cartão do Início**, numa lista vazia que vai sair, o número grande passa a ser os dias que faltam ("3 dias para sair") e o anel esvazia ao longo dos 5 dias. Com a lista aberta e vazia, o ecrã diz quando sai e como a guardar.
- **[Proposta]** Itens em Expirados e em Concluídos seguram a lista até voltarem ou serem apagados, porque nada se perde por engano. Trabalho e Pessoal nascem permanentes. Ao atualizar a app, as 4 primeiras listas existentes ficam permanentes.

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

## 10. Ícone da app [Decidido 28/10/2026: proposta B, Anel]

- **Atual:** a Ampulheta (sem braços) dentro do anel do prazo, três quartos cheio. Junta as duas assinaturas da app.
  - **Claro:** o gradiente roxo (#A050E0) → azul (#0A60EE) de sempre, com um brilho no canto.
  - **Escuro:** noite índigo com estrelas.
  - **Tingido:** cinzentos sobre preto.
- Gerado a partir do desenho anterior da mascote, com um script SwiftUI `ImageRenderer` a 1024 px. Ainda não foi atualizado para o Glassy (7.14): esse desenho já não existe no código.
- O ícone usado na app são os 3 PNG do `AppIcon.appiconset` (`design/icone/README.md` explica como os trocar): 1024 × 1024, sem transparência e sem cantos arredondados (o iOS aplica a máscara).
