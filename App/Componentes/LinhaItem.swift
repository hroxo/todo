import SwiftUI
import ToDoCore

/// Linha de um item principal na lista.
struct LinhaItem: View {
    let item: Item
    let cor: Color
    let aoConcluir: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CirculoConcluir(feito: item.estado == .concluido, cor: cor, acao: aoConcluir)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.titulo)
                    .lineLimit(2)
                if !item.subtopicos.isEmpty {
                    Text("\(item.subtopicosFeitos)/\(item.subtopicos.count) subtópicos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if item.tipo == .notaRapida {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Nota rápida")
            }
            if item.fixado {
                Image(systemName: "pin.fill")
                    .foregroundStyle(cor)
                    .accessibilityLabel("Fixado")
            }
        }
        .padding(.vertical, 4)
    }
}
