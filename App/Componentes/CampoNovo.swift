import SwiftUI

/// Campo para acrescentar um subtópico. Depois de guardar, limpa o texto e mantém o teclado
/// aberto para escrever o seguinte.
struct CampoNovo: View {
    let placeholder: String
    var cor: Color = .accentColor
    var focarAoAparecer = false
    let aoSubmeter: (String) -> Void

    @State private var texto = ""
    @FocusState private var focado: Bool

    var body: some View {
        HStack(spacing: Espaco.grelha) {
            // Tocar no + também guarda, além do botão do teclado.
            Button(action: submeter) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(cor)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Adicionar")
            TextField(placeholder, text: $texto)
                .focused($focado)
                .submitLabel(.done)
                .onSubmit(submeter)
        }
        .onAppear {
            if focarAoAparecer { focado = true }
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

/// Dispõe as vistas em linhas, passando para a seguinte quando não cabem (fichas de lista).
struct FluxoLayout: Layout {
    var espaco: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let posicoes = calcular(largura: proposal.width ?? .infinity, subviews: subviews)
        return posicoes.tamanho
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let posicoes = calcular(largura: bounds.width, subviews: subviews)
        for (subview, ponto) in zip(subviews, posicoes.pontos) {
            subview.place(at: CGPoint(x: bounds.minX + ponto.x, y: bounds.minY + ponto.y), proposal: .unspecified)
        }
    }

    private func calcular(largura: CGFloat, subviews: Subviews) -> (pontos: [CGPoint], tamanho: CGSize) {
        var pontos: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var alturaLinha: CGFloat = 0
        var larguraMaxima: CGFloat = 0
        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x > 0 && x + tamanho.width > largura {
                x = 0
                y += alturaLinha + espaco
                alturaLinha = 0
            }
            pontos.append(CGPoint(x: x, y: y))
            x += tamanho.width + espaco
            alturaLinha = max(alturaLinha, tamanho.height)
            larguraMaxima = max(larguraMaxima, x - espaco)
        }
        return (pontos, CGSize(width: larguraMaxima, height: y + alturaLinha))
    }
}
