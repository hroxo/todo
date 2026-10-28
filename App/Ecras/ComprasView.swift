import SwiftData
import SwiftUI
import ToDoCore

/// Uma lista de compras (DESIGN.md 7.15): uma secção por loja com "3 de 8", artigos que se
/// riscam com um toque (os riscados descem para o fim da loja) e, no fundo, "Nova loja".
/// Nada expira. O menu "…" partilha a lista por AirDrop.
struct ComprasView: View {
    let lista: Lista

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Environment(EstadoApp.self) private var estado
    @State private var personalizar = false
    @State private var apagarLista = false
    @State private var lojaARenomear: Item?
    @State private var novoNome = ""

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }

    var body: some View {
        let cor = lista.cor
        let lojas = lista.itensAtivos

        List {
            Section {
                cabecalho(lojas)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Espaco.fino, trailing: 0))

            ForEach(lojas) { loja in
                Section {
                    ForEach(artigos(de: loja)) { artigo in
                        linha(artigo, cor: cor)
                    }
                    CampoNovo(placeholder: "Adicionar em \(loja.titulo)", cor: cor.tinta) { titulo in
                        withAnimation { _ = try? tarefas.adicionarSubtopico(titulo: titulo, a: loja) }
                    }
                } header: {
                    cabecalhoLoja(loja, cor: cor)
                }
            }

            Section {
                CampoNovo(placeholder: lojas.isEmpty ? "Primeira loja (ex.: Continente)" : "Nova loja", cor: cor.tinta) { nome in
                    withAnimation { _ = try? tarefas.criarItem(titulo: nome, em: lista) }
                }
            } footer: {
                Text("Cada loja junta os artigos a comprar lá. Toca num artigo para o riscar.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(cor.fundo.ignoresSafeArea())
        .navigationTitle(lista.nome)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        PartilhaCompras.partilhar(lista, tarefas: tarefas)
                    } label: {
                        Label("Partilhar por AirDrop", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        personalizar = true
                    } label: {
                        Label("Personalizar lista", systemImage: "paintbrush")
                    }
                    BotaoPermanente(lista: lista)
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
        .tint(cor.tinta)
        .onAppear { estado.listaAtual = lista }
        .onDisappear {
            if estado.listaAtual == lista { estado.listaAtual = nil }
        }
        .sheet(isPresented: $personalizar) {
            PersonalizarListaView(modo: .editar(lista))
        }
        .alert("Nome da loja", isPresented: Binding(presente: $lojaARenomear)) {
            TextField("Nome", text: $novoNome)
            Button("Cancelar", role: .cancel) {}
            Button("OK") {
                if let loja = lojaARenomear { try? tarefas.editarTitulo(loja, para: novoNome) }
            }
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
            Text("Apaga todas as lojas e artigos. Esta ação não pode ser desfeita.")
        }
    }

    /// Por comprar primeiro; os riscados descem, pela ordem em que foram escritos.
    private func artigos(de loja: Item) -> [Item] {
        let todos = loja.subtopicosOrdenados
        return todos.filter { $0.estado != .concluido } + todos.filter { $0.estado == .concluido }
    }

    private func cabecalho(_ lojas: [Item]) -> some View {
        let total = lojas.reduce(0) { $0 + $1.subtopicosOrdenados.count }
        let feitos = lojas.reduce(0) { $0 + $1.subtopicosFeitos }
        return HStack(spacing: Espaco.grelha) {
            IconeListaView(lista: lista, tamanho: 56)
                .shadow(color: lista.cor.base.opacity(0.35), radius: 8, y: 6)
            VStack(alignment: .leading, spacing: Espaco.minimo) {
                Text(lista.nome)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(lista.cor.tinta)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text(total == 0 ? "Sem artigos" : "\(total - feitos) por comprar · \(feitos) no carrinho")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(lista.cor.tinta.opacity(0.8))
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, Espaco.fino)
    }

    private func cabecalhoLoja(_ loja: Item, cor: CorLista) -> some View {
        let total = loja.subtopicosOrdenados.count
        let feitos = loja.subtopicosFeitos
        return HStack {
            Text(loja.titulo)
                .font(.headline)
                .foregroundStyle(cor.tinta)
                .textCase(nil)
            Spacer()
            if total > 0 {
                Text("\(feitos) de \(total)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(feitos == total ? CoresEstado.concluido : .secondary)
                    .contentTransition(.numericText())
            }
            Menu {
                Button {
                    novoNome = loja.titulo
                    lojaARenomear = loja
                } label: {
                    Label("Mudar o nome", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    withAnimation { tarefas.apagar(loja) }
                } label: {
                    Label("Apagar loja", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Opções de \(loja.titulo)")
        }
    }

    private func linha(_ artigo: Item, cor: CorLista) -> some View {
        let feito = artigo.estado == .concluido
        return HStack(spacing: Espaco.grelha) {
            CirculoConcluir(feito: feito, cor: feito ? CoresEstado.concluido : cor.tinta) {
                alternar(artigo)
            }
            Text(artigo.titulo)
                .strikethrough(feito)
                .foregroundStyle(feito ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { alternar(artigo) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { tarefas.apagar(artigo) }
            } label: {
                Label("Apagar", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(feito ? "No carrinho" : "Por comprar")
    }

    private func alternar(_ artigo: Item) {
        withAnimation(.snappy) { _ = tarefas.alternarSubtopico(artigo) }
    }
}

/// Envia uma lista de compras num ficheiro `.todolista` pela folha de partilha (AirDrop,
/// Mensagens…). Quem a abre fica com uma cópia ou junta-a à sua (DESIGN.md 7.15).
enum PartilhaCompras {
    @MainActor
    static func partilhar(_ lista: Lista, tarefas: Tarefas) {
        guard let partilhada = try? tarefas.paraPartilhar(lista),
              let dados = try? partilhada.dados()
        else { return }
        try? tarefas.contexto.save()
        let gestor = FileManager.default
        let pasta = gestor.temporaryDirectory.appendingPathComponent("Partilhar", isDirectory: true)
        try? gestor.removeItem(at: pasta)
        guard (try? gestor.createDirectory(at: pasta, withIntermediateDirectories: true)) != nil else { return }
        let url = pasta.appendingPathComponent("\(lista.nome).\(ListaPartilhada.extensao)")
        guard (try? dados.write(to: url, options: .atomic)) != nil else { return }
        PartilhaCSV.mostrarFolha(com: url)
    }

    /// Abre um ficheiro recebido: cria a lista ou junta-a à que já existe. Devolve a lista.
    @MainActor
    static func abrir(_ url: URL, contexto: ModelContext) throws -> ResultadoJuntar {
        let acesso = url.startAccessingSecurityScopedResource()
        defer { if acesso { url.stopAccessingSecurityScopedResource() } }
        let recebida = try ListaPartilhada.ler(Data(contentsOf: url))
        let resultado = try Tarefas(contexto: contexto).juntar(recebida)
        try contexto.save()
        return resultado
    }
}
