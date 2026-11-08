import SwiftUI
import ToDoCore

/// Escala de espaçamento (DESIGN.md 5). Nenhum ecrã define margens à mão: usa estes valores
/// e o `EcraBase`.
enum Espaco {
    /// Margem lateral dos ecrãs.
    static let margem: CGFloat = 20
    /// Entre blocos de um ecrã e dentro dos cartões.
    static let bloco: CGFloat = 16
    /// Entre cartões da grelha e entre um ícone e o seu texto.
    static let grelha: CGFloat = 12
    /// Altura mínima das linhas de item e de subtópico.
    static let linhaItem: CGFloat = 62
    static let linhaSubtopico: CGFloat = 46

    // Passos pequenos, dentro dos componentes.
    static let curto: CGFloat = 8
    static let fino: CGFloat = 4
    static let minimo: CGFloat = 2

    /// Depois do último bloco, para a última linha não ficar colada à barra de separadores.
    static let fim: CGFloat = 24
}

/// Cabeçalho dos ecrãs de topo, igual ao do Início: uma linha pequena (a data
/// no Início; nos outros fica reservada, para o título ficar sempre à mesma altura) e o
/// título grande. O acessório (por exemplo, um filtro) fica à direita do título.
struct CabecalhoEcra<Acessorio: View>: View {
    let titulo: String
    var sobretitulo: String?
    /// No Início, o cenário escolhido (a tinta muda com ele).
    var cenario = CenarioId.ceu
    @ViewBuilder var acessorio: () -> Acessorio

    @Environment(\.ceu) private var ceu

    var body: some View {
        let tinta = Ceu.paleta(ceu.fase, cenario: cenario).tinta
        VStack(alignment: .leading, spacing: Espaco.minimo) {
            Text(sobretitulo ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tinta.opacity(0.75))
                .accessibilityHidden(sobretitulo == nil)
            HStack {
                Text(titulo)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(tinta)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Espaco.curto)
                acessorio()
            }
        }
    }
}

/// Ecrã de topo com `ScrollView` (Início, Expirados): cabeçalho, margens laterais, o céu
/// por trás e conteúdo que percorre por baixo da barra de separadores.
struct EcraBase<Acessorio: View, Conteudo: View>: View {
    let titulo: String
    var sobretitulo: String?
    /// O Início mostra a cena do céu; `ganho` pinta-a de verde.
    var cena = false
    var ganho = false
    @ViewBuilder var acessorio: () -> Acessorio
    @ViewBuilder var conteudo: () -> Conteudo

    /// Só a cena (o Início) mostra o cenário escolhido; os outros ecrãs ficam com o céu.
    @Environment(\.cenario) private var escolhido

    var body: some View {
        let cenario = cena ? escolhido : .ceu
        ScrollView {
            VStack(alignment: .leading, spacing: Espaco.bloco) {
                CabecalhoEcra(titulo: titulo, sobretitulo: sobretitulo, cenario: cenario, acessorio: acessorio)
                conteudo()
            }
            .padding(.horizontal, Espaco.margem)
            .padding(.bottom, Espaco.fim)
        }
        .background { FundoCeu(cena: cena, ganho: ganho, cenario: cenario) }
        .navigationTitle(titulo)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

extension EcraBase where Acessorio == EmptyView {
    init(titulo: String, sobretitulo: String? = nil, cena: Bool = false, ganho: Bool = false, @ViewBuilder conteudo: @escaping () -> Conteudo) {
        self.init(titulo: titulo, sobretitulo: sobretitulo, cena: cena, ganho: ganho, acessorio: { EmptyView() }, conteudo: conteudo)
    }
}

/// O mesmo ecrã de topo sobre uma `List` agrupada (Concluídos, Definições), para manter o
/// deslizar e o arrastar das linhas. O conteúdo são as secções da lista.
struct EcraBaseLista<Acessorio: View, Conteudo: View>: View {
    let titulo: String
    var sobretitulo: String?
    @ViewBuilder var acessorio: () -> Acessorio
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        List {
            Section {
                CabecalhoEcra(titulo: titulo, sobretitulo: sobretitulo, acessorio: acessorio)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            conteudo().listRowBackground(Ceu.cartao)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Espaco.bloco)
        .contentMargins(.horizontal, Espaco.margem, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, Espaco.fim, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background { FundoCeu() }
        .navigationTitle(titulo)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

extension EcraBaseLista where Acessorio == EmptyView {
    init(titulo: String, sobretitulo: String? = nil, @ViewBuilder conteudo: @escaping () -> Conteudo) {
        self.init(titulo: titulo, sobretitulo: sobretitulo, acessorio: { EmptyView() }, conteudo: conteudo)
    }
}
