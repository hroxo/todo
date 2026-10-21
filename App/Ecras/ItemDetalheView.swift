import PhotosUI
import SwiftData
import SwiftUI
import ToDoCore

/// Detalhe de um item (mock "Detalhe do item"): anel grande e prazo, título, fotos,
/// subtópicos e o botão Manter em gotas de vidro no fundo. Fixar, Concluir e "…" ficam num
/// grupo de vidro no topo; a barra de separadores fica escondida.
struct ItemDetalheView: View {
    let item: Item

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
            VStack(alignment: .leading, spacing: 18) {
                cabecalho(agora: agora)

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

                secaoFotos
                secaoSubtopicos
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(cor.fundo.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            rodape
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
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
        HStack(spacing: 14) {
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
        VStack(alignment: .leading, spacing: 2) {
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
            .padding(.top, -10)
    }

    private var secaoFotos: some View {
        VStack(alignment: .leading, spacing: 8) {
            TituloSecao(texto: "Fotos", cor: cor.tinta)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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

        return VStack(alignment: .leading, spacing: 8) {
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
                        Divider().padding(.leading, 52)
                    }
                    if novoSubtopico {
                        CampoNovo(placeholder: "Novo subtópico", cor: cor.base, focarAoAparecer: true) { texto in
                            withAnimation { _ = try? tarefas.adicionarSubtopico(titulo: texto, a: item) }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
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

    private var feito: Bool { sub.estado == .concluido }

    var body: some View {
        HStack(spacing: 14) {
            CirculoConcluir(feito: feito, cor: cor, acao: aoAlternar)
            Text(sub.titulo)
                .strikethrough(feito)
                .foregroundStyle(feito ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
    }
}
