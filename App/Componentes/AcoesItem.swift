import SwiftData
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
    /// Falso no Detalhe, onde Fixar e Manter já têm botões próprios.
    var completo = true
    /// Concluir a partir do Detalhe (fecha o ecrã); na lista conclui no lugar.
    var aConcluir: () -> Void = {}

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
                withAnimation { _ = tarefas.concluir(item) }
            } label: {
                Label("Concluir", systemImage: "checkmark.circle")
            }
            Button {
                tarefas.definirFixado(item, !item.fixado)
            } label: {
                Label(item.fixado ? "Desafixar" : "Fixar", systemImage: item.fixado ? "pin.slash" : "pin")
            }
        }

        if !completo && item.estado == .ativo {
            Button {
                aConcluir()
            } label: {
                Label("Concluir", systemImage: "checkmark.circle")
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

/// Confirmação de apagar uma lista, a mesma em todos os ecrãs. Com `fechar`, o ecrã da lista
/// fecha primeiro e a lista só sai depois da animação, para não ficar em branco a fechar.
struct ApagarLista: ViewModifier {
    @Binding var lista: Lista?
    var fechar: (() -> Void)?

    @Environment(\.modelContext) private var contexto

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Apagar a lista «\(lista?.nome ?? "")»?",
                isPresented: Binding(presente: $lista),
                titleVisibility: .visible,
                presenting: lista
            ) { lista in
                Button("Apagar", role: .destructive) { apagar(lista) }
            } message: { lista in
                Text(mensagem(lista))
            }
    }

    private func mensagem(_ lista: Lista) -> String {
        if lista.ehCompras { return "Apaga todas as secções e pontos. Esta ação não pode ser desfeita." }
        return switch Tarefas(contexto: contexto).contarItens(de: lista) {
        case 0: "A lista está vazia."
        case 1: "Apaga também 1 item. Esta ação não pode ser desfeita."
        case let n: "Apaga também \(n) itens. Esta ação não pode ser desfeita."
        }
    }

    private func apagar(_ lista: Lista) {
        let tarefas = Tarefas(contexto: contexto)
        guard let fechar else {
            withAnimation { tarefas.apagar(lista) }
            return
        }
        fechar()
        // Se sair antes, o ecrã mostra-se vazio (`foiApagado`): é só estética, não um crash.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tarefas.apagar(lista) }
    }
}

extension View {
    func apagarLista(_ lista: Binding<Lista?>, fechar: (() -> Void)? = nil) -> some View {
        modifier(ApagarLista(lista: lista, fechar: fechar))
    }

    func acoesDeItem(
        aEditar: Binding<Item?>,
        aApagar: Binding<Item?>,
        antesDeApagar: @escaping (Item) -> Bool = { _ in false }
    ) -> some View {
        modifier(AcoesDeItem(aEditar: aEditar, aApagar: aApagar, antesDeApagar: antesDeApagar))
    }
}
