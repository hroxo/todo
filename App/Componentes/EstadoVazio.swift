import SwiftUI

/// Um ecrã vazio com a Ampulheta (DESIGN.md 7.18): a mesma mascote do widget, numa pose que
/// diz o estado, com um título e uma linha. Flutua devagar, como quem respira; com "Reduzir
/// movimento" fica parada.
struct EstadoVazio: View {
    let pose: PoseMascote
    let titulo: String
    let texto: String
    var cor: Color = .primary

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    var body: some View {
        VStack(spacing: Espaco.grelha) {
            Ampulheta(pose: pose)
                .frame(width: pose == .dormir ? 116 : 92, height: 112)
                .phaseAnimator(reduzirMovimento ? [0.0] : [0.0, -5.0]) { ampulheta, subida in
                    ampulheta.offset(y: subida)
                } animation: { _ in
                    .easeInOut(duration: 1.8)
                }
            VStack(spacing: Espaco.fino) {
                Text(titulo)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(cor)
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Espaco.margem)
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
