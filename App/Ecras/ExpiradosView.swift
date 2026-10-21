import SwiftData
import SwiftUI
import ToDoCore

/// Expirados (mock "Expirados", DESIGN.md 7.9): o que perdeu o prazo fica aqui 14 dias,
/// com Recuperar e Apagar.
struct ExpiradosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]

    @State private var aEditar: Item?
    @State private var aApagar: Item?
    @State private var recuperados = 0

    private var tarefas: Tarefas { Tarefas(contexto: contexto) }

    var body: some View {
        let itens = expirados.sorted { ($0.expiradoEm ?? .distantPast) > ($1.expiradoEm ?? .distantPast) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(CoresEstado.expira)
                            Image(systemName: "hourglass")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Expirados")
                                .font(.largeTitle.weight(.heavy))
                                .accessibilityAddTraits(.isHeader)
                            Text("Ficam aqui \(tarefas.definicoes.diasRetencaoExpirados) dias antes de serem apagados")
                                .font(.footnote)
                                .foregroundStyle(CoresEstado.expiraTinta)
                        }
                    }

                    if itens.isEmpty {
                        ContentUnavailableView(
                            "Nada expirou",
                            systemImage: "hourglass",
                            description: Text("Os itens sem ações durante \(tarefas.definicoes.diasExpiracao) dias aparecem aqui.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(itens) { cartao($0) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(CoresEstado.expiradosFundo.ignoresSafeArea())
            .navigationTitle("Expirados")
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sensoryFeedback(.success, trigger: recuperados)
            .acoesDeItem(aEditar: $aEditar, aApagar: $aApagar)
        }
    }

    private func cartao(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let lista = item.lista {
                    IconeListaView(lista: lista, tamanho: 30)
                }
                Text(item.titulo)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
            }
            HStack(spacing: 10) {
                Text(meta(item))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button {
                    withAnimation { tarefas.recuperar(item) }
                    recuperados += 1
                    estado.reagendarAvisos()
                } label: {
                    Label("Recuperar", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
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
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
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
