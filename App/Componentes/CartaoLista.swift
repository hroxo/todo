import SwiftUI
import ToDoCore

/// Cartão de uma lista na grelha do Início (DESIGN.md 7.2).
struct CartaoLista: View {
    let lista: Lista
    let agora: Date
    /// 148 pt; 128 pt quando os espaços estão em páginas.
    var altura: CGFloat = 148

    @Environment(\.modelContext) private var contexto

    var body: some View {
        let cor = lista.cor
        // Nas compras conta o que falta comprar e o anel enche com o carrinho (DESIGN.md 7.15).
        let artigos = lista.itensAtivos.flatMap(\.subtopicosOrdenados)
        let porComprar = artigos.filter { $0.estado != .concluido }.count
        let ativos = lista.ehCompras ? porComprar : lista.itensAtivos.count
        // Uma lista vazia que vai desaparecer: o anel esvazia nos 5 dias (DESIGN.md 7.17).
        let tarefas = Tarefas(contexto: contexto)
        let saida = tarefas.quandoDesaparece(lista)
        let fracao = fracaoAnel(saida: saida, artigos: artigos.count, porComprar: porComprar)
        // Vazia e a sair: o número grande passa a ser os dias que faltam.
        let diasParaSair = saida.map { max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: agora), to: Calendar.current.startOfDay(for: $0)).day ?? 0) }
        let numero = diasParaSair ?? ativos
        let legenda = diasParaSair.map { $0 == 0 ? "sai hoje" : ($0 == 1 ? "dia para sair" : "dias para sair") }
            ?? (lista.ehCompras ? "por fazer" : (ativos == 1 ? "ativo" : "ativos"))
        let hoje = lista.expiramHoje(agora: agora).count
        let aExpirar = hoje > 0

        // Estilo Fitness: o nome por cima e o número grande e arredondado em baixo.
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconeListaView(lista: lista, tamanho: 36, fundo: cor.ficha)
                Spacer()
                AnelExpiracao(
                    fracao: fracao,
                    cor: cor.texto,
                    tamanho: 40,
                    espessura: 7,
                    trilho: cor.ficha
                )
            }
            Spacer(minLength: 0)
            Text(lista.nome)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .opacity(0.9)
            HStack(alignment: .firstTextBaseline, spacing: Espaco.fino) {
                Text("\(numero)")
                    .font(.system(size: altura > 140 ? 40 : 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(legenda)
                    .font(.footnote.weight(.semibold))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(cor.texto)
        .padding(Espaco.grelha)
        .frame(maxWidth: .infinity, minHeight: altura, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            if aExpirar {
                fichaHoje(hoje).padding(Espaco.grelha)
            }
        }
        .background(cor.base, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: cor.base.opacity(0.3), radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(lista.nome), " + (lista.ehCompras ? "\(ativos) por fazer" : (ativos == 1 ? "1 item ativo" : "\(ativos) itens ativos"))
                + (aExpirar ? ", \(hoje == 1 ? "1 expira" : "\(hoje) expiram") hoje" : "")
                + (saida.map { ", vazia, \(SaidaLista.texto($0, agora: agora).lowercased())" } ?? "")
        )
        .accessibilityAddTraits(.isButton)
    }

    private func fracaoAnel(saida: Date?, artigos: Int, porComprar: Int) -> Double {
        if let saida, let desde = lista.vaziaDesde {
            return max(0, min(1, saida.timeIntervalSince(agora) / max(1, saida.timeIntervalSince(desde))))
        }
        if lista.ehCompras {
            return artigos == 0 ? 0 : Double(artigos - porComprar) / Double(artigos)
        }
        return lista.frescura(agora: agora)
    }

    /// Quantos itens expiram hoje, numa ficha branca com o laranja de "a expirar".
    private func fichaHoje(_ total: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.fill")
            Text("\(total) hoje")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(CoresEstado.expiraTinta)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .lineLimit(1)
        .fixedSize()
        .background(.white, in: .capsule)
    }
}

/// Último lugar da grelha: abre Personalizar lista para criar uma nova.
struct CartaoNovaLista: View {
    var altura: CGFloat = 148

    var body: some View {
        VStack(spacing: Espaco.curto) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
            Text("Nova lista")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: altura)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        )
        .contentShape(.rect(cornerRadius: 22))
    }
}
