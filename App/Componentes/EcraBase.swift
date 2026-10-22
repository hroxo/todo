import SwiftUI

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

/// Cabeçalho dos ecrãs de topo, igual ao do Início: uma linha pequena em maiúsculas (a data
/// no Início; nos outros fica reservada, para o título ficar sempre à mesma altura) e o
/// título grande. O acessório (por exemplo, um filtro) fica à direita do título.
struct CabecalhoEcra<Acessorio: View>: View {
    let titulo: String
    var sobretitulo: String?
    @ViewBuilder var acessorio: () -> Acessorio

    var body: some View {
        VStack(alignment: .leading, spacing: Espaco.minimo) {
            Text(sobretitulo?.uppercased() ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(sobretitulo == nil)
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(.largeTitle.weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Espaco.curto)
                acessorio()
            }
        }
    }
}

/// Ecrã de topo com `ScrollView` (Início, Expirados): cabeçalho, margens laterais, fundo
/// configurável e conteúdo que percorre por baixo da barra de separadores.
struct EcraBase<Acessorio: View, Conteudo: View>: View {
    let titulo: String
    var sobretitulo: String?
    var fundo: Color = Color(.systemGroupedBackground)
    @ViewBuilder var acessorio: () -> Acessorio
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espaco.bloco) {
                CabecalhoEcra(titulo: titulo, sobretitulo: sobretitulo, acessorio: acessorio)
                conteudo()
            }
            .padding(.horizontal, Espaco.margem)
            .padding(.bottom, Espaco.fim)
        }
        .background(fundo.ignoresSafeArea())
        .navigationTitle(titulo)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

extension EcraBase where Acessorio == EmptyView {
    init(titulo: String, sobretitulo: String? = nil, fundo: Color = Color(.systemGroupedBackground), @ViewBuilder conteudo: @escaping () -> Conteudo) {
        self.init(titulo: titulo, sobretitulo: sobretitulo, fundo: fundo, acessorio: { EmptyView() }, conteudo: conteudo)
    }
}

/// O mesmo ecrã de topo sobre uma `List` agrupada (Concluídos, Definições), para manter o
/// deslizar e o arrastar das linhas. O conteúdo são as secções da lista.
struct EcraBaseLista<Acessorio: View, Conteudo: View>: View {
    let titulo: String
    var sobretitulo: String?
    var fundo: Color = Color(.systemGroupedBackground)
    @ViewBuilder var acessorio: () -> Acessorio
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        List {
            Section {
                CabecalhoEcra(titulo: titulo, sobretitulo: sobretitulo, acessorio: acessorio)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            conteudo()
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Espaco.bloco)
        .contentMargins(.horizontal, Espaco.margem, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, Espaco.fim, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(fundo.ignoresSafeArea())
        .navigationTitle(titulo)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

extension EcraBaseLista where Acessorio == EmptyView {
    init(titulo: String, sobretitulo: String? = nil, fundo: Color = Color(.systemGroupedBackground), @ViewBuilder conteudo: @escaping () -> Conteudo) {
        self.init(titulo: titulo, sobretitulo: sobretitulo, fundo: fundo, acessorio: { EmptyView() }, conteudo: conteudo)
    }
}
