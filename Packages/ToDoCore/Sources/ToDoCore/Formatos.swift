import Foundation

/// Textos de datas em português europeu, com relógio de 24 horas (especificação 11).
public enum Formatos {
    private static let diasSemana = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    private static let meses = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

    /// "Quarta, 21 out", para o topo do Início. Sempre gregoriano, só com o fuso do calendário
    /// dado: com o calendário hebraico dos Ajustes há um mês 13, e os nomes acabam no 12.
    public static func cabecalho(_ data: Date, calendario: Calendar = .current) -> String {
        var gregoriano = Calendar(identifier: .gregorian)
        gregoriano.timeZone = calendario.timeZone
        let c = gregoriano.dateComponents([.weekday, .day, .month], from: data)
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

    /// "1 dia" ou "5 dias".
    public static func dias(_ n: Int) -> String {
        n == 1 ? "1 dia" : "\(n) dias"
    }

    /// "14:30".
    public static func hora(_ data: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.hour, .minute], from: data)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    /// "14:30–15:30".
    public static func intervalo(_ inicio: Date, _ fim: Date, calendario: Calendar = .current) -> String {
        hora(inicio, calendario: calendario) + "–" + hora(fim, calendario: calendario)
    }

    /// O nome de uma lista pronto para nome de ficheiro: sem os caracteres que os sistemas de
    /// ficheiros não aceitam ("Casa/Férias" seria uma pasta). Vazio fica "lista".
    public static func nomeFicheiro(_ nome: String) -> String {
        let proibidos = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let limpo = nome.components(separatedBy: proibidos).joined(separator: "-").trimmingCharacters(in: .whitespaces)
        return limpo.isEmpty ? "lista" : limpo
    }

    /// "ontem, 18:40".
    public static func momento(_ data: Date, agora: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.hour, .minute], from: data)
        return dia(data, agora: agora, calendario: calendario) + String(format: ", %02d:%02d", c.hour!, c.minute!)
    }
}
