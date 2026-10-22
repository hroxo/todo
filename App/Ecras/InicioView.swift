import SwiftData
import SwiftUI
import ToDoCore

/// Ecrã Início (mocks 1 e 11): data, avisos (Expirados e "expiram hoje"), grelha de espaços
/// (páginas de 4 com setas quando há mais de 4), o calendário e, no fundo, os itens que
/// expiram hoje.
struct InicioView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "ativo" && $0.fixado == false && $0.pai == nil })
    private var ativos: [Item]

    @AppStorage("mostrarCalendario") private var mostrarCalendario = true
    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?
    @State private var pagina = 0

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

    private let colunas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let agora = Date.now
        let hoje = ativos
            .filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }
            .sorted { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) }
        @Bindable var estadoLigado = estado

        NavigationStack(path: $estadoLigado.caminho) {
            ScrollViewReader { rolagem in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatos.cabecalho(agora).uppercased())
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Listas")
                            .font(.largeTitle.weight(.heavy))
                            .accessibilityAddTraits(.isHeader)
                    }

                    if !expirados.isEmpty {
                        avisoExpirados
                    }

                    if !hoje.isEmpty {
                        avisoExpiramHoje(hoje.count, rolagem: rolagem)
                    }

                    grelhaEspacos(agora: agora)

                    if mostrarCalendario {
                        SecaoCalendario()
                            .padding(.top, 4)
                            .id("calendario")
                    }

                    if !hoje.isEmpty {
                        TituloSecao(texto: "Expiram hoje")
                            .padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(hoje) { item in
                                NavigationLink(value: item) {
                                    linhaHoje(item)
                                }
                                .buttonStyle(.plain)
                                if item != hoje.last {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
                        .id("expiramHoje")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .onChange(of: estado.rolarParaCalendario) { _, rolar in
                guard rolar else { return }
                estado.rolarParaCalendario = false
                withAnimation { rolagem.scrollTo("calendario", anchor: .bottom) }
            }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Listas")
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: Lista.self) { ListaView(lista: $0) }
            .navigationDestination(for: Item.self) { ItemDetalheView(item: $0) }
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
        if listas.count < Tarefas.maxListas {
            resultado.append(.nova)
        }
        return resultado
    }

    @ViewBuilder
    private func grelhaEspacos(agora: Date) -> some View {
        let paginas = Espacos.paginas(celulas(), espacos: listas.count)
        if paginas.count <= 1 {
            LazyVGrid(columns: colunas, spacing: 12) {
                ForEach(paginas.first ?? []) { celula($0, agora: agora, altura: 148) }
            }
        } else {
            VStack(spacing: 10) {
                TabView(selection: $pagina) {
                    ForEach(paginas.indices, id: \.self) { indice in
                        LazyVGrid(columns: colunas, spacing: 12) {
                            ForEach(paginas[indice]) { celula($0, agora: agora, altura: 128) }
                        }
                        .padding(.vertical, 8)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .tag(indice)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 128 * 2 + 12 + 16)

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
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(pagina == 0)
            .accessibilityLabel("Espaços anteriores")

            Spacer()

            VStack(spacing: 4) {
                HStack(spacing: 6) {
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
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(pagina >= total - 1)
            .accessibilityLabel("Espaços seguintes")
        }
        .sensoryFeedback(.selection, trigger: pagina)
    }

    private var avisoExpirados: some View {
        Button {
            estado.separador = .expirados
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .foregroundStyle(CoresEstado.expira)
                Text(expirados.count == 1 ? "1 item em Expirados" : "\(expirados.count) itens em Expirados")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Ver")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(CoresEstado.expiraTinta)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(CoresEstado.expiradosFundo, in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// "Expiram hoje" está no fundo do Início; o aviso no topo leva até lá.
    private func avisoExpiramHoje(_ total: Int, rolagem: ScrollViewProxy) -> some View {
        Button {
            withAnimation { rolagem.scrollTo("expiramHoje", anchor: .bottom) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(CoresEstado.expira)
                Text(total == 1 ? "1 item expira hoje" : "\(total) itens expiram hoje")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(CoresEstado.expiraTinta)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Desce até aos itens que expiram hoje")
    }

    private func linhaHoje(_ item: Item) -> some View {
        HStack(spacing: 12) {
            if let lista = item.lista {
                IconeListaView(lista: lista, tamanho: 28)
            }
            Text(item.titulo)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Spacer()
            Text("Hoje")
                .font(.footnote.weight(.bold))
                .foregroundStyle(CoresEstado.expiraTinta)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func mensagemApagar(_ lista: Lista) -> String {
        switch Tarefas(contexto: contexto).contarItens(de: lista) {
        case 0: "A lista está vazia."
        case 1: "Apaga também 1 item. Esta ação não pode ser desfeita."
        case let n: "Apaga também \(n) itens. Esta ação não pode ser desfeita."
        }
    }
}
