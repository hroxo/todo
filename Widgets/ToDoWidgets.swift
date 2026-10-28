import SwiftUI
import ToDoCore
import WidgetKit

@main
struct ToDoWidgets: WidgetBundle {
    var body: some Widget {
        WidgetPontos()
        WidgetNovaNota()
        ControloNovaNota()
    }
}

/// Uma entrada da timeline: o resumo gravado pela app e a hora a que se mostra (o anel de
/// cada ponto é calculado para essa hora, e o WidgetKit anima a passagem entre entradas).
struct EntradaResumo: TimelineEntry {
    let date: Date
    let resumo: ResumoWidget?
}

struct FornecedorResumo: TimelineProvider {
    func placeholder(in context: Context) -> EntradaResumo {
        EntradaResumo(date: .now, resumo: .exemplo())
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaResumo) -> Void) {
        let resumo = context.isPreview ? .exemplo() : lerResumo()
        completion(EntradaResumo(date: .now, resumo: resumo ?? .exemplo()))
    }

    /// Uma entrada de 20 em 20 minutos durante 6 horas, alinhadas aos blocos da Ampulheta:
    /// os anéis vão esvaziando e, sem pontos, a mascote muda de pose. A app pede um
    /// recarregamento sempre que os pontos mudam.
    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaResumo>) -> Void) {
        let resumo = lerResumo()
        let agora = Date.now
        let bloco: TimeInterval = 20 * 60
        let proximo = (agora.timeIntervalSinceReferenceDate / bloco).rounded(.up) * bloco
        let entradas = [EntradaResumo(date: agora, resumo: resumo)] + (0..<18).map { i in
            EntradaResumo(date: Date(timeIntervalSinceReferenceDate: proximo + Double(i) * bloco), resumo: resumo)
        }
        completion(Timeline(entries: entradas, policy: .after(agora.addingTimeInterval(6 * 3600))))
    }

    private func lerResumo() -> ResumoWidget? {
        BaseDados.pastaPartilhada.flatMap(ResumoWidget.ler(de:))
    }
}

/// O médio "o que importa agora" (DESIGN.md 7.14).
struct WidgetPontos: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.hugo.todo.pontos", provider: FornecedorResumo()) { entrada in
            VistaPontos(resumo: entrada.resumo, data: entrada.date)
                .containerBackground(for: .widget) { FundoPontos(resumo: entrada.resumo, data: entrada.date) }
        }
        .configurationDisplayName("O que importa agora")
        .description("Os pontos que precisam de ti, com o anel do prazo. Toca no círculo para concluir.")
        .supportedFamilies([.systemMedium])
    }
}

/// O "+" do ecrã bloqueado (DESIGN.md 7.14).
struct WidgetNovaNota: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.hugo.todo.nova-nota", provider: FornecedorResumo()) { entrada in
            VistaNovaNota(resumo: entrada.resumo)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Nova nota")
        .description("Um toque para escrever um ponto novo.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct VistaNovaNota: View {
    let resumo: ResumoWidget?
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        if familia == .accessoryRectangular {
            VistaMaisRetangular(resumo: resumo)
        } else {
            VistaMaisCircular()
        }
    }
}

/// O controlo Nova nota: para os botões do ecrã bloqueado, o Centro de Controlo e o
/// Action Button.
struct ControloNovaNota: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hugo.todo.controlo.nova-nota") {
            ControlWidgetButton(action: AbrirCapturaIntent()) {
                Label("Nova nota", systemImage: "square.and.pencil")
            }
        }
        .displayName("Nova nota")
        .description("Abre a ToDo para escrever um ponto novo.")
    }
}
