import SwiftUI
import ToDoCore

/// Linha de um item principal (DESIGN.md 7.4): anel, título, resumo e tempo restante.
struct LinhaItem: View {
    let item: Item
    let cor: CorLista
    let agora: Date

    private var prazo: Prazo? { Prazo(item: item, agora: agora) }

    var body: some View {
        HStack(spacing: Espaco.grelha) {
            IndicadorPrazo(item: item, cor: cor, agora: agora)

            VStack(alignment: .leading, spacing: Espaco.minimo) {
                Text(item.titulo)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: Espaco.fino) {
                    if !item.fotos.isEmpty {
                        Image(systemName: "photo")
                    }
                    Text(item.resumo)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: Espaco.curto)

            if item.fixado {
                Text("Não expira")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let prazo {
                Text(prazo.rotuloCurto)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(prazo.ultimoDia ? CoresEstado.expiraTinta : cor.tinta)
            }
        }
        .frame(minHeight: Espaco.linhaItem)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotuloAcessivel)
    }

    private var rotuloAcessivel: String {
        let tempo = item.fixado ? "Não expira" : (prazo?.rotuloLongo ?? "")
        return [item.titulo, item.resumo, tempo].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
