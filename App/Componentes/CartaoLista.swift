import SwiftUI
import ToDoCore

/// Cartão de uma lista na grelha do Início (DESIGN.md 7.2).
struct CartaoLista: View {
    let lista: Lista
    let agora: Date
    /// 148 pt; 128 pt quando os espaços estão em páginas.
    var altura: CGFloat = 148

    var body: some View {
        let cor = lista.cor
        let ativos = lista.itensAtivos.count

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconeListaView(lista: lista, tamanho: 40, fundo: cor.ficha)
                Spacer()
                AnelExpiracao(
                    fracao: lista.frescura(agora: agora),
                    cor: cor.texto,
                    tamanho: 36,
                    espessura: 6,
                    trilho: cor.ficha
                )
            }
            Spacer(minLength: Espaco.grelha)
            Text(lista.nome)
                .font(.headline.bold())
                .lineLimit(2)
            Text(ativos == 1 ? "1 ativo" : "\(ativos) ativos")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(cor.texto)
        .padding(Espaco.grelha)
        .frame(maxWidth: .infinity, minHeight: altura, alignment: .leading)
        .background(cor.base, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: cor.base.opacity(0.3), radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lista.nome), \(ativos == 1 ? "1 item ativo" : "\(ativos) itens ativos")")
        .accessibilityAddTraits(.isButton)
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
