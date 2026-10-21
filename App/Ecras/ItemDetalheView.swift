import SwiftData
import SwiftUI
import ToDoCore

/// Detalhe de um item: título editável, subtópicos, fixar e concluir.
struct ItemDetalheView: View {
    let item: Item

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @State private var titulo = ""
    @FocusState private var tituloFocado: Bool
    @State private var aEditar: Item?
    @State private var aApagar: Item?
    @State private var sugerirConcluir = false

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }
    private var cor: Color { item.listaEfetiva?.cor.cor ?? .accentColor }

    var body: some View {
        // Durante a animação de fecho depois de apagar, o item já não existe.
        if item.isDeleted || item.modelContext == nil {
            Color.clear
        } else {
            conteudo
        }
    }

    private var conteudo: some View {
        List {
            Section {
                TextField("Título", text: $titulo)
                    .font(.title2.weight(.semibold))
                    .focused($tituloFocado)
                    .submitLabel(.done)
                    .onSubmit(guardarTitulo)
                HStack(spacing: 12) {
                    Label(item.listaEfetiva?.nome ?? "", systemImage: "circle.fill")
                        .foregroundStyle(cor)
                    Label(item.tipo == .tarefa ? "Tarefa" : "Nota rápida",
                          systemImage: item.tipo == .tarefa ? "checklist" : "note.text")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .labelStyle(.titleAndIcon)
            }

            Section("Subtópicos") {
                ForEach(item.subtopicosOrdenados) { sub in
                    LinhaSubtopico(sub: sub, cor: cor) { alternar(sub) }
                        .swipeActions(edge: .trailing) {
                            Button {
                                aApagar = sub
                            } label: {
                                Label("Apagar", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .contextMenu {
                            Button { aEditar = sub } label: { Label("Editar", systemImage: "pencil") }
                            Button(role: .destructive) { aApagar = sub } label: { Label("Apagar", systemImage: "trash") }
                        }
                }
                CampoNovo(placeholder: "Novo subtópico", cor: cor) { texto in
                    withAnimation { _ = try? tarefas.adicionarSubtopico(titulo: texto, a: item) }
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { item.fixado },
                    set: { tarefas.definirFixado(item, $0) }
                )) {
                    Label("Fixado", systemImage: "pin")
                }
                if item.estado == .concluido {
                    Button("Reabrir item") { tarefas.reabrir(item) }
                } else {
                    Button("Concluir item", action: concluir)
                }
            } footer: {
                Text(item.fixado ? "Um item fixado nunca expira." : "Sem ações, o item expira ao fim de 3 dias.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(cor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MenuItem(item: item, listas: listas, aEditar: $aEditar, aApagar: $aApagar)
            }
        }
        .acoesDeItem(aEditar: $aEditar, aApagar: $aApagar) { apagado in
            guard apagado == item else { return false }
            dismiss()
            return true
        }
        .alert("Concluir o item?", isPresented: $sugerirConcluir) {
            Button("Concluir", action: concluir)
            Button("Agora não", role: .cancel) {}
        } message: {
            Text("Todos os subtópicos estão feitos.")
        }
        .onAppear { titulo = item.titulo }
        .onChange(of: item.titulo) { _, novo in titulo = novo }
        .onChange(of: tituloFocado) { _, focado in
            if !focado { guardarTitulo() }
        }
    }

    private func guardarTitulo() {
        guard titulo != item.titulo else { return }
        do {
            try tarefas.editarTitulo(item, para: titulo)
        } catch {
            titulo = item.titulo
        }
    }

    private func alternar(_ sub: Item) {
        withAnimation {
            if tarefas.alternarSubtopico(sub) {
                sugerirConcluir = true
            }
        }
    }

    private func concluir() {
        tarefas.concluir(item)
        dismiss()
    }
}

private struct LinhaSubtopico: View {
    let sub: Item
    let cor: Color
    let aoAlternar: () -> Void

    private var feito: Bool { sub.estado == .concluido }

    var body: some View {
        HStack(spacing: 12) {
            CirculoConcluir(feito: feito, cor: cor, acao: aoAlternar)
            Text(sub.titulo)
                .strikethrough(feito)
                .foregroundStyle(feito ? .secondary : .primary)
        }
    }
}
