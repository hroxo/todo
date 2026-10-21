import SwiftUI
import ToDoCore

/// Cartão de uma lista no ecrã Início: nome, cor e número grande de itens ativos.
struct CartaoLista: View {
    let lista: Lista

    private var ativos: Int { lista.itensAtivos.count }

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .stroke(lista.cor.cor, lineWidth: 6)
                .frame(width: 30, height: 30)

            Text(lista.nome)
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(ativos)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(lista.cor.cor)
                Text(ativos == 1 ? "ativo" : "ativos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lista.nome), \(ativos) \(ativos == 1 ? "item ativo" : "itens ativos")")
    }
}
