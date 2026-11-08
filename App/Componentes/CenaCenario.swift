import SwiftUI
import ToDoCore

extension EnvironmentValues {
    /// O cenário desbloqueado e escolhido neste aparelho, posto na raiz (Melhoria 35). Só o
    /// Início o desenha (`EcraBase` com `cena`); os outros ecrãs ficam com o céu.
    @Entry var cenario = CenarioId.ceu
}

/// As cores de cada cenário, de dia e de noite (DESIGN.md 7.27). A tinta é a do texto que fica
/// por cima do fundo (título, "Expiram hoje", os pontos das páginas): escura nos fundos claros
/// e clara nos escuros. Todas desenhadas para o contraste chegar com o texto grande.
extension Ceu {
    static func paleta(_ fase: CeuDoDia.Fase, cenario: CenarioId) -> Paleta {
        let noite = fase == .noite
        return switch cenario {
        case .ceu:
            paleta(fase)
        case .parque:
            noite
                ? Paleta(ceu: cor(0x1E2A5C), tinta: cor(0xEEF3FF), colina: cor(0x1D4A3A), colinaFrente: cor(0x163B2E))
                : Paleta(ceu: cor(0xA9DBFF), tinta: cor(0x0B3A2A), colina: cor(0x9AD98A), colinaFrente: cor(0x7CCB6A))
        case .praia:
            noite
                ? Paleta(ceu: cor(0x142C55), tinta: cor(0xF0F6FF), colina: cor(0x1C4F7A), colinaFrente: cor(0x5E5240))
                : Paleta(ceu: cor(0xBFF0EE), tinta: cor(0x0A3B4A), colina: cor(0x5BC8D6), colinaFrente: cor(0xF4DFA8))
        case .biblioteca:
            noite
                ? Paleta(ceu: cor(0x2E1E16), tinta: cor(0xFBEBD5), colina: cor(0x4A3022), colinaFrente: cor(0x3A251A))
                : Paleta(ceu: cor(0xF6E7CF), tinta: cor(0x3B2414), colina: cor(0xD9B58A), colinaFrente: cor(0xC59A6A))
        case .viagem:
            noite
                ? Paleta(ceu: cor(0x2B1840), tinta: cor(0xFFEFF4), colina: cor(0x4A2A55), colinaFrente: cor(0x381F44))
                : Paleta(ceu: cor(0xFFD9B8), tinta: cor(0x4A1F12), colina: cor(0xF7B18A), colinaFrente: cor(0xF29A7A))
        case .montanha:
            noite
                ? Paleta(ceu: cor(0x1A2340), tinta: cor(0xEEF2FA), colina: cor(0x3A4766), colinaFrente: cor(0x2A3450))
                : Paleta(ceu: cor(0xD6E8F7), tinta: cor(0x1C2B3D), colina: cor(0xB7C8DA), colinaFrente: cor(0xA4B9CE))
        }
    }
}

/// O desenho de um cenário que não é o Céu, a encher o espaço dado: serve de fundo ao Início e
/// de miniatura na coleção. Tudo em proporções, sem imagens.
struct CenaCenario: View {
    let cenario: CenarioId
    let fase: CeuDoDia.Fase
    /// No fundo do Início o sol fica sempre no mesmo sítio que o do céu; na miniatura, em proporção.
    var miniatura = false

