import SwiftUI
import ToDoCore

/// Folha para criar uma lista ou mudar o nome e a cor de uma existente.
struct FormularioLista: View {
    enum Modo: Identifiable {
        case nova
        case editar(Lista)

        var id: String {
            switch self {
            case .nova: "nova"
            case .editar(let lista): lista.id.uuidString
            }
        }
    }

    let modo: Modo

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @State private var nome = ""
    @State private var cor: CorLista = .azul

    private var podeGuardar: Bool {
        !nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $nome)
                        .font(.title3)
                }
                Section("Cor") {
                    SeletorCor(selecao: $cor)
                }
            }
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .tint(cor.cor)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardar)
                        .disabled(!podeGuardar)
                }
            }
            .onAppear {
                if case .editar(let lista) = modo {
                    nome = lista.nome
                    cor = lista.cor
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var titulo: String {
        if case .editar = modo { return "Editar lista" }
        return "Nova lista"
    }

    private func guardar() {
        let tarefas = Tarefas(contexto: contexto)
        switch modo {
        case .nova:
            _ = try? tarefas.criarLista(nome: nome, cor: cor)
        case .editar(let lista):
            try? tarefas.editar(lista, nome: nome, cor: cor)
        }
        dismiss()
    }
}
