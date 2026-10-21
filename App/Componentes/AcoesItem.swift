import SwiftUI
import ToDoCore

/// Ações de um item principal, para o menu "…" e para o menu de pressão longa (alternativa
/// aos gestos, especificação 11). Editar e Apagar só marcam o item; o alerta e a confirmação
/// vêm de `acoesDeItem`.
struct MenuAcoesItem: View {
    let item: Item
    let listas: [Lista]
    @Binding var aEditar: Item?
    @Binding var aApagar: Item?
    /// Falso no Detalhe, onde Fixar, Concluir e Manter já têm botões próprios.
    var completo = true

    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        let tarefas = Tarefas(contexto: contexto)
        let definicoes = tarefas.definicoes

        if completo {
            if item.estado == .ativo && !item.fixado {
                Button {
                    tarefas.manter(item, longo: false)
                    estado.reagendarAvisos()
                } label: {
                    Label("Manter mais \(definicoes.diasManterCurto) dias", systemImage: "arrow.clockwise")
                }
                Button {
                    tarefas.manter(item, longo: true)
                    estado.reagendarAvisos()
                } label: {
                    Label("Manter mais \(definicoes.diasManterLongo) dias", systemImage: "arrow.clockwise")
                }
            }
            Button {
                withAnimation { tarefas.concluir(item) }
            } label: {
                Label("Concluir", systemImage: "checkmark.circle")
            }
            Button {
                tarefas.definirFixado(item, !item.fixado)
            } label: {
                Label(item.fixado ? "Desafixar" : "Fixar", systemImage: item.fixado ? "pin.slash" : "pin")
            }
        }

        Button {
            aEditar = item
        } label: {
            Label("Editar título", systemImage: "pencil")
        }

        Menu {
            ForEach(listas.filter { $0 != item.lista }) { lista in
                Button(lista.nome) {
                    withAnimation { tarefas.mover(item, para: lista) }
                }
            }
        } label: {
            Label("Mover para", systemImage: "folder")
        }

        Button {
            tarefas.converter(item)
        } label: {
            Label(
                item.tipo == .tarefa ? "Converter em nota" : "Converter em tarefa",
                systemImage: "arrow.left.arrow.right"
            )
        }

        Divider()

        Button(role: .destructive) {
            aApagar = item
        } label: {
            Label("Apagar", systemImage: "trash")
        }
    }
}

/// Alerta de edição do título e confirmação de apagar, partilhados pelos ecrãs.
struct AcoesDeItem: ViewModifier {
    @Binding var aEditar: Item?
    @Binding var aApagar: Item?
    /// Chamado antes de apagar. Devolve verdadeiro se o ecrã vai fechar, para apagar só
    /// depois da animação (o SwiftData não deixa ler um item já apagado).
    var antesDeApagar: (Item) -> Bool = { _ in false }

    @Environment(\.modelContext) private var contexto
    @State private var titulo = ""

    func body(content: Content) -> some View {
        content
            .alert("Editar", isPresented: Binding(presente: $aEditar), presenting: aEditar) { item in
                TextField("Título", text: $titulo)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") {
                    try? Tarefas(contexto: contexto).editarTitulo(item, para: titulo)
                }
            }
            .onChange(of: aEditar) { _, item in
                if let item { titulo = item.titulo }
            }
            .confirmationDialog(
                "Apagar «\(aApagar?.titulo ?? "")»?",
                isPresented: Binding(presente: $aApagar),
                titleVisibility: .visible,
                presenting: aApagar
            ) { item in
                Button("Apagar", role: .destructive) { apagar(item) }
            } message: { item in
                Text(mensagemApagar(item))
            }
            .sensoryFeedback(.warning, trigger: aApagar) { _, novo in novo != nil }
    }

    private func mensagemApagar(_ item: Item) -> String {
        switch item.subtopicos.count {
        case 0: "Esta ação não pode ser desfeita."
        case 1: "Apaga também 1 subtópico. Esta ação não pode ser desfeita."
        case let n: "Apaga também \(n) subtópicos. Esta ação não pode ser desfeita."
        }
    }

    private func apagar(_ item: Item) {
        let tarefas = Tarefas(contexto: contexto)
        if antesDeApagar(item) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tarefas.apagar(item) }
        } else {
            withAnimation { tarefas.apagar(item) }
        }
    }
}

extension View {
    func acoesDeItem(
        aEditar: Binding<Item?>,
        aApagar: Binding<Item?>,
        antesDeApagar: @escaping (Item) -> Bool = { _ in false }
    ) -> some View {
        modifier(AcoesDeItem(aEditar: aEditar, aApagar: aApagar, antesDeApagar: antesDeApagar))
    }
}
