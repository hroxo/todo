import SwiftUI
import ToDoCore

/// A Ampulheta que recebe no Início (DESIGN.md 7.22): a areia conta o dia e o balão diz o que
/// importa agora, no lugar do antigo cartão "Para ti". Tocar nela faz com que dê um salto.
struct CartaoAnfitria: View {
    /// Uma ação do balão: as de "Para ti" ou o Anular de um ponto acabado de concluir.
    struct Botao: Identifiable {
        let rotulo: String
        let acao: () -> Void
        var id: String { rotulo }
    }

    let progresso: ProgressoDia
    let pose: PoseMascote
    let frase: String
    let botoes: [Botao]
    var dispensar: (() -> Void)?
    /// Muda quando a areia recebe um grão: a Ampulheta salta.
    let saltos: Int

    @State private var toques = 0
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        HStack(alignment: .center, spacing: Espaco.curto) {
            AmpulhetaDia(pose: pose, nivel: progresso.fracao)
                .frame(width: 70, height: 84)
                .modifier(Salto(gatilho: reduzirMovimento ? 0 : saltos + toques))
                .contentShape(Rectangle())
                .onTapGesture { toques += 1 }
                .sensoryFeedback(.impact(weight: .light), trigger: toques)
            balao
        }
    }

    private var balao: some View {
        HStack(alignment: .top, spacing: Espaco.curto) {
            VStack(alignment: .leading, spacing: Espaco.curto) {
                Text(frase)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if !botoes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(botoes) { botao in
                            Button(action: botao.acao) {
                                let destaque = botao.id == botoes.first?.id
                                Text(botao.rotulo)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(destaque ? Color.indigo : Color.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(destaque ? Color.indigo.opacity(0.14) : Color(.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if let dispensar {
                Button(action: dispensar) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .padding(.top, -4)
                .padding(.trailing, -6)
                .accessibilityLabel("Dispensar")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Ceu.cartao,
            // O canto junto à Ampulheta fica quase reto: é o bico do balão.
            in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

/// A Ampulheta com a areia a mudar de nível de forma animada.
private struct AmpulhetaDia: View, Animatable {
    let pose: PoseMascote
    var nivel: Double

    var animatableData: Double {
        get { nivel }
        set { nivel = newValue }
    }

    var body: some View {
        Ampulheta(pose: pose, nivelAreia: nivel)
    }
}

/// Encolhe, salta e assenta, como quem recebe um grão de areia.
private struct Salto: ViewModifier {
    let gatilho: Int

    private struct Valores {
        var subida: CGFloat = 0
        var largura: CGFloat = 1
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Valores(), trigger: gatilho) { vista, valores in
            vista
                .scaleEffect(x: valores.largura, y: 2 - valores.largura, anchor: .bottom)
                .offset(y: valores.subida)
        } keyframes: { _ in
            KeyframeTrack(\.subida) {
                CubicKeyframe(0, duration: 0.08)
                CubicKeyframe(-16, duration: 0.2)
                SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.largura) {
                CubicKeyframe(1.12, duration: 0.08)
                CubicKeyframe(0.94, duration: 0.2)
                CubicKeyframe(1.08, duration: 0.12)
                SpringKeyframe(1, duration: 0.25)
            }
        }
    }
}

/// O grão que voa do círculo do ponto até à Ampulheta.
struct GraoVoador: View {
    let de: CGPoint
    let para: CGPoint
    @State private var chegou = false

    var body: some View {
        Circle()
            .fill(Color(red: 0.96, green: 0.73, blue: 0.35))
            .frame(width: 10, height: 10)
            .scaleEffect(chegou ? 0.5 : 1)
            .position(chegou ? para : de)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5)) { chegou = true }
            }
    }
}

/// As faíscas à volta do círculo ao concluir um ponto.
struct FaiscasConcluir: View {
    @State private var abertas = false
    private let total = 8

    var body: some View {
        ZStack {
            ForEach(0..<total, id: \.self) { indice in
                let angulo = Double(indice) / Double(total) * 2 * .pi
                Circle()
                    .fill(indice.isMultiple(of: 2) ? CoresEstado.concluido : Color(red: 0.96, green: 0.73, blue: 0.35))
                    .frame(width: 5, height: 5)
                    .offset(x: abertas ? cos(angulo) * 26 : 0, y: abertas ? sin(angulo) * 26 : 0)
                    .opacity(abertas ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { abertas = true }
        }
    }
}

/// Os confettis do dia ganho, por cima de tudo, durante 2 segundos.
struct Confetes: View {
    private struct Peca {
        let x: Double, atraso: Double, deriva: Double, giro: Double, cor: Color
    }

    private static let duracao = 2.0
    private let inicio = Date.now
    private let pecas: [Peca] = (0..<70).map { _ in
        Peca(
            x: .random(in: 0...1),
            atraso: .random(in: 0...0.5),
            deriva: .random(in: -40...40),
            giro: .random(in: 2...9),
            cor: [Color.green, .yellow, .blue, .pink, .purple, .orange].randomElement()!
        )
    }

    var body: some View {
        TimelineView(.animation) { linha in
            Canvas { contexto, tamanho in
                let tempo = linha.date.timeIntervalSince(inicio)
                for peca in pecas {
                    let t = (tempo - peca.atraso) / (Self.duracao - 0.5)
                    guard t > 0, t < 1 else { continue }
                    var c = contexto
                    c.opacity = t > 0.8 ? (1 - t) * 5 : 1
                    c.translateBy(x: peca.x * tamanho.width + peca.deriva * t, y: -20 + t * t * (tamanho.height + 40))
                    c.rotate(by: .radians(peca.giro * t))
                    c.fill(Path(roundedRect: CGRect(x: -4, y: -3, width: 8, height: 6), cornerRadius: 1.5), with: .color(peca.cor))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
