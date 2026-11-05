import SwiftUI
import ToDoCore

/// Linha de um item principal (DESIGN.md 7.4): anel, título, resumo e tempo restante.
/// Tocar no anel (ou no alfinete) conclui o item; tocar no resto da linha abre o Detalhe.
struct LinhaItem: View {
    let item: Item
    let cor: CorLista
    let agora: Date
    /// Chamado depois da animação do anel; quem chama conclui o item.
    var aoConcluir: () -> Void = {}
    /// Chamado logo no toque, antes da animação: o Início lança o grão de areia.
    var aoTocarConcluir: () -> Void = {}

    @State private var concluindo = false
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private var prazo: Prazo? { Prazo(item: item, agora: agora) }

    var body: some View {
        // Na animação de saída o item pode já estar apagado (por exemplo, noutro aparelho).
        if item.foiApagado {
            Color.clear
        } else {
            conteudo
        }
    }

    private var conteudo: some View {
        HStack(spacing: Espaco.grelha) {
            botaoConcluir

            HStack(spacing: Espaco.grelha) {
                VStack(alignment: .leading, spacing: Espaco.minimo) {
                    Text(item.titulo)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: Espaco.fino) {
                        if !item.fotos.isEmpty {
                            Image(systemName: "photo")
                        }
                        Text(item.resumo)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: Espaco.curto)

                if item.fixado {
                    Text("Não expira")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let prazo {
                    Text(prazo.rotuloCurto)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(prazo.ultimoDia ? CoresEstado.expiraTinta : cor.tinta)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rotuloAcessivel)
        }
        .frame(minHeight: Espaco.linhaItem)
        .accessibilityElement(children: .contain)
    }

    /// O anel enche-se, fica verde com um visto e só depois o item sai da lista.
    private var botaoConcluir: some View {
        Button {
            guard !concluindo else { return }
            withAnimation(.snappy) { concluindo = true }
            aoTocarConcluir()
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                aoConcluir()
            }
        } label: {
            IndicadorPrazo(item: item, cor: cor, agora: agora, concluido: concluindo)
                .scaleEffect(concluindo ? 1.15 : 1)
                .animation(.spring(duration: 0.3, bounce: 0.6), value: concluindo)
                .frame(width: 44, height: 44)
                .overlay {
                    if concluindo && !reduzirMovimento { FaiscasConcluir() }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(concluindo)
        .accessibilityLabel("Concluir")
        .accessibilityHint(tempoRestante)
    }

    private var tempoRestante: String {
        item.fixado ? "Não expira" : (prazo?.rotuloLongo ?? "")
    }

    private var rotuloAcessivel: String {
        [item.titulo, item.resumo, tempoRestante].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
