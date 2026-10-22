import SwiftUI
import ToDoCore
import UIKit

/// Botão de filtro de Concluídos e Expirados (Melhoria 3): um menu com a lista e o período.
/// Com um filtro ativo, o ícone fica preenchido.
struct BotaoFiltro: View {
    @Binding var filtro: FiltroItens
    let listas: [Lista]
    /// "Data de conclusão" ou "Data de expiração".
    let tituloData: String

    var body: some View {
        Menu {
            Section("Lista") {
                Picker("Lista", selection: $filtro.listaId) {
                    Text("Todas").tag(UUID?.none)
                    ForEach(listas) { lista in
                        Label {
                            Text(lista.nome)
                        } icon: {
                            IconeMenu(lista: lista)
                        }
                        .tag(Optional(lista.id))
                    }
                }
                .pickerStyle(.inline)
            }
            Section(tituloData) {
                Picker(tituloData, selection: $filtro.periodo) {
                    ForEach(PeriodoFiltro.allCases, id: \.self) { periodo in
                        Text(periodo.nome).tag(periodo)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Image(systemName: filtro.ativo ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(filtro.ativo ? "Filtros ativos" : "Filtrar")
        .sensoryFeedback(.selection, trigger: filtro)
        .onChange(of: listas.map(\.id), initial: true) { _, ids in
            // A lista do filtro foi apagada.
            if let id = filtro.listaId, !ids.contains(id) {
                filtro.listaId = nil
            }
        }
    }
}

/// Ícone da lista para os menus, já na cor da lista: os menus do sistema pintam os
/// símbolos de cinzento, a não ser que a imagem leve a cor original.
private struct IconeMenu: View {
    let lista: Lista

    var body: some View {
        if let emoji = lista.emoji {
            Text(emoji)
        } else if let simbolo = UIImage(systemName: lista.icone)?
            .withTintColor(UIColor(lista.cor.base), renderingMode: .alwaysOriginal) {
            Image(uiImage: simbolo)
        } else {
            Image(systemName: lista.icone)
        }
    }
}

/// Ficha por baixo do título com o filtro ativo ("Trabalho · Últimos 7 dias") e um ✕ para
/// o limpar.
struct FichaFiltro: View {
    let texto: String
    let limpar: () -> Void

    var body: some View {
        Button(action: limpar) {
            HStack(spacing: Espaco.curto) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.footnote.weight(.bold))
                Text(texto)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Espaco.grelha)
            .frame(minHeight: 36)
            .background(Color(.tertiarySystemFill), in: .capsule)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filtro: \(texto)")
        .accessibilityHint("Toca para limpar os filtros")
    }
}

/// Estado vazio quando os filtros escondem tudo.
struct VazioComFiltros: View {
    let limpar: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Nada com estes filtros", systemImage: "line.3.horizontal.decrease.circle")
        } actions: {
            Button("Limpar filtros", action: limpar)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}

extension FiltroItens {
    /// O texto da ficha, com o nome da lista escolhida.
    func rotulo(listas: [Lista]) -> String {
        rotulo(nomeLista: listas.first { $0.id == listaId }?.nome)
    }
}
