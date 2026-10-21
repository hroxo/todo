import SwiftData
import SwiftUI
import ToDoCore

/// Ecrã Início: cartões das listas. Criar com +, ordenar com Editar, editar e apagar por
/// pressão longa.
struct InicioView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    @State private var formulario: FormularioLista.Modo?
    @State private var aApagar: Lista?

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(listas) { lista in
                    CartaoLista(lista: lista)
                        .background(NavigationLink(value: lista) { EmptyView() }.opacity(0))
                        .contextMenu {
                            Button {
                                formulario = .editar(lista)
                            } label: {
                                Label("Editar lista", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                aApagar = lista
                            } label: {
                                Label("Apagar lista", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove { origem, destino in
                    var ordenadas = listas
                    ordenadas.move(fromOffsets: origem, toOffset: destino)
                    tarefas.reordenar(ordenadas)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Listas")
            .navigationDestination(for: Lista.self) { ListaView(lista: $0) }
            .navigationDestination(for: Item.self) { ItemDetalheView(item: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        formulario = .nova
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nova lista")
                }
            }
            .sheet(item: $formulario) { FormularioLista(modo: $0) }
            .confirmationDialog(
                "Apagar a lista «\(aApagar?.nome ?? "")»?",
                isPresented: Binding(presente: $aApagar),
                titleVisibility: .visible,
                presenting: aApagar
            ) { lista in
                Button("Apagar", role: .destructive) {
                    withAnimation { tarefas.apagar(lista) }
                }
            } message: { lista in
                Text(mensagemApagar(lista))
            }
            .task {
                _ = try? tarefas.criarListasIniciaisSeVazio()
            }
        }
    }

    private func mensagemApagar(_ lista: Lista) -> String {
        switch tarefas.contarItens(de: lista) {
        case 0: "A lista está vazia."
        case 1: "Apaga também 1 item. Esta ação não pode ser desfeita."
        case let n: "Apaga também \(n) itens. Esta ação não pode ser desfeita."
        }
    }
}