    var body: some View {
        let p = Ceu.paleta(fase, cenario: cenario)
        let noite = fase == .noite
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let astro = miniatura ? CGPoint(x: w * 0.68, y: h * 0.24) : CGPoint(x: w - 58, y: 86)
            let escala = miniatura ? min(w, h) / 300 : 1
            ZStack(alignment: .topLeading) {
                p.ceu
                switch cenario {
                case .ceu:
                    // Igual ao `FundoCeu`, para a miniatura da coleção.
                    if noite { Estrelas() }
                    Astro(noite: noite).scaleEffect(escala).position(astro)
                    Colina(esquerda: 0.30, controloX: 0.35, controloY: 0.20, direita: 0.33).fill(p.colina)
                    Colina(esquerda: 0.40, controloX: 0.75, controloY: 0.26, direita: 0.36).fill(p.colinaFrente)
                case .parque:
                    if noite { Estrelas() }
                    Astro(noite: noite).scaleEffect(escala).position(astro)
                    Colina(esquerda: 0.36, controloX: 0.3, controloY: 0.26, direita: 0.42).fill(p.colina)
                    Arvore(cor: p.colinaFrente, tronco: noite ? Ceu.cor(0x2A1E14) : Ceu.cor(0x7A5230))
                        .frame(width: w * 0.16, height: h * 0.22)
                        .position(x: w * 0.18, y: h * 0.36)
                    Arvore(cor: p.colinaFrente, tronco: noite ? Ceu.cor(0x2A1E14) : Ceu.cor(0x7A5230))
                        .frame(width: w * 0.11, height: h * 0.15)
                        .position(x: w * 0.34, y: h * 0.36)
                    Colina(esquerda: 0.44, controloX: 0.7, controloY: 0.34, direita: 0.4).fill(p.colinaFrente)
                case .praia:
                    if noite { Estrelas() }
                    Astro(noite: noite).scaleEffect(escala).position(astro)
                    Rectangle().fill(p.colina)
                        .frame(height: h * 0.7)
                        .offset(y: h * 0.3)
                    // As ondas: riscas claras no mar.
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(.white.opacity(noite ? 0.15 : 0.45))
                            .frame(width: w * 0.22, height: max(2, h * 0.008))
                            .position(x: w * (0.2 + 0.28 * Double(i)), y: h * (0.33 + 0.025 * Double(i % 2)))
                    }
                    Colina(esquerda: 0.42, controloX: 0.55, controloY: 0.36, direita: 0.39).fill(p.colinaFrente)
                case .biblioteca:
                    Estante(madeira: p.colina, sombra: p.colinaFrente, noite: noite)
                case .viagem:
                    if noite { Estrelas() }
                    Astro(noite: noite, cor: Ceu.cor(0xFF8A5B)).scaleEffect(escala).position(x: astro.x, y: astro.y + h * 0.05)
                    Aviao(cor: p.tinta.opacity(0.55))
                        .frame(width: w * 0.12, height: w * 0.12)
                        .position(x: w * 0.3, y: h * 0.14)
                    Colina(esquerda: 0.34, controloX: 0.45, controloY: 0.26, direita: 0.36).fill(p.colina)
                    Colina(esquerda: 0.42, controloX: 0.7, controloY: 0.34, direita: 0.4).fill(p.colinaFrente)
                case .montanha:
                    if noite { Estrelas() }
                    Astro(noite: noite).scaleEffect(escala).position(astro)
                    Pico(base: 0.42, cume: 0.16, centro: 0.3, largura: 0.7).fill(p.colina)
                    Pico(base: 0.42, cume: 0.16, centro: 0.3, largura: 0.7, neve: true).fill(.white.opacity(noite ? 0.55 : 0.95))
                    Pico(base: 0.46, cume: 0.22, centro: 0.72, largura: 0.8).fill(p.colinaFrente)
                    Pico(base: 0.46, cume: 0.22, centro: 0.72, largura: 0.8, neve: true).fill(.white.opacity(noite ? 0.5 : 0.9))
                    Rectangle().fill(p.colinaFrente).frame(height: h * 0.56).offset(y: h * 0.45)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Peças

/// O sol, ou a lua recortada, como no Céu.
private struct Astro: View {
    let noite: Bool
    var cor = Color(red: 1, green: 0.82, blue: 0.25)

    var body: some View {
        if noite {
            Circle()
                .fill(Color(red: 0.96, green: 0.94, blue: 0.85))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle().frame(width: 40, height: 40).offset(x: 13, y: -4).blendMode(.destinationOut)
                }
                .compositingGroup()
        } else {
            Circle().fill(cor).frame(width: 64, height: 64)
        }
    }
}

private struct Estrelas: View {
    private static let posicoes: [(Double, Double)] = [
        (0.12, 0.05), (0.30, 0.03), (0.52, 0.06), (0.68, 0.02), (0.20, 0.11), (0.60, 0.10), (0.42, 0.14), (0.92, 0.13),
    ]

    var body: some View {
        GeometryReader { g in
            ForEach(Self.posicoes.indices, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 3, height: 3)
                    .position(x: Self.posicoes[i].0 * g.size.width, y: Self.posicoes[i].1 * g.size.height)
            }
        }
    }
}

/// Uma colina que enche até ao fundo, como a do Céu.
struct Colina: Shape {
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

private struct Arvore: View {
    let cor: Color
    let tronco: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            Capsule().fill(tronco)
                .frame(width: w * 0.16, height: h * 0.45)
                .position(x: w / 2, y: h * 0.75)
            Circle().fill(cor)
                .frame(width: w, height: w)
                .position(x: w / 2, y: h * 0.38)
        }
    }
}

