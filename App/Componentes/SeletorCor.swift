import SwiftUI
import ToDoCore

/// Grelha com as 8 cores da paleta.
struct SeletorCor: View {
    @Binding var selecao: CorLista

    private let colunas = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        LazyVGrid(columns: colunas, spacing: 16) {
            ForEach(CorLista.allCases, id: \.self) { cor in
                let escolhida = cor == selecao
                Button {
                    selecao = cor
                } label: {
                    Circle()
                        .fill(cor.cor)
                        .frame(width: 44, height: 44)
                        .overlay {
                            if escolhida {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(4)
                        .overlay(Circle().stroke(Color.primary, lineWidth: escolhida ? 2 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cor.nome)
                .accessibilityAddTraits(escolhida ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: selecao)
    }
}
