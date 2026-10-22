import SwiftUI
import ToDoCore

/// Grelha 6 × 2 com as 12 cores da paleta (DESIGN.md 7.8).
struct SeletorCor: View {
    @Binding var selecao: CorLista

    private let colunas = Array(repeating: GridItem(.flexible(), spacing: Espaco.grelha), count: 6)

    var body: some View {
        LazyVGrid(columns: colunas, spacing: Espaco.grelha) {
            ForEach(CorLista.allCases, id: \.self) { cor in
                let escolhida = cor == selecao
                Button {
                    selecao = cor
                } label: {
                    Circle()
                        .fill(cor.base)
                        .frame(width: 40, height: 40)
                        .padding(Espaco.fino)
                        .overlay(Circle().stroke(cor.base, lineWidth: escolhida ? 2.5 : 0))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cor.nome)
                .accessibilityAddTraits(escolhida ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selecao)
    }
}

/// Grelha 6 × 3 com os símbolos ou os emojis possíveis para uma lista.
struct SeletorIcone: View {
    let cor: CorLista
    let emojis: Bool
    @Binding var icone: String
    @Binding var emoji: String?

    private let colunas = Array(repeating: GridItem(.flexible(), spacing: Espaco.curto), count: 6)

    var body: some View {
        LazyVGrid(columns: colunas, spacing: Espaco.grelha) {
            if emojis {
                ForEach(IconesLista.emojis, id: \.self) { opcao in
                    botao(escolhido: emoji == opcao, rotulo: opcao) {
                        Text(opcao).font(.title3)
                    } acao: {
                        emoji = opcao
                    }
                }
            } else {
                ForEach(IconesLista.simbolos.indices, id: \.self) { indice in
                    let opcao = IconesLista.simbolos[indice]
                    let escolhido = emoji == nil && icone == opcao.simbolo
                    botao(escolhido: escolhido, rotulo: opcao.nome) {
                        Image(systemName: opcao.simbolo)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(escolhido ? cor.texto : Color.primary)
                    } acao: {
                        icone = opcao.simbolo
                        emoji = nil
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: icone + (emoji ?? ""))
    }

    private func botao<Conteudo: View>(
        escolhido: Bool,
        rotulo: String,
        @ViewBuilder conteudo: () -> Conteudo,
        acao: @escaping () -> Void
    ) -> some View {
        Button(action: acao) {
            conteudo()
                .frame(width: 44, height: 44)
                .background(Circle().fill(escolhido ? cor.base : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rotulo)
        .accessibilityAddTraits(escolhido ? .isSelected : [])
    }
}
