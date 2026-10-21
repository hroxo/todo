import SwiftData
import SwiftUI
import ToDoCore

/// Itens ativos de uma lista, com campo para acrescentar no fundo.
struct ListaView: View {
    let lista: Lista

    @Environment(\.modelContext) private var contexto
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @State private var aEditar: Item?
    @State private var aApagar: Item?

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }
    private var cor: Color { lista.cor.cor }

    var body: some View {
        List {
            ForEach(lista.itensAtivos) { item in
                HStack(spacing: 8) {
                    NavigationLink(value: item) {
                        LinhaItem(item: item, cor: cor) { concluir(item) }
                    }
                    MenuItem(item: item, listas: listas, aEditar: $aEditar, aApagar: $aApagar)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        concluir(item)
                    } label: {
                        Label("Concluir", systemImage: "checkmark")
                    }
                    .tint(cor)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        aApagar = item
                    } label: {
                        Label("Apagar", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .overlay {
            if lista.itensAtivos.isEmpty {
                ContentUnavailableView(
                    "Nada por fazer",
                    systemImage: "checkmark.circle",
                    description: Text("Escreve em baixo para acrescentar um item.")
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            CampoNovo(placeholder: "Novo item", cor: cor) { titulo in
                withAnimation { _ = try? tarefas.criarItem(titulo: titulo, em: lista) }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .navigationTitle(lista.nome)
        .tint(cor)
        .acoesDeItem(aEditar: $aEditar, aApagar: $aApagar)
    }

    private func concluir(_ item: Item) {
        withAnimation { tarefas.concluir(item) }
    }
}
