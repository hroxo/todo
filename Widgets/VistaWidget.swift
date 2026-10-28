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

    /// A pose da Ampulheta quando não há pontos: "tudo em dia" só quando a app disse que não
    /// há nenhum ponto ativo.
    static func pose(_ resumo: ResumoWidget?, _ data: Date) -> PoseMascote {
        .para(data, tudoEmDia: resumo?.totalAtivos == 0)
    }

    var body: some View {
        if let pontos = resumo?.pontos, !pontos.isEmpty {
            comPontos
        } else {
            VistaVazia(pose: Self.pose(resumo, data), tema: resumo?.tema ?? .geral, semDados: resumo == nil)
        }
    }

    private var comPontos: some View {
        let hoje = resumo?.expiramHoje ?? 0
        let numero = hoje > 0 ? hoje : (resumo?.totalAtivos ?? 0)
        let legenda = hoje > 0 ? (hoje == 1 ? "expira hoje" : "expiram hoje") : (numero == 1 ? "ponto ativo" : "pontos ativos")
        return HStack(alignment: .top, spacing: 14) {
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
                ForEach(resumo?.pontos ?? []) { ponto in
                    linha(ponto)
                        .id(ponto.id)
                        .transition(.push(from: .bottom))
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

/// O widget sem pontos: a Ampulheta numa pose do dia, com o título e uma linha por baixo, e
/// o "+ Nova nota" no canto. Sem dados da app (sem App Group), convida a abri-la.
struct VistaVazia: View {
    let pose: PoseMascote
    var tema: TemaMascote = .geral
    var semDados = false

    /// Azul escuro nos cenários claros; no tema, a cor mais escura do cenário.
    private var corTexto: Color {
        if pose.cenarioEscuro { return .white }
        guard pose.doTema(tema) else { return Color(red: 0.05, green: 0.27, blue: 0.49) }
        switch tema.cenario {
        case .trabalho: return Color(red: 0.24, green: 0.2, blue: 0.54)
        case .pessoal: return Color(red: 0.09, green: 0.2, blue: 0.02)
        default: return Color(red: 0.02, green: 0.17, blue: 0.33)
        }
    }

    var body: some View {
        let claro = pose.cenarioEscuro
        let naJanela = pose.doTema(tema) && tema == .viagem
        HStack(spacing: 14) {
            if naJanela {
                // A janela do avião está no cenário, à esquerda: a Ampulheta senta-se ao lado.
                Color.clear.frame(width: 112)
            }
            Ampulheta(pose: pose, tema: tema)
                .frame(width: pose == .dormir ? 118 : (naJanela ? 70 : 92), height: 118)
                .id("\(pose)-\(tema)")
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 3) {
                Text(pose.titulo(tema))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(semDados && pose != .dormir ? "Toca para abrir a ToDo." : pose.subtitulo(tema))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .opacity(0.8)
                    .lineLimit(2)
            }
            .foregroundStyle(corTexto)
            .contentTransition(.opacity)
            // Espaço para o "+ Nova nota" no canto, para o texto nunca lhe tocar.
            .padding(.bottom, 28)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottomTrailing) {
            Link(destination: urlCaptura) {
                Label("Nova nota", systemImage: "plus")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(corTexto)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(claro ? 0.18 : 0.85)))
            }
            .accessibilityLabel("Nova nota")
        }
    }
}

/// Fundo do widget médio: com pontos, a cor de fundo da lista do primeiro, a desvanecer; sem
/// pontos, o cenário da pose da Ampulheta.
struct FundoPontos: View {
    let resumo: ResumoWidget?
    var data: Date = .now

    var body: some View {
        if let primeiro = resumo?.pontos.first {
            LinearGradient(
                colors: [CorLista.deChave(primeiro.cor).fundo, Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            CenarioMascote(pose: VistaPontos.pose(resumo, data), tema: resumo?.tema ?? .geral)
        }
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
