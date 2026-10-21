import SwiftUI
import ToDoCore

/// Ícone de uma lista: um SF Symbol ou um emoji dentro de um círculo (DESIGN.md 6.1).
struct IconeListaView: View {
    let cor: CorLista
    let icone: String
    let emoji: String?
    var tamanho: CGFloat = 40
    /// Por defeito, a cor base da lista.
    var fundo: Color?

    init(cor: CorLista, icone: String, emoji: String?, tamanho: CGFloat = 40, fundo: Color? = nil) {
        self.cor = cor
        self.icone = icone
        self.emoji = emoji
        self.tamanho = tamanho
        self.fundo = fundo
    }

    init(lista: Lista, tamanho: CGFloat = 40, fundo: Color? = nil) {
        self.init(cor: lista.cor, icone: lista.icone, emoji: lista.emoji, tamanho: tamanho, fundo: fundo)
    }

    var body: some View {
        ZStack {
            Circle().fill(fundo ?? cor.base)
            if let emoji {
                Text(emoji)
                    .font(.system(size: tamanho * 0.5))
            } else {
                Image(systemName: icone)
                    .font(.system(size: tamanho * 0.45, weight: .semibold))
                    .foregroundStyle(cor.texto)
            }
        }
        .frame(width: tamanho, height: tamanho)
        .accessibilityHidden(true)
    }
}
