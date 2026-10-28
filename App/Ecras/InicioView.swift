import SwiftData
import SwiftUI
import ToDoCore

/// Ecrã Início (mocks 1 e 11): data, o cartão "Para ti" (DESIGN.md 7.21), grelha de espaços
/// (páginas de 4 com setas quando há mais de 4), o calendário e, no fundo, os itens que
/// expiram hoje.
struct InicioView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Environment(Calendario.self) private var calendario
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "ativo" && $0.fixado == false && $0.pai == nil })
    private var ativos: [Item]

    @AppStorage("mostrarCalendario") private var mostrarCalendario = true
    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?
    @State private var pagina = 0
    /// "Para ti" (DESIGN.md 7.21): o assunto dispensado com o "x" e as frases do modelo.
    @AppStorage("paraTiDispensado") private var paraTiDispensado = ""
    @State private var frasesParaTi: [String: String] = [:]

    /// Um lugar da grelha: um espaço ou o cartão "Nova lista".
    private enum Celula: Identifiable {
        case lista(Lista)
        case nova

        var id: String {
            switch self {
            case .lista(let lista): lista.id.uuidString
            case .nova: "nova"
            }
        }
    }

    private let colunas = [GridItem(.flexible(), spacing: Espaco.grelha), GridItem(.flexible(), spacing: Espaco.grelha)]
    private let tamanhoIconeHoje: CGFloat = 28

    var body: some View {
        let agora = Date.now
        let hoje = ativos
            .filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }
            .sorted { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) }
        @Bindable var estadoLigado = estado

        NavigationStack(path: $estadoLigado.caminho) {
            ScrollViewReader { rolagem in
                let sugestao = paraTi(agora)
                EcraBase(titulo: "Listas", sobretitulo: Formatos.cabecalho(agora)) {
                    if let sugestao, sugestao.chave != paraTiDispensado {
                        CartaoParaTi(
                            paraTi: sugestao,
                            frase: frasesParaTi[sugestao.chave] ?? sugestao.fraseBase,
                            agir: agir
                        ) {
                            withAnimation(.snappy) { paraTiDispensado = sugestao.chave }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: sugestao.chave) { await escreverFrase(sugestao) }
                    }

                    grelhaEspacos(agora: agora)

                    if mostrarCalendario {
                        SecaoCalendario()
                            .id("calendario")
                    }

                    if !hoje.isEmpty {
                        VStack(alignment: .leading, spacing: Espaco.curto) {
                            TituloSecao(texto: "Expiram hoje")
                            VStack(spacing: 0) {
                                ForEach(hoje) { item in
                                    NavigationLink(value: item) {
                                        linhaHoje(item)
                                    }
                                    .buttonStyle(.plain)
                                    if item != hoje.last {
                                        Divider().padding(.leading, Espaco.bloco + tamanhoIconeHoje + Espaco.grelha)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
                        }
                        .id("expiramHoje")
                    }
                }
                .onChange(of: estado.rolarParaCalendario) { _, rolar in
                    guard rolar else { return }
                    estado.rolarParaCalendario = false
                    withAnimation { rolagem.scrollTo("calendario", anchor: .bottom) }
                }
            }
            .navigationDestination(for: Lista.self) { ListaView(lista: $0) }
            .navigationDestination(for: Item.self) { DetalheNavegavel(item: $0) }
            .sheet(item: $formulario) { PersonalizarListaView(modo: $0) }
            .onChange(of: estado.abrirPersonalizar) { _, abrir in
                guard abrir, let lista = listas.first else { return }
                estado.abrirPersonalizar = false
                formulario = .editar(lista)
            }
            .confirmationDialog(
                "Apagar a lista «\(aApagar?.nome ?? "")»?",
                isPresented: Binding(presente: $aApagar),
                titleVisibility: .visible,
                presenting: aApagar
            ) { lista in
                Button("Apagar", role: .destructive) {
                    withAnimation { Tarefas(contexto: contexto).apagar(lista) }
                }
            } message: { lista in
                Text(mensagemApagar(lista))
            }
        }
    }

    private func celulas() -> [Celula] {
        var resultado = listas.map { Celula.lista($0) }
        // Com 4 espaços a vista fica cheia: o "Nova lista" abriria uma terceira fila. Aí
        // cria-se em Definições › Listas; com mais de 4, volta na última página.
        if listas.count < Tarefas.maxListas && listas.count != Espacos.porPagina {
            resultado.append(.nova)
        }
        return resultado
    }

    @ViewBuilder
    private func grelhaEspacos(agora: Date) -> some View {
        let paginas = Espacos.paginas(celulas(), espacos: listas.count)
        if paginas.count <= 1 {
            LazyVGrid(columns: colunas, spacing: Espaco.grelha) {
                ForEach(paginas.first ?? []) { celula($0, agora: agora, altura: 148) }
            }
        } else {
            VStack(spacing: Espaco.curto) {
                TabView(selection: $pagina) {
                    ForEach(paginas.indices, id: \.self) { indice in
                        LazyVGrid(columns: colunas, spacing: Espaco.grelha) {
                            ForEach(paginas[indice]) { celula($0, agora: agora, altura: 128) }
                        }
                        // Espaço para a sombra dos cartões, que a TabView cortaria.
                        .padding(.vertical, Espaco.curto)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .tag(indice)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 128 * 2 + Espaco.grelha + 2 * Espaco.curto)

                controlosPagina(total: paginas.count)

                if listas.count >= Tarefas.maxListas {
                    Text("Máximo de \(Tarefas.maxListas) espaços")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .onChange(of: paginas.count) { _, total in
                if pagina >= total { pagina = max(0, total - 1) }
            }
        }
    }

    @ViewBuilder
    private func celula(_ celula: Celula, agora: Date, altura: CGFloat) -> some View {
        switch celula {
        case .lista(let lista):
            NavigationLink(value: lista) {
                CartaoLista(lista: lista, agora: agora, altura: altura)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    formulario = .editar(lista)
                } label: {
                    Label("Personalizar lista", systemImage: "paintbrush")
                }
                Button(role: .destructive) {
                    aApagar = lista
                } label: {
                    Label("Apagar lista", systemImage: "trash")
                }
            }
        case .nova:
            Button {
                formulario = .nova
            } label: {
                CartaoNovaLista(altura: altura)
            }
            .buttonStyle(.plain)
        }
    }

    /// Setas ‹ › de vidro, pontos de página e "Espaços 1–4 de 6" (DESIGN.md 7.12b).
    private func controlosPagina(total: Int) -> some View {
        HStack {
            Button {
                withAnimation { pagina = max(0, pagina - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(SetaPagina())
            .disabled(pagina == 0)
            .accessibilityLabel("Espaços anteriores")

            Spacer()

            VStack(spacing: Espaco.fino) {
                HStack(spacing: Espaco.curto) {
                    ForEach(0..<total, id: \.self) { indice in
                        Circle()
                            .fill(indice == pagina ? Color.primary : Color(.systemGray3))
                            .frame(width: 8, height: 8)
                    }
                }
                Text(Espacos.rotuloPagina(pagina, espacos: listas.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Espacos.rotuloPagina(pagina, espacos: listas.count))

            Spacer()

            Button {
                withAnimation { pagina = min(total - 1, pagina + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(SetaPagina())
            .disabled(pagina >= total - 1)
            .accessibilityLabel("Espaços seguintes")
        }
        .sensoryFeedback(.selection, trigger: pagina)
    }

    /// Setas sólidas: o vidro fica só na barra de baixo e nos botões dos cantos (DESIGN.md 1.2).
    private struct SetaPagina: ButtonStyle {
        @Environment(\.isEnabled) private var ativa

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(ativa ? Color.primary : Color(.systemGray3))
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: .circle)
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .animation(.snappy, value: configuration.isPressed)
        }
    }

    private func linhaHoje(_ item: Item) -> some View {
        HStack(spacing: Espaco.grelha) {
            if let lista = item.lista {
                IconeListaView(lista: lista, tamanho: tamanhoIconeHoje)
            }
            Text(item.titulo)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Spacer()
            Text("Hoje")
                .font(.footnote.weight(.bold))
                .foregroundStyle(CoresEstado.expiraTinta)
        }
        .padding(.horizontal, Espaco.bloco)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    // MARK: - Para ti (DESIGN.md 7.21)

    /// Os eventos das próximas horas entram com o espaço a que pertencem.
    private func paraTi(_ agora: Date) -> ParaTi? {
        let eventos = calendario.eventos
            .filter { !$0.diaInteiro && $0.inicio > agora }
            .map { EventoProximo(titulo: $0.titulo, inicio: $0.inicio, listaId: calendario.espaco(de: $0.calendarioId)) }
        return try? Tarefas(contexto: contexto).paraTi(eventos: eventos)
    }

    /// Com o modelo do iPhone, troca a frase de base por uma escrita por ele (uma vez por assunto).
    private func escreverFrase(_ sugestao: ParaTi) async {
        guard frasesParaTi[sugestao.chave] == nil, Definicoes.carregar().inteligenciaAtiva,
              let frase = await Inteligencia.fraseParaTi(sugestao)
        else { return }
        withAnimation(.smooth) { frasesParaTi[sugestao.chave] = frase }
    }

    private func agir(_ acao: ParaTi.Acao) {
        let tarefas = Tarefas(contexto: contexto)
        func item(_ id: UUID) -> Item? {
            var pedido = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
            pedido.fetchLimit = 1
            return try? contexto.fetch(pedido).first
        }
        withAnimation(.snappy) {
            switch acao {
            case .abrirItem(let id):
                if let alvo = item(id) { estado.caminho.append(alvo) }
            case .manter(let id):
                if let alvo = item(id) { tarefas.manter(alvo, longo: false) }
            case .abrirLista(let id):
                if let lista = listas.first(where: { $0.id == id }) { estado.caminho.append(lista) }
            case .tornarPermanente(let id):
                if let lista = listas.first(where: { $0.id == id }) { try? tarefas.definirPermanente(lista, true) }
            case .manterLista(let id):
                if let lista = listas.first(where: { $0.id == id }) { tarefas.manterLista(lista) }
            }
        }
        try? contexto.save()
        estado.reagendarAvisos()
    }


    private func mensagemApagar(_ lista: Lista) -> String {
        switch Tarefas(contexto: contexto).contarItens(de: lista) {
        case 0: "A lista está vazia."
        case 1: "Apaga também 1 item. Esta ação não pode ser desfeita."
        case let n: "Apaga também \(n) itens. Esta ação não pode ser desfeita."
        }
    }
}
