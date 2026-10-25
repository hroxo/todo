import SwiftUI
import ToDoCore

/// Botão Manter em "gotas de vidro" (DESIGN.md 7.5). Toque: +5 dias. Premir ~0,3 s faz
/// nascer duas bolhas (+5 e +15); arrastar para um lado escolhe, soltar confirma, voltar
/// ao centro cancela.
struct BotaoManter: View {
    let cor: CorLista
    let diasCurto: Int
    let diasLongo: Int
    /// Verdadeiro para o prazo longo.
    let aoManter: (Bool) -> Void

    private enum Fase {
        case parado, premido, esquerda, direita

        /// Parado, exceto nas capturas do modo de demonstração.
        static var inicial: Fase {
            switch Demo.faseManter {
            case "premido": .premido
            case "esquerda": .esquerda
            case "direita": .direita
            default: .parado
            }
        }
    }

    @State private var fase = Fase.inicial
    @State private var tocando = false
    @State private var temporizador: Task<Void, Never>?
    @State private var premidos = 0
    @State private var limiares = 0
    @State private var confirmacoes = 0
    /// Quanto o dedo já se afastou do centro, limitado a ±`alcance`. As gotas seguem-no de
    /// forma contínua, como água a ser puxada, em vez de saltarem entre três posições.
    @State private var arrasto: CGFloat = 0
    @Namespace private var espaco

    private let limiar: CGFloat = 40
    private let alcance: CGFloat = 80

    /// Onda que sai da cápsula quando as gotas nascem.
    private struct Ondulacao {
        var escala = 1.0
        var opacidade = 0.0
    }

    /// De -1 (tudo à esquerda) a 1 (tudo à direita).
    private var progresso: CGFloat {
        if tocando { return max(-1, min(1, arrasto / alcance)) }
        switch fase {
        case .esquerda: return -1
        case .direita: return 1
        default: return 0
        }
    }

    var body: some View {
        VStack(spacing: Espaco.grelha) {
            Text(ajuda)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(cor.tinta)
                .contentTransition(.opacity)

            // Distância de fusão das gotas (DESIGN.md 7.5), não é um espaçamento. Quanto maior,
            // mais tempo as gotas ficam ligadas à cápsula por uma ponte de vidro antes de se soltarem.
            GlassEffectContainer(spacing: 44) {
                HStack(spacing: Espaco.grelha) {
                    if fase != .parado {
                        bolha(longo: false)
                    }
                    capsula
                    if fase != .parado {
                        bolha(longo: true)
                    }
                }
                .offset(x: deslocamento)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
            .gesture(gesto)
        }
        // Mola com ressalto: as gotas nascem, balançam e assentam como água.
        .animation(.bouncy(duration: 0.55, extraBounce: 0.2), value: fase)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.62), value: arrasto)
        .sensoryFeedback(.impact(weight: .light), trigger: premidos)
        .sensoryFeedback(.selection, trigger: limiares)
        .sensoryFeedback(.success, trigger: confirmacoes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Manter")
        .accessibilityHint("Mantém o item mais \(diasCurto) dias")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmar(longo: false) }
        .accessibilityAction(named: "Manter mais \(diasCurto) dias") { confirmar(longo: false) }
        .accessibilityAction(named: "Manter mais \(diasLongo) dias") { confirmar(longo: true) }
    }

    private var ajuda: String {
        switch fase {
        case .parado: "Toque: +\(diasCurto) dias · Premir e arrastar para escolher"
        case .premido: "Arrasta para um dos lados"
        case .esquerda: "Solta para manter mais \(diasCurto) dias"
        case .direita: "Solta para manter mais \(diasLongo) dias"
        }
    }

    /// O conjunto acompanha o dedo, com resistência (quanto mais longe, menos cede).
    private var deslocamento: CGFloat {
        progresso * 28
    }

    private var capsula: some View {
        let parado = fase == .parado
        // Estica na direção do arrasto e encolhe na vertical, como uma gota puxada.
        let esticar = abs(progresso)
        return Label("Manter", systemImage: "arrow.clockwise")
            .font(.title3.weight(.heavy))
            .foregroundStyle(parado ? cor.texto : cor.tinta)
            .frame(width: parado ? 200 : 160, height: 64)
            .glassEffect(parado ? .regular.tint(cor.base).interactive() : .regular.interactive(), in: .capsule)
            .glassEffectID("capsula", in: espaco)
            .scaleEffect(x: 1 + esticar * 0.08, y: 1 - esticar * 0.06)
            .background {
                Capsule()
                    .stroke(cor.base.opacity(0.55), lineWidth: 3)
                    .keyframeAnimator(initialValue: Ondulacao(), trigger: premidos) { vista, valor in
                        vista
                            .scaleEffect(valor.escala)
                            .opacity(valor.opacidade)
                    } keyframes: { _ in
                        KeyframeTrack(\.escala) {
                            LinearKeyframe(1.0, duration: 0.01)
                            CubicKeyframe(1.55, duration: 0.7)
                        }
                        KeyframeTrack(\.opacidade) {
                            LinearKeyframe(0.9, duration: 0.01)
                            CubicKeyframe(0, duration: 0.7)
                        }
                    }
                    .allowsHitTesting(false)
            }
    }

    private func bolha(longo: Bool) -> some View {
        let ativa = longo ? fase == .direita : fase == .esquerda
        let inativa = longo ? fase == .esquerda : fase == .direita
        // O tamanho cresce de forma contínua com a gota para onde o dedo vai e encolhe a outra.
        let direcao: CGFloat = longo ? 1 : -1
        let tamanho: CGFloat = 60 + 12 * progresso * direcao
        return VStack(spacing: 0) {
            Text("+\(longo ? diasLongo : diasCurto)")
                .font(.headline.weight(.heavy))
            Text("dias")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(ativa ? cor.texto : Color.primary)
        .frame(width: tamanho, height: tamanho)
        .glassEffect(ativa ? .regular.tint(cor.base).interactive() : .regular.interactive(), in: .circle)
        .glassEffectID(longo ? "longo" : "curto", in: espaco)
        // A bolha do lado oposto afasta-se para se soltar da cápsula.
        .padding(longo ? .leading : .trailing, inativa ? Espaco.bloco : 0)
    }

    private var gesto: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { valor in
                if !tocando {
                    tocando = true
                    temporizador = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled, tocando, fase == .parado else { return }
                        fase = .premido
                        premidos += 1
                    }
                }
                guard fase != .parado else { return }
                let dx = valor.translation.width
                arrasto = max(-alcance, min(alcance, dx))
                let nova: Fase = dx < -limiar ? .esquerda : (dx > limiar ? .direita : .premido)
                if nova != fase {
                    if nova != .premido { limiares += 1 }
                    fase = nova
                }
            }
            .onEnded { valor in
                temporizador?.cancel()
                tocando = false
                arrasto = 0
                let final = fase
                fase = .parado
                switch final {
                case .parado:
                    // Toque simples, sem arrastar.
                    if abs(valor.translation.width) < 10 && abs(valor.translation.height) < 10 {
                        confirmar(longo: false)
                    }
                case .premido:
                    break
                case .esquerda:
                    confirmar(longo: false)
                case .direita:
                    confirmar(longo: true)
                }
            }
    }

    private func confirmar(longo: Bool) {
        confirmacoes += 1
        aoManter(longo)
    }
}
