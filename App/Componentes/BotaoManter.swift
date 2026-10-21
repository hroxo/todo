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

    private enum Fase { case parado, premido, esquerda, direita }

    @State private var fase = Fase.parado
    @State private var tocando = false
    @State private var temporizador: Task<Void, Never>?
    @State private var premidos = 0
    @State private var limiares = 0
    @State private var confirmacoes = 0
    @Namespace private var espaco

    private let limiar: CGFloat = 40

    var body: some View {
        VStack(spacing: 12) {
            Text(ajuda)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(cor.tinta)
                .contentTransition(.opacity)

            GlassEffectContainer(spacing: 20) {
                HStack(spacing: 12) {
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
        .animation(.snappy, value: fase)
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

    private var deslocamento: CGFloat {
        switch fase {
        case .esquerda: -20
        case .direita: 20
        default: 0
        }
    }

    private var capsula: some View {
        let parado = fase == .parado
        return Label("Manter", systemImage: "arrow.clockwise")
            .font(.title3.weight(.heavy))
            .foregroundStyle(parado ? cor.texto : cor.tinta)
            .frame(width: parado ? 200 : 160, height: 64)
            .glassEffect(parado ? .regular.tint(cor.base).interactive() : .regular.interactive(), in: .capsule)
            .glassEffectID("capsula", in: espaco)
    }

    private func bolha(longo: Bool) -> some View {
        let ativa = longo ? fase == .direita : fase == .esquerda
        let inativa = longo ? fase == .esquerda : fase == .direita
        let tamanho: CGFloat = ativa ? 68 : (inativa ? 48 : 60)
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
        .padding(longo ? .leading : .trailing, inativa ? 16 : 0)
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
                let nova: Fase = dx < -limiar ? .esquerda : (dx > limiar ? .direita : .premido)
                if nova != fase {
                    if nova != .premido { limiares += 1 }
                    fase = nova
                }
            }
            .onEnded { valor in
                temporizador?.cancel()
                tocando = false
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
