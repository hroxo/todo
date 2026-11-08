import SwiftUI
import ToDoCore

extension EnvironmentValues {
    /// O céu de agora, posto na raiz da app por `CeuDoModo`.
    @Entry var ceu = CeuDoDia(agora: .now)
    /// A hora da raiz, o único relógio de minuto a minuto da app.
    @Entry var agora = Date.now
}

/// Põe o céu do modo do iPhone. Tem de ser uma vista: o `App` não recebe o `colorScheme`.
struct CeuDoModo: ViewModifier {
    let agora: Date
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        content.environment(\.ceu, CeuDoDia(agora: agora, escuro: esquema == .dark))
    }
}

/// As cores do céu (DESIGN.md 7.23). O modo escuro é sempre noite e o claro sempre dia, por isso
/// os cartões e as folhas só têm de trocar o preto do sistema pelo índigo da noite.
enum Ceu {
    static func cor(_ hex: UInt32) -> Color {
        Color(uiColor: uiCor(hex))
    }

    private static func uiCor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat(hex >> 16 & 0xFF) / 255,
            green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func dinamica(claro: UIColor, escuro: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? uiCor(escuro) : claro })
    }

    /// Cartões e linhas: branco de dia, índigo claro à noite.
    static let cartao = dinamica(claro: .white, escuro: 0x3A3590)
    /// Fundo das folhas que abrem por cima dos ecrãs.
    static let folha = dinamica(claro: .systemGroupedBackground, escuro: 0x2A2570)

    struct Paleta: Equatable {
        let ceu: Color
        let tinta: Color
        let colina: Color
        let colinaFrente: Color
    }

    static let ganho = Paleta(ceu: cor(0x7FE0B4), tinta: cor(0x06402C), colina: cor(0x5CCB9B), colinaFrente: cor(0x45B788))

    static func paleta(_ fase: CeuDoDia.Fase) -> Paleta {
        switch fase {
        case .dia: Paleta(ceu: cor(0xBDE6FB), tinta: cor(0x0B3A5E), colina: cor(0xA8E09A), colinaFrente: cor(0x8BD083))
        case .noite: Paleta(ceu: cor(0x2A2570), tinta: cor(0xF2F0FF), colina: cor(0x231F60), colinaFrente: cor(0x1C1950))
        }
    }
}

/// O fundo dos ecrãs: a cor do céu e, no Início, a cena com o sol ou a lua atrás das colinas,
/// ou o cenário escolhido (Melhoria 35). O dia ganho fica verde, exceto no modo escuro (aí o
/// texto é claro e continua o céu estrelado) e num cenário comprado, que não se esconde.
struct FundoCeu: View {
    var cena = false
    var ganho = false
    var cenario = CenarioId.ceu

    @Environment(\.ceu) private var ceu

    private static let estrelas: [(Double, Double)] = [
        (0.12, 0.05), (0.30, 0.03), (0.52, 0.06), (0.68, 0.02), (0.84, 0.07), (0.20, 0.11), (0.60, 0.10), (0.42, 0.14), (0.92, 0.13),
    ]

    var body: some View {
        let verde = ganho && ceu.fase != .noite && cenario == .ceu
        let paleta = verde ? Ceu.ganho : Ceu.paleta(ceu.fase)
        if cena && cenario != .ceu {
            CenaCenario(cenario: cenario, fase: ceu.fase)
                .ignoresSafeArea()
                .animation(.smooth(duration: 1), value: ceu.fase)
                .accessibilityHidden(true)
        } else {
            ceuDoDia(paleta: paleta, verde: verde)
        }
    }

    private func ceuDoDia(paleta: Ceu.Paleta, verde: Bool) -> some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                paleta.ceu
                if cena {
                    if ceu.fase == .noite {
                        ForEach(Self.estrelas.indices, id: \.self) { i in
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 3, height: 3)
                                .position(x: Self.estrelas[i].0 * g.size.width, y: Self.estrelas[i].1 * g.size.height)
                        }
                        lua.position(x: g.size.width - 58, y: 86)
                    } else {
                        sol.position(x: g.size.width - 58, y: 86)
                    }
                    Colina(esquerda: 0.30, controloX: 0.35, controloY: 0.20, direita: 0.33).fill(paleta.colina)
                    Colina(esquerda: 0.40, controloX: 0.75, controloY: 0.26, direita: 0.36).fill(paleta.colinaFrente)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 1), value: ceu.fase)
        .animation(.smooth(duration: 0.8), value: verde)
        .accessibilityHidden(true)
    }

    /// O sol e a lua ficam no mesmo sítio: abaixo dos ícones de rede, acima do balão do Glassy.
    private var sol: some View {
        Circle()
            .fill(Color(red: 1, green: 0.82, blue: 0.25))
            .frame(width: 64, height: 64)
    }

    /// Recortada a sério, em vez de tapada com a cor do fundo, que deixava um fio à volta.
    private var lua: some View {
        Circle()
            .fill(Color(red: 0.96, green: 0.94, blue: 0.85))
            .frame(width: 44, height: 44)
            .overlay {
                Circle().frame(width: 40, height: 40).offset(x: 13, y: -4).blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}

/// Uma lista agrupada com as linhas na cor dos cartões, sobre o céu ou sobre a cor pedida.
struct ListaCeu<Conteudo: View>: View {
    var cor: Color?
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        List {
            conteudo().listRowBackground(Ceu.cartao)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background {
            if let cor {
                cor.ignoresSafeArea()
            } else {
                FundoCeu()
            }
        }
    }
}
