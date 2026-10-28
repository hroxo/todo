import PhotosUI
import SwiftData
import SwiftUI
import ToDoCore

/// Detalhe de um item (mock "Detalhe do item"): anel grande e prazo, título, fotos,
/// subtópicos e o botão Manter em gotas de vidro no fundo. Fixar, Concluir e "…" ficam num
/// grupo de vidro no topo; a barra de separadores fica escondida. Com `navegacao`, os botões
/// ˄ ˅ e o puxão nas pontas do scroll passam ao item anterior ou seguinte da lista.
struct ItemDetalheView: View {
    let item: Item
    var navegacao: NavegacaoDetalhe?

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Environment(EstadoApp.self) private var estado
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    @State private var titulo = ""
    @FocusState private var tituloFocado: Bool
    @State private var nota = ""
    @FocusState private var notaFocada: Bool
    @State private var aEditar: Item?
    @State private var aApagar: Item?
    @State private var sugerirConcluir = false
    @State private var novoSubtopico = false
    @State private var selecaoFotos: [PhotosPickerItem] = []
    @State private var fotoAberta: Foto?
    @State private var sucessos = 0
    /// Quanto o scroll passou da ponta: positivo no fim (seguinte), negativo no topo (anterior).
    @State private var puxao: CGFloat = 0

