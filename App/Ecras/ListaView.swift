import SwiftData
import SwiftUI
import ToDoCore

/// Itens ativos de uma lista (mock "Lista"): cabeçalho com o ícone, secções Fixados e Ativos.
/// Tocar no anel conclui, com "Anular" durante 4 s. Deslizar para a direita: Manter e
/// Concluir. Para a esquerda: Apagar. Pressão longa: todas as ações.
struct ListaView: View {
    let lista: Lista

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Environment(EstadoApp.self) private var estado
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @State private var aEditar: Item?
    @State private var aApagar: Item?
    @State private var personalizar = false
    @State private var apagarLista = false
    @State private var sucessos = 0
    @State private var ultimoConcluido: UltimoConcluido?

    /// O último item concluído, para o aviso "Concluído · Anular" (Melhoria 2).
    private struct UltimoConcluido: Equatable {
        let id = UUID()
        let item: Item
        let antes: AntesDeConcluir
    }

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }

    var body: some View {
        if lista.isDeleted || lista.modelContext == nil {
            Color.clear
        } else {
            conteudo
        }
    }

    private var conteudo: some View {
        let cor = lista.cor
        let agora = Date.now
        let ativos = lista.itensAtivos
        let fixados = ativos.filter(\.fixado)
        let outros = ativos.filter { !$0.fixado }

        return List {
            Section {
                cabecalho(ativos: ativos.count, hoje: lista.expiramHoje(agora: agora).count)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Espaco.fino, trailing: 0))

            if !fixados.isEmpty {
                Section {
                    ForEach(fixados) { linha($0, cor: cor, agora: agora) }
                } header: {
                    TituloSecao(texto: "Fixados", cor: cor.tinta)
                }
            }

            if !outros.isEmpty {
                Section {
                    ForEach(outros) { linha($0, cor: cor, agora: agora) }
                } header: {
                    TituloSecao(texto: "Ativos", cor: cor.tinta)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(cor.fundo.ignoresSafeArea())
        .overlay {
            if ativos.isEmpty {
                ContentUnavailableView(
                    "Nada por fazer",
                    systemImage: "checkmark.circle",
                    description: Text("Toca em + para escrever uma nota nesta lista.")
                )
            }
        }
        .navigationTitle(lista.nome)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        personalizar = true
                    } label: {
                        Label("Personalizar lista", systemImage: "paintbrush")
                    }
                    Button(role: .destructive) {
                        apagarLista = true
                    } label: {
                        Label("Apagar lista", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mais opções")
            }
        }
        .overlay(alignment: .bottom) {
            if let ultimoConcluido {
                avisoAnular(ultimoConcluido)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: ultimoConcluido?.id) {
            guard ultimoConcluido != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { ultimoConcluido = nil }
        }
        .tint(cor.tinta)
        .sensoryFeedback(.success, trigger: sucessos)
        .onAppear { estado.listaAtual = lista }
        .onDisappear {
            if estado.listaAtual == lista { estado.listaAtual = nil }
        }
        .acoesDeItem(aEditar: $aEditar, aApagar: $aApagar)
        .sheet(isPresented: $personalizar) {
            PersonalizarListaView(modo: .editar(lista))
        }
        .confirmationDialog(
            "Apagar a lista «\(lista.nome)»?",
            isPresented: $apagarLista,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive) {
                let tarefas = tarefas
                let lista = lista
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tarefas.apagar(lista) }
            }
        } message: {
            Text(mensagemApagar)
        }
    }

    private func cabecalho(ativos: Int, hoje: Int) -> some View {
        HStack(spacing: Espaco.grelha) {
            IconeListaView(lista: lista, tamanho: 56)
                .shadow(color: lista.cor.base.opacity(0.35), radius: 8, y: 6)
            VStack(alignment: .leading, spacing: Espaco.minimo) {
                Text(lista.nome)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(lista.cor.tinta)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text(resumo(ativos: ativos, hoje: hoje))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(lista.cor.tinta.opacity(0.8))
            }
        }
        .padding(.horizontal, Espaco.fino)
    }

    private func resumo(ativos: Int, hoje: Int) -> String {
        let parteAtivos = ativos == 1 ? "1 ativo" : "\(ativos) ativos"
        switch hoje {
        case 0: return parteAtivos
        case 1: return parteAtivos + " · 1 expira hoje"
        default: return parteAtivos + " · \(hoje) expiram hoje"
        }
    }

    private func linha(_ item: Item, cor: CorLista, agora: Date) -> some View {
        NavigationLink(value: item) {
            LinhaItem(item: item, cor: cor, agora: agora) {
                concluir(item)
            }
        }
        .swipeActions(edge: .leading) {
            if !item.fixado {
                Button {
                    tarefas.manter(item, longo: false)
                    estado.reagendarAvisos()
                    sucessos += 1
                } label: {
                    Label("Manter +\(tarefas.definicoes.diasManterCurto)", systemImage: "arrow.clockwise")
                }
                .tint(cor.base)
            }
            Button {
                concluir(item)
            } label: {
                Label("Concluir", systemImage: "checkmark.circle")
            }
            .tint(CoresEstado.concluido)
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
            MenuAcoesItem(item: item, listas: listas, aEditar: $aEditar, aApagar: $aApagar)
        }
    }

    private func concluir(_ item: Item) {
        let antes = withAnimation(.snappy) { tarefas.concluir(item) }
        sucessos += 1
        estado.reagendarAvisos()
        withAnimation(.snappy) { ultimoConcluido = UltimoConcluido(item: item, antes: antes) }
    }

    private func anular(_ ultimo: UltimoConcluido) {
        withAnimation(.snappy) {
            tarefas.anular(ultimo.item, para: ultimo.antes)
            ultimoConcluido = nil
        }
        estado.reagendarAvisos()
    }

    /// Aviso no fundo durante 4 s: "Concluído" e o botão Anular.
    private func avisoAnular(_ ultimo: UltimoConcluido) -> some View {
        HStack(spacing: Espaco.grelha) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CoresEstado.concluido)
                .accessibilityHidden(true)
            Text("Concluído")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: Espaco.curto)
            Button("Anular") { anular(ultimo) }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(lista.cor.tinta)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, Espaco.margem)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Espaco.margem)
        .padding(.bottom, Espaco.curto)
    }

    private var mensagemApagar: String {
        switch tarefas.contarItens(de: lista) {
        case 0: "A lista está vazia."
        case 1: "Apaga também 1 item. Esta ação não pode ser desfeita."
        case let n: "Apaga também \(n) itens. Esta ação não pode ser desfeita."
        }
    }
}
