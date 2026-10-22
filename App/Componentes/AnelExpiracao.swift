import SwiftUI
import ToDoCore

/// Anel que se esvazia até o item expirar (DESIGN.md 7.3). Começa no topo e corre no
/// sentido dos ponteiros do relógio.
struct AnelExpiracao: View {
    let fracao: Double
    let cor: Color
    var tamanho: CGFloat = 34
    var espessura: CGFloat = 5
    var trilho: Color = CoresEstado.anelTrilho

    var body: some View {
        ZStack {
            Circle()
                .stroke(trilho, lineWidth: espessura)
            Circle()
                .trim(from: 0, to: max(0.001, fracao))
                .stroke(cor, style: StrokeStyle(lineWidth: espessura, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(espessura / 2)
        .frame(width: tamanho, height: tamanho)
        .animation(.smooth, value: fracao)
        .accessibilityHidden(true)
    }
}

/// O anel de um item, ou o alfinete quando está fixado. Ao concluir na linha, o anel
/// enche-se na cor de concluído, com um visto (Melhoria 2).
struct IndicadorPrazo: View {
    let item: Item
    let cor: CorLista
    let agora: Date
    var tamanho: CGFloat = 34
    var espessura: CGFloat = 5
    var concluido = false

    var body: some View {
        if concluido {
            ZStack {
                AnelExpiracao(fracao: 1, cor: CoresEstado.concluido, tamanho: tamanho, espessura: espessura)
                Image(systemName: "checkmark")
                    .font(.system(size: tamanho * 0.4, weight: .heavy))
                    .foregroundStyle(CoresEstado.concluido)
                    .transition(.scale.combined(with: .opacity))
            }
            .accessibilityHidden(true)
        } else if item.fixado {
            ZStack {
                Circle().fill(cor.fundo)
                Image(systemName: "pin.fill")
                    .font(.system(size: tamanho * 0.45, weight: .semibold))
                    .foregroundStyle(cor.tinta)
            }
            .frame(width: tamanho, height: tamanho)
            .accessibilityHidden(true)
        } else if let prazo = Prazo(item: item, agora: agora) {
            AnelExpiracao(
                fracao: prazo.fracao,
                cor: prazo.ultimoDia ? CoresEstado.expira : cor.base,
                tamanho: tamanho,
                espessura: espessura
            )
        }
    }
}