    /// Puxão extra nas pontas para mudar de item.
    private let limiarPuxao: CGFloat = 60

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }
    private var cor: CorLista { item.listaEfetiva?.cor ?? .azul }

    var body: some View {
        // Durante a animação de fecho depois de apagar, o item já não existe.
        if item.isDeleted || item.modelContext == nil {
            Color.clear
        } else {
            conteudo
        }
    }

    private var conteudo: some View {
        let agora = Date.now

        return ScrollView {
            VStack(alignment: .leading, spacing: Espaco.bloco) {
                cabecalho(agora: agora)

                // A descrição fica colada ao título.
                VStack(alignment: .leading, spacing: Espaco.fino) {
                    TextField("Título", text: $titulo, axis: .vertical)
                        .font(.title2.bold())
                        .focused($tituloFocado)
                        .submitLabel(.done)
                        .onChange(of: titulo) { _, novo in
                            // Num campo de várias linhas, o Enter termina a edição.
                            if novo.contains("\n") {
                                titulo = novo.replacingOccurrences(of: "\n", with: "")
                                tituloFocado = false
                            }
                        }

                    descricao
                }

                secaoFotos
                secaoSubtopicos
            }
            .padding(.horizontal, Espaco.margem)
            .padding(.bottom, Espaco.fim)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.always)
        .onScrollGeometryChange(for: CGFloat.self, of: Self.distanciaPuxao(em:)) { _, novo in
            puxao = novo
        }
        .onScrollPhaseChange { antiga, nova in
            // Só muda de item quando se solta o dedo depois de puxar.
            if antiga == .interacting && nova != .interacting {
                soltarPuxao()
            }
        }
        .sensoryFeedback(.selection, trigger: abs(puxao) >= limiarPuxao) { _, passou in passou }
        .overlay(alignment: .top) {
            if let anterior = navegacao?.anterior, puxao < 0 {
                indicadorPuxao("Anterior: \(anterior.titulo)", simbolo: "chevron.up", progresso: -puxao)
            }
        }
        .overlay(alignment: .bottom) {
            if let seguinte = navegacao?.seguinte, puxao > 0 {
                indicadorPuxao("Seguinte: \(seguinte.titulo)", simbolo: "chevron.down", progresso: puxao)
            }
        }
        .accessibilityActions {
            if let navegacao, let anterior = navegacao.anterior {
                Button("Item anterior") { navegacao.ir(anterior, false) }
            }
            if let navegacao, let seguinte = navegacao.seguinte {
                Button("Item seguinte") { navegacao.ir(seguinte, true) }
            }
        }
        .background(cor.fundo.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            rodape
                .padding(.horizontal, Espaco.bloco)
                .padding(.bottom, Espaco.curto)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if let navegacao {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if let anterior = navegacao.anterior { navegacao.ir(anterior, false) }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(navegacao.anterior == nil)
                    .accessibilityLabel("Item anterior")

                    Button {
                        if let seguinte = navegacao.seguinte { navegacao.ir(seguinte, true) }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(navegacao.seguinte == nil)
                    .accessibilityLabel("Item seguinte")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if item.estado == .ativo {
                    Button {
                        tarefas.definirFixado(item, !item.fixado)
                        estado.reagendarAvisos()
                    } label: {
                        Image(systemName: item.fixado ? "pin.fill" : "pin")
                    }
                    .accessibilityLabel(item.fixado ? "Desafixar" : "Fixar")

                    Button(action: concluir) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(CoresEstado.concluido)
                    }
                    .accessibilityLabel("Concluir")
                }

                Menu {
                    MenuAcoesItem(item: item, listas: listas, aEditar: $aEditar, aApagar: $aApagar, completo: false, aConcluir: concluir)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mais opções")
            }
        }
        .tint(cor.tinta)
        .sensoryFeedback(.success, trigger: sucessos)
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
        .fullScreenCover(item: $fotoAberta) { foto in
            VisualizadorFoto(dados: foto.dados)
        }
        .onAppear {
            titulo = item.titulo
            nota = item.nota ?? ""
        }
        .onDisappear {
            guard !item.isDeleted, item.modelContext != nil else { return }
            guardarTitulo()
            tarefas.definirNota(item, nota)
        }
        .onChange(of: item.titulo) { _, novo in titulo = novo }
        .onChange(of: tituloFocado) { _, focado in
            if !focado { guardarTitulo() }
        }
        .onChange(of: notaFocada) { _, focada in
            if !focada { tarefas.definirNota(item, nota) }
        }
        .onChange(of: selecaoFotos) { _, selecao in
            guard !selecao.isEmpty else { return }
            Task {
                for dados in await ProcessarFoto.carregar(selecao) {
                    _ = try? tarefas.adicionarFoto(dados, a: item)
                }
                selecaoFotos = []
            }
        }
    }

    // MARK: - Partes

    @ViewBuilder
    private func cabecalho(agora: Date) -> some View {
        HStack(spacing: Espaco.grelha) {
            if item.estado == .concluido {
                circuloEstado("checkmark", fundo: CoresEstado.concluido)
                textosCabecalho("Concluído", cor: CoresEstado.concluido)
            } else if item.estado == .expirado {
                circuloEstado("hourglass", fundo: CoresEstado.expira)
                textosCabecalho("Expirado", cor: CoresEstado.expiraTinta)
            } else if item.fixado {
                circuloEstado("pin.fill", fundo: cor.base)
                textosCabecalho("Não expira", cor: cor.tinta)
            } else if let prazo = Prazo(item: item, agora: agora) {
                AnelExpiracao(
                    fracao: prazo.fracao,
                    cor: prazo.ultimoDia ? CoresEstado.expira : cor.base,
                    tamanho: 64,
                    espessura: 10,
                    trilho: cor.base.opacity(0.2)
                )
                textosCabecalho(prazo.rotuloLongo, cor: prazo.ultimoDia ? CoresEstado.expiraTinta : cor.tinta)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func circuloEstado(_ simbolo: String, fundo: Color) -> some View {
        ZStack {
            Circle().fill(fundo)
            Image(systemName: simbolo)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    private func textosCabecalho(_ texto: String, cor: Color) -> some View {
        VStack(alignment: .leading, spacing: Espaco.minimo) {
            Text(texto)
                .font(.title.weight(.heavy))
                .foregroundStyle(cor)
            Text("Última ação \(Formatos.momento(item.ultimaAcaoEm, agora: .now))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Descrição curta do ponto (2–3 linhas), logo a seguir ao título.
    private var descricao: some View {
        TextField("Acrescentar descrição", text: $nota, axis: .vertical)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineLimit(1...3)
            .focused($notaFocada)
            .onChange(of: nota) { _, novo in
                if novo.count > Tarefas.maxDescricao {
                    nota = String(novo.prefix(Tarefas.maxDescricao))
                }
            }
    }

    private var secaoFotos: some View {
        VStack(alignment: .leading, spacing: Espaco.curto) {
            TituloSecao(texto: "Fotos", cor: cor.tinta)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Espaco.curto) {
                    ForEach(item.fotosOrdenadas) { foto in
                        Button {
                            fotoAberta = foto
                        } label: {
                            MiniaturaFoto(dados: foto.dados)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation { tarefas.remover(foto) }
                            } label: {
                                Label("Remover foto", systemImage: "trash")
                            }
                        }
                    }
                    if item.fotos.count < Tarefas.maxFotos {
                        PhotosPicker(
                            selection: $selecaoFotos,
                            maxSelectionCount: Tarefas.maxFotos - item.fotos.count,
                            matching: .images
                        ) {
                            BotaoBiblioteca(cor: cor.tinta)
                        }
                        .accessibilityLabel("Adicionar foto da biblioteca")
                    }
                }
            }
        }
    }

    private var secaoSubtopicos: some View {
        let subs = item.subtopicosOrdenados

        return VStack(alignment: .leading, spacing: Espaco.curto) {
            HStack {
                TituloSecao(
                    texto: subs.isEmpty ? "Subtópicos" : "Subtópicos · \(item.subtopicosFeitos) de \(subs.count)",
                    cor: cor.tinta
                )
                Spacer()
                Button {
                    novoSubtopico = true
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(cor.texto)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(cor.base))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Adicionar subtópico")
            }

            if !subs.isEmpty || novoSubtopico {
                VStack(spacing: 0) {
                    ForEach(subs) { sub in
                        LinhaSubtopico(sub: sub, cor: cor.base) { alternar(sub) }
                            .contextMenu {
                                Button { aEditar = sub } label: { Label("Editar", systemImage: "pencil") }
                                Button(role: .destructive) { aApagar = sub } label: { Label("Apagar", systemImage: "trash") }
                            }
                        Divider().padding(.leading, LinhaSubtopico.recuoDivisor)
                    }
                    if novoSubtopico {
                        CampoNovo(placeholder: "Novo subtópico", cor: cor.base, focarAoAparecer: true) { texto in
                            withAnimation { _ = try? tarefas.adicionarSubtopico(titulo: texto, a: item) }
                        }
                        .padding(.horizontal, Espaco.bloco)
                        .frame(minHeight: Espaco.linhaSubtopico)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var rodape: some View {
        switch item.estado {
        case .ativo:
            if !item.fixado {
                BotaoManter(
                    cor: cor,
                    diasCurto: tarefas.definicoes.diasManterCurto,
                    diasLongo: tarefas.definicoes.diasManterLongo
                ) { longo in
                    withAnimation(.smooth) { tarefas.manter(item, longo: longo) }
                    estado.reagendarAvisos()
                }
            }
        case .concluido:
            botaoRodape("Reabrir", simbolo: "arrow.uturn.backward") {
                tarefas.reabrir(item)
                estado.reagendarAvisos()
            }
        case .expirado:
            botaoRodape("Recuperar", simbolo: "arrow.uturn.backward") {
                tarefas.recuperar(item)
                estado.reagendarAvisos()
            }
        }
    }

    private func botaoRodape(_ titulo: String, simbolo: String, acao: @escaping () -> Void) -> some View {
        Button {
            withAnimation { acao() }
            sucessos += 1
        } label: {
            Label(titulo, systemImage: simbolo)
                .font(.title3.weight(.heavy))
                .frame(width: 200, height: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(cor.base)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Navegar entre itens (Melhoria 5)

    /// Quanto o conteúdo passou da ponta. O `contentOffset` conta com as margens da área
    /// segura: em repouso no topo vale `-contentInsets.top`.
    private static func distanciaPuxao(em geometria: ScrollGeometry) -> CGFloat {
        let topo = -geometria.contentInsets.top
        let fundo = max(topo, geometria.contentSize.height - geometria.containerSize.height + geometria.contentInsets.bottom)
        let y = geometria.contentOffset.y
        if y > fundo { return y - fundo }
        if y < topo { return y - topo }
        return 0
    }

    private func soltarPuxao() {
        guard let navegacao, abs(puxao) >= limiarPuxao else { return }
        if puxao > 0, let seguinte = navegacao.seguinte {
            navegacao.ir(seguinte, true)
        } else if puxao < 0, let anterior = navegacao.anterior {
            navegacao.ir(anterior, false)
        }
    }

    /// "Seguinte: <título>" no fundo, ou "Anterior: <título>" no topo, enquanto se puxa.
    private func indicadorPuxao(_ texto: String, simbolo: String, progresso: CGFloat) -> some View {
        let pronto = progresso >= limiarPuxao
        return HStack(spacing: Espaco.curto) {
            Image(systemName: simbolo)
                .fontWeight(.bold)
            Text(texto)
                .lineLimit(1)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(pronto ? cor.texto : cor.tinta)
        .padding(.horizontal, Espaco.bloco)
        .frame(minHeight: 36)
        .background(pronto ? cor.base : Color(.secondarySystemGroupedBackground), in: .capsule)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
        .opacity(min(1, progresso / limiarPuxao))
        .padding(Espaco.curto)
        .animation(.snappy, value: pronto)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Ações

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
        estado.reagendarAvisos()
        sucessos += 1
        dismiss()
    }
}

private struct LinhaSubtopico: View {
    let sub: Item
    let cor: Color
    let aoAlternar: () -> Void

    /// O divisor começa no texto: margem, o círculo (`.title2`, cerca de 24 pt) e o espaço.
    static let recuoDivisor = Espaco.bloco + 24 + Espaco.grelha

    private var feito: Bool { sub.estado == .concluido }

    var body: some View {
        HStack(spacing: Espaco.grelha) {
            CirculoConcluir(feito: feito, cor: cor, acao: aoAlternar)
            Text(sub.titulo)
                .strikethrough(feito)
                .foregroundStyle(feito ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Espaco.bloco)
        .frame(minHeight: Espaco.linhaSubtopico)
    }
}

/// Vizinhos do item na lista e como mudar para eles (Melhoria 5).
struct NavegacaoDetalhe {
    let anterior: Item?
    let seguinte: Item?
    /// O item para onde ir e se é o seguinte (verdadeiro) ou o anterior.
    let ir: (Item, Bool) -> Void
}

/// O Detalhe com a navegação entre os itens da lista. Mostra um item de cada vez e troca-o
/// no lugar, com um deslize vertical curto (só fade com "Reduzir movimento"); o "voltar"
/// regressa sempre à lista.
struct DetalheNavegavel: View {
    @State private var atual: Item
    @State private var paraSeguinte = true
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    init(item: Item) {
        _atual = State(initialValue: item)
    }

    var body: some View {
        ZStack {
            ItemDetalheView(item: atual, navegacao: navegacao)
                .id(atual.id)
                .transition(transicao)
        }
    }

    private var navegacao: NavegacaoDetalhe? {
        guard !atual.isDeleted, atual.modelContext != nil, let lista = atual.lista else { return nil }
        let ordem = NavegacaoItens.ordem(lista)
        guard ordem.contains(where: { $0.id == atual.id }) else { return nil }
        return NavegacaoDetalhe(
            anterior: NavegacaoItens.anterior(de: atual, em: ordem),
            seguinte: NavegacaoItens.seguinte(de: atual, em: ordem),
            ir: ir
        )
    }

    private var transicao: AnyTransition {
        guard !reduzirMovimento else { return .opacity }
        let deslize: CGFloat = 48
        return .asymmetric(
            insertion: .offset(y: paraSeguinte ? deslize : -deslize).combined(with: .opacity),
            removal: .offset(y: paraSeguinte ? -deslize : deslize).combined(with: .opacity)
        )
    }

    private func ir(_ item: Item, seguinte: Bool) {
        paraSeguinte = seguinte
        withAnimation(.snappy) { atual = item }
    }
}
