import SwiftUI
import ToDoCore
import WidgetKit

/// URL que abre a captura rápida na app (o "+" dos widgets e o controlo Nova nota).
let urlCaptura = URL(string: "todo://captura")!

/// Widget médio "o que importa agora" (DESIGN.md 7.14), ao estilo Fitness: à esquerda o número
/// grande do dia ("1 expira hoje", ou os ativos) com a frase por baixo; à direita os 3 pontos
/// mais importantes, cada um com o anel na cor da lista (tocar no anel conclui sem abrir a app)
/// e a razão; no canto, o "+" para uma nota nova. Partilhada com o ecrã de demonstração.
struct VistaPontos: View {
    let resumo: ResumoWidget?
    let data: Date

    @Environment(\.widgetRenderingMode) private var modo

    var body: some View {
        let hoje = resumo?.expiramHoje ?? 0
        let numero = hoje > 0 ? hoje : (resumo?.totalAtivos ?? 0)
        let legenda = hoje > 0 ? (hoje == 1 ? "expira hoje" : "expiram hoje") : (numero == 1 ? "ponto ativo" : "pontos ativos")
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(numero)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(hoje > 0 && modo == .fullColor ? CoresEstado.expira : .primary)
                    .contentTransition(.numericText(value: Double(numero)))
                    .widgetAccentable()
                Text(legenda)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(resumo?.frase ?? "Abre a ToDo para começar")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(3)
                    .contentTransition(.opacity)
            }
            .frame(width: 104, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if let pontos = resumo?.pontos, !pontos.isEmpty {
                    ForEach(pontos) { ponto in
                        linha(ponto)
                            .id(ponto.id)
                            .transition(.push(from: .bottom))
                    }
                } else {
                    Text("Nada a pedir atenção.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .bottomTrailing) {
            Link(destination: urlCaptura) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .heavy))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.primary.opacity(0.08)))
                    .widgetAccentable()
            }
            .accessibilityLabel("Nova nota")
        }
    }

    private func linha(_ ponto: ResumoWidget.Ponto) -> some View {
        let cor = CorLista.deChave(ponto.cor)
        let ultimoDia = ponto.ultimoDia(em: data)
        return HStack(spacing: 8) {
            Button(intent: ConcluirPontoIntent(id: ponto.id)) {
                AnelExpiracao(
                    fracao: ponto.fracao(em: data),
                    cor: ultimoDia ? CoresEstado.expira : cor.base,
                    tamanho: 26,
                    espessura: 4.5
                )
                .widgetAccentable()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Concluir \(ponto.titulo)")
            VStack(alignment: .leading, spacing: 0) {
                Text(ponto.titulo)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text(ponto.razao)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ultimoDia && modo == .fullColor ? CoresEstado.expiraTinta : .secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Fundo do widget médio: a cor de fundo da lista do primeiro ponto, a desvanecer.
struct FundoPontos: View {
    let resumo: ResumoWidget?

    var body: some View {
        let cor = resumo?.pontos.first.map { CorLista.deChave($0.cor) }
        LinearGradient(
            colors: [cor?.fundo ?? Color(.secondarySystemBackground), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// "+" redondo do ecrã bloqueado: abre a captura com o teclado ativo.
struct VistaMaisCircular: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
        }
        .widgetURL(urlCaptura)
        .accessibilityLabel("Nova nota")
    }
}

/// Retangular do ecrã bloqueado: "+ Nova nota" e quantos pontos expiram hoje.
struct VistaMaisRetangular: View {
    let resumo: ResumoWidget?

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(.primary.opacity(0.15))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text("Nova nota")
                    .font(.headline)
                Text(resumo.map { ResumoWidget.fraseBase(totalAtivos: $0.totalAtivos, expiramHoje: $0.expiramHoje) } ?? "ToDo")
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(urlCaptura)
    }
}
