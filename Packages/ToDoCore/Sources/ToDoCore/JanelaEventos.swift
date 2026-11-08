import Foundation

/// Os eventos de um dia da janela.
public struct GrupoDeEventos<Evento> {
    /// Início do dia.
    public let dia: Date
    /// "Hoje", "Amanhã" ou o dia da semana.
    public let titulo: String
    public let eventos: [Evento]
}

/// Os próximos eventos do calendário: hoje e os dias seguintes (3 por defeito, nas Definições). Fica no núcleo para
/// a janela, o agrupamento e os nomes dos dias serem testados e iguais em qualquer fonte.
public enum JanelaEventos {
    /// Dias lidos por defeito, contando com hoje.
    public static let dias = Definicoes().diasCalendario

    private static let diasDaSemana = [
        "Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado",
    ]

    /// Do início de hoje ao fim do último dia (exclusivo).
    public static func intervalo(agora: Date, dias: Int = dias, calendario: Calendar = .current) -> (inicio: Date, fim: Date) {
        let inicio = calendario.startOfDay(for: agora)
        return (inicio, calendario.date(byAdding: .day, value: dias, to: inicio)!)
    }

    /// Um grupo por dia, sempre todos, mesmo vazios. Os eventos ordenam-se pela hora; o que
    /// começou antes de hoje (vários dias) conta em hoje; o que começa depois da janela sai.
    public static func agrupar<Evento>(
        _ eventos: [Evento],
        agora: Date,
        dias: Int = dias,
        calendario: Calendar = .current,
        inicio: (Evento) -> Date
    ) -> [GrupoDeEventos<Evento>] {
        let janela = intervalo(agora: agora, dias: dias, calendario: calendario)
        let ordenados = eventos.sorted { inicio($0) < inicio($1) }
        return (0..<dias).map { n in
            let dia = calendario.date(byAdding: .day, value: n, to: janela.inicio)!
            let seguinte = calendario.date(byAdding: .day, value: 1, to: dia)!
            let doDia = ordenados.filter {
                let i = inicio($0)
                return i < seguinte && (i >= dia || n == 0)
            }
            return GrupoDeEventos(dia: dia, titulo: titulo(n, dia: dia, calendario: calendario), eventos: doDia)
        }
    }

    private static func titulo(_ n: Int, dia: Date, calendario: Calendar) -> String {
        switch n {
        case 0: "Hoje"
        case 1: "Amanhã"
        // O número do dia da semana é sempre 1 = domingo, seja qual for o calendário.
        default: diasDaSemana[calendario.component(.weekday, from: dia) - 1]
        }
    }
}
