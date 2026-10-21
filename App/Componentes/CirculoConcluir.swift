import SwiftUI

/// Botão redondo para concluir um item ou marcar um subtópico.
struct CirculoConcluir: View {
    let feito: Bool
    let cor: Color
    let acao: () -> Void

    @State private var toques = 0

    var body: some View {
        Button {
            toques += 1
            acao()
        } label: {
            Image(systemName: feito ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(cor)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.success, trigger: toques)
        .accessibilityLabel(feito ? "Marcar como por fazer" : "Concluir")
    }
}
