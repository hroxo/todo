import SwiftUI
import ToDoCore

extension EnvironmentValues {
    /// O céu de agora, atualizado de minuto a minuto na raiz da app.
    @Entry var ceu = CeuDoDia(agora: .now)
}

/// As cores do céu (DESIGN.md 7.23). A app fica em modo claro de dia e em modo escuro à noite,
/// por isso os cartões e as folhas só têm de trocar o preto do sistema pelo índigo da noite.
enum Ceu {
    private static func cor(_ hex: UInt32) -> Color {
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
        case .amanhecer: Paleta(ceu: cor(0xFFD1C7), tinta: cor(0x6A2A3A), colina: cor(0xF7B7AC), colinaFrente: cor(0xEFA39F))
        case .dia: Paleta(ceu: cor(0xBDE6FB), tinta: cor(0x0B3A5E), colina: cor(0xA8E09A), colinaFrente: cor(0x8BD083))
        case .porDoSol: Paleta(ceu: cor(0xFFB27A), tinta: cor(0x5A1F0A), colina: cor(0xF09A7A), colinaFrente: cor(0xE58570))
        case .noite: Paleta(ceu: cor(0x2A2570), tinta: cor(0xF2F0FF), colina: cor(0x231F60), colinaFrente: cor(0x1C1950))
        }
    }
}

/// O fundo dos ecrãs: a cor do céu e, no Início, a cena com o sol ou a lua atrás das colinas.
/// O dia ganho fica verde, exceto à noite: aí o texto é claro e continua o céu estrelado.
struct FundoCeu: View {
    var cena = false
    var ganho = false

    @Environment(\.ceu) private var ceu

    private static let estrelas: [(Double, Double)] = [
        (0.12, 0.05), (0.30, 0.03), (0.52, 0.06), (0.68, 0.02), (0.84, 0.07), (0.20, 0.11), (0.60, 0.10), (0.42, 0.14), (0.92, 0.13),
    ]

    var body: some View {
        let verde = ganho && ceu.fase != .noite
        let paleta = verde ? Ceu.ganho : Ceu.paleta(ceu.fase)
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
                        lua(fundo: paleta.ceu).position(x: g.size.width - 58, y: 86)
                    } else {
                        sol(largura: g.size.width)
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

    /// Atravessa o céu durante o dia; ao nascer e ao pôr fica maior, laranja e baixo.
    private func sol(largura: CGFloat) -> some View {
        let baixo = ceu.fase == .amanhecer || ceu.fase == .porDoSol
        let tamanho: CGFloat = baixo ? 88 : 64
        return Circle()
            .fill(baixo ? Color(red: 1, green: 0.54, blue: 0.24) : Color(red: 1, green: 0.82, blue: 0.25))
            .frame(width: tamanho, height: tamanho)
            .position(
                // Só na metade direita: à esquerda ficaria por trás do título.
                x: largura * (0.5 + ceu.percurso * 0.42),
                // Acima do balão da Ampulheta, que tapa o céu a partir daí.
                y: baixo ? 92 : 110 - sin(ceu.percurso * .pi) * 45
            )
    }

    private func lua(fundo: Color) -> some View {
        Circle()
            .fill(Color(red: 0.96, green: 0.94, blue: 0.85))
            .frame(width: 44, height: 44)
            .overlay {
                Circle().fill(fundo).frame(width: 40, height: 40).offset(x: 13, y: -4)
            }
            .clipShape(.circle)
    }

    /// Uma colina que enche o ecrã até ao fundo, para o céu nunca aparecer por baixo dela.
    private struct Colina: Shape {
        let esquerda, controloX, controloY, direita: CGFloat

        func path(in r: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 0, y: esquerda * r.height))
                p.addQuadCurve(
                    to: CGPoint(x: r.width, y: direita * r.height),
                    control: CGPoint(x: controloX * r.width, y: controloY * r.height)
                )
                p.addLine(to: CGPoint(x: r.width, y: r.height))
                p.addLine(to: CGPoint(x: 0, y: r.height))
                p.closeSubpath()
            }
        }
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
