import SwiftData
import SwiftUI
import ToDoCore

/// Concluídos (DESIGN.md 7.11): itens concluídos nos últimos dias, com Reabrir. Filtra por
/// lista e pela data de conclusão (Melhoria 3).
struct ConcluidosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "concluido" && $0.pai == nil })
    private var concluidos: [Item]
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    @State private var aEditar: Item?
    @State private var aApagar: Item?
    @State private var reabertos = 0

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }

    var body: some View {
        let agora = Date.now
        @Bindable var estado = estado
        let filtro = estado.filtroConcluidos
        let todos = concluidos.sorted { ($0.concluidoEm ?? .distantPast) > ($1.concluidoEm ?? .distantPast) }
        let itens = filtro.aplicar(todos, agora: agora)

        NavigationStack {
            EcraBaseLista(titulo: "Concluídos") {
                BotaoFiltro(filtro: $estado.filtroConcluidos, listas: listas, tituloData: "Data de conclusão")
            } conteudo: {
                if filtro.ativo {
                    Section {
                        FichaFiltro(texto: filtro.rotulo(listas: listas)) { limparFiltros() }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(itens) { item in
                        linha(item, agora: agora)
                            .swipeActions(edge: .leading) {
                                Button {
                                    reabrir(item)
                                } label: {
                                    Label("Reabrir", systemImage: "arrow.uturn.backward")
                                }
                                .tint(item.lista?.cor.base ?? .accentColor)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    aApagar = item
                                } label: {
                                    Label("Apagar", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .contextMenu {
                                Button {
                                    reabrir(item)
                                } label: {
                                    Label("Reabrir", systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) {
                                    aApagar = item
                                } label: {
                                    Label("Apagar", systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    if !itens.isEmpty {
                        Text("Ficam aqui \(tarefas.definicoes.diasRetencaoConcluidos) dias antes de serem apagados.")
                    }
                }
            }
            .overlay {
                if itens.isEmpty && filtro.ativo && !todos.isEmpty {
                    VazioComFiltros { limparFiltros() }
                } else if itens.isEmpty {
                    ContentUnavailableView(
                        "Nada concluído",
                        systemImage: "checkmark.circle",
                        description: Text("O que concluíres fica aqui \(tarefas.definicoes.diasRetencaoConcluidos) dias.")
                    )
                }
            }
            .sensoryFeedback(.success, trigger: reabertos)
            .acoesDeItem(aEditar: $aEditar, aApagar: $aApagar)
        }
    }

    private func linha(_ item: Item, agora: Date) -> some View {
        HStack(spacing: Espaco.grelha) {
            if let lista = item.lista {
                IconeListaView(lista: lista, tamanho: 30)
            }
            VStack(alignment: .leading, spacing: Espaco.minimo) {
                Text(item.titulo)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                if let quando = item.concluidoEm {
                    Text("Concluído \(Formatos.momento(quando, agora: agora))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CoresEstado.concluido)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 52)
    }

    private func limparFiltros() {
        withAnimation(.snappy) { estado.filtroConcluidos = FiltroItens() }
    }

    private func reabrir(_ item: Item) {
        withAnimation { tarefas.reabrir(item) }
        reabertos += 1
        estado.reagendarAvisos()
    }
}
