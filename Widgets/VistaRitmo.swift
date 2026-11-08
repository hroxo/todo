import SwiftUI
import ToDoCore
import WidgetKit

/// Widget "O teu ritmo" (Melhoria 33, DESIGN.md 7.24): os últimos dias, verdes quando
/// concluíste um ponto, vermelhos quando algo expirou e neutros sem atividade. O pequeno mostra
/// 7 dias numa linha; o médio 15, com o Glassy. Conta dias, nunca pontos. Partilhada com o
/// ecrã de demonstração.
struct VistaRitmo: View {
    let resumo: ResumoWidget?
    let data: Date
    /// 7 no pequeno, 15 no médio.
    var quantos = 7

    @Environment(\.widgetRenderingMode) private var modo

    private var dias: [DiaHistorico]? { resumo?.dias.map { Array($0.suffix(quantos)) } }
    /// Depois da hora do Fecho do dia, os pontos que chegam ao fim (DESIGN.md 7.25).
    private var fecho: Int { resumo?.fechoPendente(em: data) ?? 0 }

    var body: some View {
        if let dias {
            Group {
                if quantos > 7 { medio(dias) } else { pequeno(dias) }
            }
            .widgetURL(fecho > 0 ? urlFecho : nil)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                titulo
                Spacer(minLength: 0)
                Text("Abre a ToDo para começar o teu ritmo.")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var titulo: some View {
        Text("O teu ritmo")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private func contagem(_ dias: [DiaHistorico], tamanho: CGFloat = 40) -> some View {
        let verdes = dias.filter { $0.estado == .verde }.count
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(verdes)")
                .font(.system(size: tamanho, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(verdes)))
                .widgetAccentable()
            Text(verdes == 1 ? "dia verde em \(dias.count)" : "dias verdes em \(dias.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func pequeno(_ dias: [DiaHistorico]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titulo
            contagem(dias)
            Spacer(minLength: 6)
            HStack(spacing: 0) {
                ForEach(Array(dias.enumerated()), id: \.element.id) { indice, dia in
                    VStack(spacing: 3) {
                        BolaDia(dia: dia, hoje: indice == dias.count - 1, tamanho: 16)
                        Text(dia.letra)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func medio(_ dias: [DiaHistorico]) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                titulo
                contagem(dias, tamanho: 34)
                Spacer(minLength: 4)
                if fecho > 0 {
                    Link(destination: urlFecho) {
                        Label("Fechar o dia", systemImage: "moon.stars.fill")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.primary.opacity(0.08)))
                            .widgetAccentable()
                    }
                    .accessibilityHint(ProgressoDia.fraseFecho(fecho))
                } else if modo == .fullColor {
                    let pose = VistaPontos.pose(resumo, data)
                    let nivel = resumo?.glassy?.nivelAreia
                    Ampulheta(pose: pose, tema: .geral, nivelAreia: nivel)
                        .frame(width: 32, height: 40)
                        .id("\(pose)-\(nivel ?? -1)")
                        .transition(.opacity)
                }
            }
            .frame(width: 104, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 8) {
                ForEach(Array(dias.enumerated()), id: \.element.id) { indice, dia in
                    VStack(spacing: 2) {
                        BolaDia(dia: dia, hoje: indice == dias.count - 1, tamanho: 22)
                        Text(dia.letra)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Um dia: verde com ✓, vermelho com ✕, neutro só com o contorno tracejado. A marca diz o
/// mesmo que a cor, também no modo tingido do ecrã principal (DESIGN.md 9). Hoje tem um anel.
struct BolaDia: View {
    let dia: DiaHistorico
    var hoje = false
    var tamanho: CGFloat = 16
    /// Na semana e no mês da app (Melhoria 35): um dia que ainda não chegou, só uma sombra.
    var futuro = false
    /// O rótulo do VoiceOver, quando quem chama sabe mais (o dia por vir).
    var rotulo: String?

    var body: some View {
        ZStack {
            if futuro {
                Circle().fill(.secondary.opacity(0.18))
            } else {
                estado
            }
        }
        .frame(width: tamanho, height: tamanho)
        .padding(2)
        .overlay {
            if hoje { Circle().strokeBorder(.primary.opacity(0.5), lineWidth: 1.5) }
        }
        .widgetAccentable()
        .accessibilityElement()
        .accessibilityLabel(rotulo ?? (hoje ? "Hoje, " + dia.rotulo : dia.rotulo))
    }

    @ViewBuilder
    private var estado: some View {
        switch dia.estado {
        case .verde:
            Circle().fill(CoresEstado.concluido)
            marca("checkmark")
        case .vermelho:
            Circle().fill(CorLista.vermelho.base)
            marca("xmark")
        case .neutro:
            Circle().strokeBorder(.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
        }
    }

    private func marca(_ simbolo: String) -> some View {
        Image(systemName: simbolo)
            .font(.system(size: tamanho * 0.5, weight: .heavy))
            .foregroundStyle(.white)
    }
}
