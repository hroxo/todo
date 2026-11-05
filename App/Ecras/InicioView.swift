import SwiftData
import SwiftUI
import ToDoCore

/// Ecrã Início (mocks 1 e 11): data, a Ampulheta anfitriã com "Para ti" no balão (DESIGN.md
/// 7.21 e 7.22), grelha de espaços (páginas de 4 com setas quando há mais de 4), os itens que
/// expiram hoje e o calendário.
struct InicioView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Environment(Calendario.self) private var calendario
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "ativo" && $0.fixado == false && $0.pai == nil })
    private var ativos: [Item]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "concluido" && $0.pai == nil })
    private var concluidos: [Item]

    @AppStorage("mostrarCalendario") private var mostrarCalendario = true
    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?
    @State private var pagina = 0
    /// "Para ti" (DESIGN.md 7.21): o assunto dispensado com o "x" e as frases do modelo.
    @AppStorage("paraTiDispensado") private var paraTiDispensado = ""
    @State private var frasesParaTi: [String: String] = [:]
    /// O dia em que já houve festa, para os confettis só saírem uma vez (DESIGN.md 7.22).
    @AppStorage("festaDia") private var festaDia = ""
    /// O ponto acabado de concluir aqui: o balão diz "Boa!" e oferece Anular durante 4 s.
    @State private var acabado: Acabado?
    @State private var saltos = 0
    @State private var graos: [Grao] = []
    @State private var posicaoAmpulheta = CGPoint.zero
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.ceu) private var ceu

    private struct Acabado: Equatable {
        let id = UUID()
        let item: Item
        let antes: AntesDeConcluir
    }

    private struct Grao: Identifiable {
        let id = UUID()
        let origem: CGPoint
    }

    private static let espacoEcra = "inicio"

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

    var body: some View {
        let agora = Date.now
        let hoje = ativos
            .filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }
            .sorted { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) }
        @Bindable var estadoLigado = estado

        NavigationStack(path: $estadoLigado.caminho) {
            ScrollViewReader { rolagem in
                let sugestao = paraTi(agora).flatMap { $0.chave == paraTiDispensado ? nil : $0 }
                let progresso = ProgressoDia(ativos: ativos, concluidos: concluidos, agora: agora)
                EcraBase(
                    titulo: "Listas",
                    sobretitulo: Formatos.cabecalho(agora),
                    cena: true,
                    ganho: progresso.completo
                ) {
                    anfitria(progresso: progresso, sugestao: sugestao, agora: agora)
                        .task(id: sugestao?.chave) {
                            if let sugestao { await escreverFrase(sugestao) }
                        }

                    grelhaEspacos(agora: agora)

                    if !hoje.isEmpty {
                        VStack(alignment: .leading, spacing: Espaco.curto) {
                            TituloSecao(texto: "Expiram hoje", cor: Ceu.paleta(ceu.fase).tinta)
                            VStack(spacing: 0) {
                                ForEach(hoje) { item in
                                    linhaHoje(item, agora: agora)
                                    if item != hoje.last {
                                        Divider().padding(.leading, Espaco.bloco + 44 + Espaco.grelha)
                                    }
                                }
                            }
                            .background(Ceu.cartao, in: .rect(cornerRadius: 18, style: .continuous))
                        }
                        .id("expiramHoje")
                    }

                    if mostrarCalendario {
                        SecaoCalendario()
                            .id("calendario")
                    }
                }
                .coordinateSpace(name: Self.espacoEcra)
                .overlay {
                    ForEach(graos) { grao in
                        GraoVoador(de: grao.origem, para: posicaoAmpulheta)
                    }
                }
                .onAppear { festejar(progresso) }
                .onChange(of: progresso.completo) { festejar(progresso) }
                #if DEBUG
                .onChange(of: estado.rolarParaCalendario) { _, rolar in
                    guard rolar else { return }
                    estado.rolarParaCalendario = false
                    withAnimation { rolagem.scrollTo("calendario", anchor: .bottom) }
                }
                #endif
            }
            .navigationDestination(for: Lista.self) { ListaView(lista: $0) }
            .navigationDestination(for: Item.self) { DetalheNavegavel(item: $0) }
            .sheet(item: $formulario) { PersonalizarListaView(modo: $0) }
            #if DEBUG
            .onChange(of: estado.abrirPersonalizar) { _, abrir in
                guard abrir, let lista = listas.first else { return }
                estado.abrirPersonalizar = false
                formulario = .editar(lista)
            }
            #endif
            .apagarLista($aApagar)
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
                        .frame(maxHeight: .infinity, alignment: .top)
                        .tag(indice)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 128 * 2 + Espaco.grelha)

                controlosPagina(total: paginas.count)

                if listas.count >= Tarefas.maxListas {
                    Text("Máximo de \(Tarefas.maxListas) espaços")
                        .font(.caption)
                        .foregroundStyle(Ceu.paleta(ceu.fase).tinta)
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
                            .fill(Ceu.paleta(ceu.fase).tinta.opacity(indice == pagina ? 1 : 0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                Text(Espacos.rotuloPagina(pagina, espacos: listas.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Ceu.paleta(ceu.fase).tinta)
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
                .background(Ceu.cartao, in: .circle)
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .animation(.snappy, value: configuration.isPressed)
        }
    }

    /// Tocar no anel conclui aqui mesmo e lança um grão de areia para a Ampulheta.
    private func linhaHoje(_ item: Item, agora: Date) -> some View {
        LinhaHoje(item: item, agora: agora, espaco: Self.espacoEcra) { origem in
            lancarGrao(de: origem)
        } aoConcluir: {
            concluir(item)
        }
    }

    private struct LinhaHoje: View {
        let item: Item
        let agora: Date
        let espaco: String
        let aoTocar: (CGPoint) -> Void
        let aoConcluir: () -> Void
        @State private var moldura = CGRect.zero

        var body: some View {
            NavigationLink(value: item) {
                LinhaItem(item: item, cor: item.lista?.cor ?? .azul, agora: agora, aoConcluir: aoConcluir) {
                    aoTocar(CGPoint(x: moldura.minX + 22, y: moldura.midY))
                }
                .padding(.horizontal, Espaco.grelha)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(espaco)) } action: { moldura = $0 }
        }
    }

    private func lancarGrao(de origem: CGPoint) {
        guard !reduzirMovimento else { return }
        let grao = Grao(origem: origem)
        graos.append(grao)
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            graos.removeAll { $0.id == grao.id }
        }
    }

    private func concluir(_ item: Item) {
        let antes = withAnimation(.snappy) { Tarefas(contexto: contexto).concluir(item) }
        try? contexto.save()
        estado.reagendarAvisos()
        withAnimation(.snappy) {
            saltos += 1
            acabado = Acabado(item: item, antes: antes)
        }
    }

    private func anular(_ ultimo: Acabado) {
        withAnimation(.snappy) {
            Tarefas(contexto: contexto).anular(ultimo.item, para: ultimo.antes)
            acabado = nil
        }
        try? contexto.save()
        estado.reagendarAvisos()
    }

    /// Uma vez por dia, em qualquer ecrã, quando o último ponto de hoje fica feito.
    private func festejar(_ progresso: ProgressoDia) {
        let hoje = Formatos.cabecalho(.now)
        guard progresso.completo, festaDia != hoje else { return }
        festaDia = hoje
        estado.festa = UUID()
    }

    // MARK: - Anfitriã (DESIGN.md 7.22)

    /// O balão diz, por esta ordem: o "Boa!" do ponto acabado de concluir, a sugestão de "Para ti"
    /// ou a frase do dia.
    private func anfitria(progresso: ProgressoDia, sugestao: ParaTi?, agora: Date) -> some View {
        let fraseDoDia = progresso.frase(saudacao: ceu.saudacao)
        let frase: String
        let botoes: [CartaoAnfitria.Botao]
        if let acabado {
            frase = progresso.completo ? fraseDoDia : "Boa! Menos um."
            botoes = [.init(rotulo: "Anular") { anular(acabado) }]
        } else if let sugestao {
            frase = frasesParaTi[sugestao.chave] ?? sugestao.fraseBase
            botoes = sugestao.botoes.map { botao in .init(rotulo: botao.rotulo) { agir(botao.acao) } }
        } else {
            frase = fraseDoDia
            botoes = []
        }
        // Vai à base e não às @Query daqui, para contar o mesmo que o widget (com os fixados).
        let glassy = try? Tarefas(contexto: contexto).estadoGlassy()
        return CartaoAnfitria(
            nivelAreia: glassy?.nivelAreia ?? 0,
            pose: progresso.completo ? .celebrar : .para(agora, tudoEmDia: false, estado: glassy),
            frase: frase,
            botoes: botoes,
            dispensar: acabado == nil ? sugestao.map { sugestao in
                { withAnimation(.snappy) { paraTiDispensado = sugestao.chave } }
            } : nil,
            saltos: saltos
        )
        .onGeometryChange(for: CGPoint.self) { proxy in
            let moldura = proxy.frame(in: .named(Self.espacoEcra))
            // No bolbo de cima: concluir dá tempo, e a areia sobe.
            return CGPoint(x: moldura.minX + 35, y: moldura.midY - 14)
        } action: { posicaoAmpulheta = $0 }
        .task(id: acabado?.id) {
            guard acabado != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { acabado = nil }
        }
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

}
