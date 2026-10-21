# Guia de UI — App ToDo pessoal (v1)

Versão 1.1 · 21 de outubro de 2026 · Complementa o `CLAUDE.md` e a especificação funcional.

Novidades da 1.1: Definições reorganizadas (7.11), calendário no Início (7.12), descrição curta nos pontos (7.13), aparência a seguir o iPhone (1.6).

Este documento fixa as decisões visuais e de interação da v1. Quem implementa deve segui-lo à letra no que está **[Decidido]**. Nas **[Proposta]**, deve seguir o texto e assinalar dúvidas em vez de inventar.

Referência visual (mocks iteráveis): https://claude.ai/artifact/HUdHGgoDoZwCJDAjwnshfj

- Artboards 1–6: Início, Lista, Detalhe + Manter, Captura, Expirados, Personalizar lista. Também: ícone e os 4 estados do Manter.
- Artboards 7–11 (v1.1): 7 Início — ligar calendário · 8 Início — hoje no calendário · 9 Definições reorganizadas · 10 Detalhe com descrição.

---

## 1. Princípios visuais

1. **Nativo primeiro.** SwiftUI e componentes do sistema (TabView, NavigationStack, sheet, PhotosPicker, SF Symbols). Não desenhar à mão o que o iOS já dá. [Decidido]
2. **Liquid glass do sistema.** A barra de separadores, as barras de ferramentas e os botões flutuantes usam o material de vidro nativo do iOS 26+, nunca uma imitação com blur. [Decidido]
3. **Cor com significado.** Cada lista tem uma cor e um ícone. A cor pinta o cartão da lista, o fundo dos ecrãs dessa lista e o anel de cada item. [Decidido]
4. **O anel conta o tempo.** Cada item mostra um anel que se esvazia nos 3 dias. No último dia fica laranja. É o elemento-assinatura da app. [Decidido]
5. **Nada sai do ecrã.** Todo o conteúdo cabe na largura e altura disponíveis, respeita as safe areas e nunca fica por baixo da barra de separadores sem poder ser percorrido. [Decidido]
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

### 7.4 Linha de item

Anel · título (1 linha, com reticências) · metadados ("2/4 subtópicos · 2 fotos", com o ícone `photo` quando há fotos) · tempo restante. Toque abre o Detalhe. Swipe para a esquerda: Apagar. Swipe para a direita: Manter +5. [Proposta para os swipes]

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
- Voltar ao centro antes de soltar cancela, e as bolhas recolhem para dentro da cápsula.
- A linha de ajuda acima do botão muda com o estado: "Toque: +5 dias · Premir e arrastar para escolher" → "Arrasta para um dos lados" → "Solta para manter mais 5/15 dias".
- Depois de confirmar: vibração `.success`, as bolhas recolhem e o anel do topo anima até ao novo valor.
- **Fixar, Concluir e "…"** saem da barra de baixo e vão para um grupo de vidro no canto superior direito da barra de navegação. No Detalhe, a barra de separadores fica escondida (`.toolbar(.hidden, for: .tabBar)`); o botão Manter ocupa o fundo do ecrã sozinho.

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

- Fundo `EstadoExpiradosFundo`. Cabeçalho com o ícone `hourglass` num círculo laranja e o texto "Ficam aqui 14 dias antes de serem apagados".
- Cartão por item: ícone da lista, título, "Lista · apagado em N dias", botão **Recuperar** (cápsula laranja clara) e botão Apagar (círculo cinzento).
- No Início há um aviso permanente "N itens em Expirados" que leva a este ecrã, sempre que N > 0.

### 7.10 Ecrãs Lista e Detalhe

- O fundo é a cor Fundo da lista. O título e o "voltar" usam a cor Tinta.
- Lista: cabeçalho com o círculo do ícone (56 pt) + nome + "N ativos · M expiram hoje"; depois as secções **Fixados** e **Ativos**.
- Detalhe: grupo de vidro no topo direito (Fixar, Concluir, "…") · anel grande + "Expira em N dias" + "Última ação …" · título · Fotos · Subtópicos (com "+" no cabeçalho da secção) · botão Manter em gotas de vidro no fundo (7.5).

### 7.11 Concluídos e Definições

- Concluídos: sem mock. Fundo agrupado do sistema, `List` `.insetGrouped`, ícone da lista em círculo, "Concluído hoje, 18:40", deslizar para Reabrir e Apagar.
- **Definições (mock 9)** [Decidido 21/10/2026: gerir listas primeiro; menos controlos de horários]. `Form` agrupado, por esta ordem:
  1. **Listas**: uma linha por lista (ícone em círculo de 30 pt, nome, número de ativos, pega para arrastar). Tocar abre Personalizar lista. Última linha "+ Nova lista" na cor de destaque. Ordenar arrastando, sem botão Editar.
  2. **Calendário**: "Calendários" (valor: as fontes ligadas, por exemplo "Apple, Outlook") leva à escolha dos calendários; interruptor "Mostrar eventos no Início". Sem ligação: uma só linha "Ligar calendário".
  3. **Notificações**: interruptor "Avisar antes de expirar" e "Hora dos avisos" (só a hora; nada de outros horários).
  4. **Aparência**: controlo segmentado Sistema · Claro · Escuro.
  5. **Avançado**: "Prazos" (valor resumido "3 · 5 · 15 dias"; abre um ecrã com as cinco durações) e "Importar e backup".
- Ícones das linhas em círculos coloridos de 30 pt, como nos Ajustes do iOS.

### 7.12 Calendário no Início (mocks 7 e 8)

- Lugar: o fundo do Início, por baixo da grelha de listas e de "Expiram hoje". O conteúdo percorre por baixo da barra de separadores.
- **Por ligar (mock 7)**: cartão branco de 18 pt de raio com o ícone `calendar` num círculo azul de 40 pt, o título "Junta o teu calendário", a frase "Vê os eventos de hoje por baixo das listas e cria pontos a partir deles.", três fichas (Apple, Google, Outlook, cada uma com um ponto da sua cor), o botão em cápsula "Ligar calendário" na cor de destaque e a nota "Lê só no iPhone: usa as contas Google e Outlook que já tens nos Ajustes." O cartão pode fechar-se ("Agora não") e volta a estar em Definições.
- **Ligado (mock 8)**: cabeçalho "HOJE NO CALENDÁRIO" com "Ver semana" à direita; grupo branco com uma linha por evento (58 pt): hora de início e fim, barra vertical de 4 pt na cor do calendário, título (`.body` semibold) e local ou calendário (`.footnote`), ficha vermelha "AGORA" no evento a decorrer e um botão "+" (círculo de 30 pt na cor Fundo da lista de destino, alvo de 44 pt) para criar um ponto a partir do evento.
- Sem eventos hoje: uma linha "Nada no calendário hoje".
- Ícones: `calendar`, `plus`. Cores dos calendários: as que o iOS dá a cada calendário.

### 7.13 Descrição curta e Concluir (mock 10) [Decidido 21/10/2026]

- **Descrição**: logo abaixo do título do Detalhe, sem cabeçalho nem cartão, em `.body` `.secondary`, no máximo 3 linhas (200 caracteres). Edita-se no lugar; vazia mostra "Acrescentar descrição".
- **Subtópicos**: ficam como estão (círculo + texto); sem descrição, sem fotos. O + à esquerda do campo de novo subtópico também guarda.
- **Concluir**: o visto verde fica no grupo de vidro do topo e há também "Concluir" no menu "…".
- Na Lista, um ponto com descrição mostra "descrição" nos metadados ("2/4 subtópicos · descrição · 2 fotos").

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
