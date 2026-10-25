import SwiftUI
import ToDoCore

/// Botão Manter em "gotas de vidro" (DESIGN.md 7.5). Toque: +5 dias. Premir ~0,3 s faz
/// nascer duas bolhas (+5 e +15); arrastar para um lado escolhe, soltar confirma, voltar
/// ao centro cancela. O movimento é física de água (`AguaManter`): as gotas têm inércia e
/// ressalto, e o líquido passa da cápsula para a bolha escolhida.
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
    @State private var agua = AguaManter()
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Namespace private var espaco

    private let limiar: CGFloat = 40
    private let alcance: CGFloat = 80

    /// Onda que sai da cápsula quando as gotas nascem.
    private struct Ondulacao {
        var escala = 1.0
        var opacidade = 0.0
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
                .offset(x: agua.capsula.x)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
            .gesture(gesto)
        }
        // Só a largura da cápsula e o nascer das bolhas usam animação; o resto é a física.
        .animation(.bouncy(duration: 0.55, extraBounce: 0.2), value: fase)
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
        .onAppear {
            agua.reduzirMovimento = reduzirMovimento
            if fase != .parado {
                let dedo: CGFloat = fase == .esquerda ? -alcance : (fase == .direita ? alcance : 0)
                agua.definir(dedo: dedo, aberto: true, limiar: limiar)
                agua.assentar()
            }
        }
        .onChange(of: reduzirMovimento) { _, novo in agua.reduzirMovimento = novo }
        .onDisappear { agua.parar() }
    }

    private var ajuda: String {
        switch fase {
        case .parado: "Toque: +\(diasCurto) dias · Premir e arrastar para escolher"
        case .premido: "Arrasta para um dos lados"
        case .esquerda: "Solta para manter mais \(diasCurto) dias"
        case .direita: "Solta para manter mais \(diasLongo) dias"
        }
    }

    /// Escala de uma gota: estica na direção do movimento e encolhe na outra, sem mudar de
    /// volume, e treme como geleia com o pulso.
    private func deformacao(velocidade: CGFloat, puxao: CGFloat, pulso: CGFloat) -> CGSize {
        let esticar = min(0.16, abs(velocidade) * 0.0008) + puxao
        return CGSize(width: (1 + esticar) * (1 + pulso), height: (1 - pulso) / (1 + esticar))
    }

    private var capsula: some View {
        let parado = fase == .parado
        let escala = deformacao(
            velocidade: agua.capsula.v,
            puxao: abs(agua.progresso.x) * 0.06,
            pulso: agua.liquidoCapsula.pulso.x
        )
        return comLiquido(agua.liquidoCapsula, fora: cor.tinta) {
            Label("Manter", systemImage: "arrow.clockwise")
                .font(.title3.weight(.heavy))
        }
        .frame(width: parado ? 200 : 160, height: 64)
        .clipShape(.capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("capsula", in: espaco)
        .scaleEffect(x: escala.width, y: escala.height)
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
        let mola = longo ? agua.longo : agua.curto
        let liquido = longo ? agua.liquidoLongo : agua.liquidoCurto
        // O tamanho segue o dedo com inércia: a gota escolhida incha, a outra encolhe.
        let direcao: CGFloat = longo ? 1 : -1
        let tamanho = max(40, 60 + 12 * agua.progresso.x * direcao)
        let escala = deformacao(velocidade: mola.v - agua.capsula.v, puxao: 0, pulso: liquido.pulso.x)
        return comLiquido(liquido, fora: Color.primary) {
            VStack(spacing: 0) {
                Text("+\(longo ? diasLongo : diasCurto)")
                    .font(.headline.weight(.heavy))
                Text("dias")
                    .font(.caption2.weight(.bold))
            }
        }
        .frame(width: tamanho, height: tamanho)
        .clipShape(.circle)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID(longo ? "longo" : "curto", in: espaco)
        .scaleEffect(x: escala.width, y: escala.height)
        // Atrasa-se em relação à cápsula: o pescoço de vidro estica antes de a gota a seguir.
        .offset(x: mola.x - agua.capsula.x)
    }

    /// O líquido na cor da lista, com uma segunda onda mais clara por trás, e o rótulo em
    /// duas cores: `fora` acima da superfície e a cor Texto por baixo.
    private func comLiquido<Rotulo: View>(
        _ liquido: AguaManter.Recipiente,
        fora: Color,
        @ViewBuilder rotulo: () -> Rotulo
    ) -> some View {
        let superficie = agua.superficie(liquido)
        let conteudo = rotulo()
        return ZStack {
            agua.superficie(liquido, atras: true)
                .fill(cor.base.opacity(0.45))
            superficie
                .fill(cor.base.opacity(0.9))
            conteudo
                .foregroundStyle(fora)
            conteudo
                .foregroundStyle(cor.texto)
                .mask { superficie }
        }
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
                        agua.nascer()
                        agua.definir(dedo: 0, aberto: true, limiar: limiar)
                    }
                }
                guard fase != .parado else { return }
                let dx = valor.translation.width
                agua.definir(dedo: max(-alcance, min(alcance, dx)), aberto: true, limiar: limiar)
                let nova: Fase = dx < -limiar ? .esquerda : (dx > limiar ? .direita : .premido)
                if nova != fase {
                    if nova != .premido {
                        limiares += 1
                        agua.salpicar(nova == .direita ? .longo : .curto, forca: 1.4)
                    }
                    fase = nova
                }
            }
            .onEnded { valor in
                temporizador?.cancel()
                tocando = false
                let final = fase
                fase = .parado
                agua.definir(dedo: 0, aberto: false, limiar: limiar)
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
        agua.salpicar(.capsula, forca: 2)
        aoManter(longo)
    }
}
