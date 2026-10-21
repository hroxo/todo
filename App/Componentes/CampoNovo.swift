import SwiftUI

/// Campo para acrescentar um item ou subtópico. Depois de guardar, limpa o texto e mantém
/// o teclado aberto para escrever o seguinte.
struct CampoNovo: View {
    let placeholder: String
    var cor: Color = .accentColor
    let aoSubmeter: (String) -> Void

    @State private var texto = ""
    @FocusState private var focado: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(cor)
                .accessibilityHidden(true)
            TextField(placeholder, text: $texto)
                .focused($focado)
                .submitLabel(.done)
                .onSubmit(submeter)
        }
    }

    private func submeter() {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return }
        aoSubmeter(limpo)
        texto = ""
        focado = true
    }
}
