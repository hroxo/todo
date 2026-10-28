import SwiftData
import SwiftUI
import ToDoCore

/// Expirados (mock "Expirados", DESIGN.md 7.9): o que perdeu o prazo fica aqui 14 dias,
/// com Recuperar e Apagar. Filtra por lista e pela data de expiração (Melhoria 3).
struct ExpiradosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    @State private var aEditar: Item?
    @State private var aApagar: Item?
    @State private var recuperados = 0

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }

    var body: some View {
        @Bindable var estado = estado
        let filtro = estado.filtroExpirados
        let todos = expirados.sorted { ($0.expiradoEm ?? .distantPast) > ($1.expiradoEm ?? .distantPast) }
        let itens = filtro.aplicar(todos, agora: .now)

        NavigationStack {
            EcraBase(titulo: "Expirados", fundo: CoresEstado.expiradosFundo) {
                BotaoFiltro(filtro: $estado.filtroExpirados, listas: listas, tituloData: "Data de expiração")
                    .tint(CoresEstado.expiraTinta)
            } conteudo: {
                if filtro.ativo {
                    FichaFiltro(texto: filtro.rotulo(listas: listas)) { limparFiltros() }
                }

                HStack(spacing: Espaco.grelha) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(CoresEstado.expira))
                        .accessibilityHidden(true)
                    Text("Ficam aqui \(tarefas.definicoes.diasRetencaoExpirados) dias antes de serem apagados")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CoresEstado.expiraTinta)
                }

                if itens.isEmpty && filtro.ativo && !todos.isEmpty {
                    VazioComFiltros { limparFiltros() }
                        .padding(.top, Espaco.margem)
                } else if itens.isEmpty {
                    EstadoVazio(
                        pose: .celebrar,
                        titulo: "Nada expirou",
                        texto: "Estás em dia. O que ficar \(Formatos.dias(tarefas.definicoes.diasExpiracao)) sem ações aparece aqui.",
                        cor: CoresEstado.expiraTinta
                    )
                } else {
                    ForEach(itens) { cartao($0) }
                }
            }
            .sensoryFeedback(.success, trigger: recuperados)
            .acoesDeItem(aEditar: $aEditar, aApagar: $aApagar)
        }
    }

    /// Título e "Lista · apagado em N dias" em cima; Recuperar (a toda a largura, para nunca
    /// cortar) e Apagar em baixo.
    private func cartao(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: Espaco.grelha) {
            HStack(spacing: Espaco.grelha) {
                if let lista = item.lista {
                    IconeListaView(lista: lista, tamanho: 30)
                }
                VStack(alignment: .leading, spacing: Espaco.minimo) {
                    Text(item.titulo)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                    Text(meta(item))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: Espaco.grelha) {
                Button {
                    withAnimation { tarefas.recuperar(item) }
                    recuperados += 1
                    estado.reagendarAvisos()
                } label: {
                    Label("Recuperar", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(CoresEstado.expiraTinta)
                        .background(CoresEstado.expira.opacity(0.18), in: .capsule)
                }
                .buttonStyle(.plain)
                Button {
                    aApagar = item
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apagar")
            }
        }
        .padding(Espaco.bloco)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func limparFiltros() {
        withAnimation(.snappy) { estado.filtroExpirados = FiltroItens() }
    }

    private func meta(_ item: Item) -> String {
        let nome = item.lista?.nome ?? ""
        switch tarefas.diasAteApagar(item) ?? 0 {
        case 0: return "\(nome) · apagado hoje"
        case 1: return "\(nome) · apagado em 1 dia"
        case let n: return "\(nome) · apagado em \(n) dias"
        }
    }
}
