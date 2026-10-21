import SwiftData
import SwiftUI
import ToDoCore

/// Ecrã Início (mock "Início"): data, aviso de Expirados, grelha de cartões das listas e os
/// itens que expiram hoje.
struct InicioView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "ativo" && $0.fixado == false && $0.pai == nil })
    private var ativos: [Item]

    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?

    private let colunas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let agora = Date.now
        let hoje = ativos
            .filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }
            .sorted { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) }
        @Bindable var estadoLigado = estado

        NavigationStack(path: $estadoLigado.caminho) {
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

                    LazyVGrid(columns: colunas, spacing: 12) {
                        ForEach(listas) { lista in
                            NavigationLink(value: lista) {
                                CartaoLista(lista: lista, agora: agora)
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
                        }
                        Button {
                            formulario = .nova
                        } label: {
                            CartaoNovaLista()
                        }
                        .buttonStyle(.plain)
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
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