/// Um monte com cume em `cume` e base em `base` (frações da altura). Com `neve`, só o topo.
private struct Pico: Shape {
    let base, cume, centro, largura: CGFloat
    var neve = false

    func path(in r: CGRect) -> Path {
        let topo = CGPoint(x: centro * r.width, y: cume * r.height)
        let esquerda = CGPoint(x: (centro - largura / 2) * r.width, y: base * r.height)
        let direita = CGPoint(x: (centro + largura / 2) * r.width, y: base * r.height)
        return Path { p in
            if neve {
                // O terço de cima do monte.
                let f: CGFloat = 0.3
                let e = CGPoint(x: topo.x + (esquerda.x - topo.x) * f, y: topo.y + (esquerda.y - topo.y) * f)
                let d = CGPoint(x: topo.x + (direita.x - topo.x) * f, y: topo.y + (direita.y - topo.y) * f)
                p.move(to: topo)
                p.addLine(to: d)
                p.addLine(to: CGPoint(x: (topo.x + d.x) / 2 + r.width * 0.01, y: d.y - r.height * 0.012))
                p.addLine(to: CGPoint(x: topo.x, y: d.y + r.height * 0.006))
                p.addLine(to: CGPoint(x: (topo.x + e.x) / 2, y: e.y - r.height * 0.012))
                p.addLine(to: e)
            } else {
                p.move(to: esquerda)
                p.addLine(to: topo)
                p.addLine(to: direita)
                p.addLine(to: CGPoint(x: direita.x, y: r.height))
                p.addLine(to: CGPoint(x: esquerda.x, y: r.height))
            }
            p.closeSubpath()
        }
    }
}

private struct Aviao: View {
    let cor: Color

    var body: some View {
        Image(systemName: "airplane")
            .resizable()
            .scaledToFit()
            .foregroundStyle(cor)
            .rotationEffect(.degrees(-20))
    }
}

/// A biblioteca: uma parede com uma janela e, por baixo, prateleiras com livros às cores.
private struct Estante: View {
    let madeira: Color
    let sombra: Color
    let noite: Bool

    private static let livros: [UInt32] = [0xC0392B, 0x2E86C1, 0x27AE60, 0xF1C40F, 0x8E44AD, 0xE67E22, 0x16A085, 0xD35400]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            // A janela, em cima à direita, onde o sol fica nos outros cenários.
            RoundedRectangle(cornerRadius: 8)
                .fill(noite ? Ceu.cor(0x1A2350) : Ceu.cor(0xBDE6FB))
                .overlay {
                    if noite {
                        Circle().fill(Color(red: 0.96, green: 0.94, blue: 0.85)).frame(width: w * 0.05).offset(x: w * 0.03, y: -h * 0.02)
                    }
                }
                .overlay { Rectangle().fill(madeira).frame(width: 4) }
                .overlay { Rectangle().fill(madeira).frame(height: 4) }
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(madeira, lineWidth: 6) }
                .frame(width: w * 0.28, height: h * 0.16)
                .position(x: w * 0.78, y: h * 0.13)
            // As prateleiras.
            Rectangle().fill(sombra)
                .frame(width: w, height: h * 0.66)
                .position(x: w / 2, y: h * 0.67)
            ForEach(0..<6, id: \.self) { linha in
                let y = h * (0.37 + 0.1 * Double(linha))
                HStack(alignment: .bottom, spacing: w * 0.012) {
                    ForEach(0..<14, id: \.self) { i in
                        let cor = Ceu.cor(Self.livros[(i * 3 + linha) % Self.livros.count])
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cor.opacity(noite ? 0.55 : 0.85))
                            .frame(width: w * 0.045, height: h * (0.055 + 0.012 * Double((i + linha) % 3)))
                    }
                }
                .frame(width: w, height: h * 0.08, alignment: .bottom)
                .position(x: w / 2, y: y - h * 0.04)
                Rectangle().fill(madeira).frame(width: w, height: max(3, h * 0.012)).position(x: w / 2, y: y)
            }
        }
    }
}
