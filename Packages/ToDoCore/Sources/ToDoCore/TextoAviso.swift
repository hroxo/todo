import Foundation

/// Texto das notificações (DESIGN.md 7.16): uma linha curta com quando expira e o que dá
/// contexto ("Expira amanhã às 18:30 · 2 subtópicos por fazer"). É o texto de base, usado
/// sempre que o modelo do iPhone não está disponível, e o ponto de partida para ele.
public enum TextoAviso {
    public static func corpo(_ aviso: Aviso, calendario: Calendar = .current) -> String {
        var partes = [quando(aviso, calendario: calendario)]
        if aviso.subtopicosPorFazer > 0 {
            partes.append(aviso.subtopicosPorFazer == 1 ? "1 subtópico por fazer" : "\(aviso.subtopicosPorFazer) subtópicos por fazer")
        } else if let parado = diasParado(aviso, calendario: calendario), parado >= 2 {
            partes.append("sem mexer há \(parado) dias")
        }
        return partes.joined(separator: " · ")
    }

    /// "Expira amanhã às 18:30", contado a partir da hora a que o aviso aparece.
    public static func quando(_ aviso: Aviso, calendario: Calendar = .current) -> String {
        quando(expiraEm: aviso.expiraEm, agora: aviso.data, calendario: calendario)
    }

    /// O mesmo para qualquer prazo (também no Fecho do dia).
    public static func quando(expiraEm limite: Date, agora: Date, calendario: Calendar = .current) -> String {
        let hora = Formatos.hora(limite, calendario: calendario)
        let dia = calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: agora),
            to: calendario.startOfDay(for: limite)
        ).day ?? 0
        switch dia {
        case ...0: return "Expira hoje às \(hora)"
        case 1: return "Expira amanhã às \(hora)"
        default: return "Expira \(Formatos.dia(limite, agora: agora, calendario: calendario)) às \(hora)"
        }
    }

    /// "«Ideias» vai desaparecer" (DESIGN.md 7.17).
    public static func tituloLista(_ aviso: AvisoLista) -> String {
        "«\(aviso.nome)» vai desaparecer"
    }

    /// "Sem pontos abertos há 4 dias. Sai amanhã às 09:00, a não ser que a mantenhas."
    public static func corpoLista(_ aviso: AvisoLista, calendario: Calendar = .current) -> String {
        let dias = calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: aviso.vaziaDesde),
            to: calendario.startOfDay(for: aviso.data)
        ).day ?? 0
        let ha = dias <= 0 ? "desde hoje" : (dias == 1 ? "há 1 dia" : "há \(dias) dias")
        let hora = Formatos.hora(aviso.desapareceEm, calendario: calendario)
        let mesmoDia = calendario.isDate(aviso.desapareceEm, inSameDayAs: aviso.data)
        return "Sem pontos abertos \(ha). Sai \(mesmoDia ? "hoje" : "amanhã") às \(hora), a não ser que a mantenhas."
    }

    /// Dias entre a última ação e a hora do aviso.
    public static func diasParado(_ aviso: Aviso, calendario: Calendar = .current) -> Int? {
        calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: aviso.ultimaAcaoEm),
            to: calendario.startOfDay(for: aviso.data)
        ).day
    }
}
