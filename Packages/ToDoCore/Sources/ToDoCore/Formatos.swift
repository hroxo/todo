import Foundation

/// Textos de datas em português europeu, com relógio de 24 horas (especificação 11).
public enum Formatos {
    private static let diasSemana = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    private static let meses = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

    /// "Quarta, 21 out", para o topo do Início.
    public static func cabecalho(_ data: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.weekday, .day, .month], from: data)
        return "\(diasSemana[c.weekday! - 1]), \(c.day!) \(meses[c.month! - 1])"
    }

    /// "hoje", "ontem" ou "19/10".
    public static func dia(_ data: Date, agora: Date, calendario: Calendar = .current) -> String {
        if calendario.isDate(data, inSameDayAs: agora) { return "hoje" }
        if let ontem = calendario.date(byAdding: .day, value: -1, to: agora),
           calendario.isDate(data, inSameDayAs: ontem) { return "ontem" }
        let c = calendario.dateComponents([.day, .month], from: data)
        return String(format: "%02d/%02d", c.day!, c.month!)
    }

    /// "ontem, 18:40".
    public static func momento(_ data: Date, agora: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.hour, .minute], from: data)
        return dia(data, agora: agora, calendario: calendario) + String(format: ", %02d:%02d", c.hour!, c.minute!)
    }
}
