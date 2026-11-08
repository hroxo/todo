import Foundation

/// Um dia no mês do Streak (Melhoria 35). Os dias por vir ficam à
/// parte dos neutros: ainda não aconteceram, não são dias sem nada.
public struct DiaRitmo: Equatable, Sendable, Identifiable {
    public let dia: DiaHistorico
    /// O dia do mês, para a grelha.
    public let numero: Int
    public let hoje: Bool
    public let futuro: Bool

    public var id: String { dia.dia }

    /// Para o VoiceOver: "Sexta, 23 out: por vir" nos dias que ainda não chegaram.
    public var rotulo: String {
        let texto = futuro ? "\(dia.cabecalho ?? dia.dia): por vir" : dia.rotulo
        return hoje ? "Hoje, " + texto : texto
    }
}

/// Um mês do histórico, pronto a desenhar de segunda a domingo.
public struct MesRitmo: Equatable, Sendable {
    /// "Novembro de 2026".
    public let titulo: String
    /// Casas vazias antes do dia 1, para ele cair no dia da semana certo.
    public let vazios: Int
    public let dias: [DiaRitmo]
    public let verdes: Int
    /// Um dia do mês anterior, ou nil antes do primeiro registo.
    public let anterior: Date?
    /// Um dia do mês seguinte, ou nil no mês atual: não se vê o futuro.
    public let seguinte: Date?
}

extension HistoricoDias {
    private static let nomesMeses = [
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
    ]

    /// Sempre gregoriano e a começar na segunda, seja qual for o calendário dos Ajustes.
    private static func gregoriano(_ calendario: Calendar) -> Calendar {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = calendario.timeZone
        g.firstWeekday = 2
        return g
    }

    /// O mês de `data`, com a navegação limitada entre o primeiro registo e o mês de `agora`.
    public func mes(de data: Date, agora: Date, calendario: Calendar) -> MesRitmo {
        let g = Self.gregoriano(calendario)
        let primeiro = g.dateInterval(of: .month, for: data)!.start
        let n = g.range(of: .day, in: .month, for: primeiro)!.count
        let dias = (0..<n).map { ritmo(g.date(byAdding: .day, value: $0, to: primeiro)!, agora: agora, calendario: g) }
        // Segunda = 0 … domingo = 6.
        let vazios = (g.component(.weekday, from: primeiro) + 5) % 7
        let c = g.dateComponents([.year, .month], from: primeiro)

        let chaveMes = String(Self.chave(primeiro, calendario: g).prefix(7))
        let primeiroRegisto = self.dias.first.map { String($0.dia.prefix(7)) }
        let mesAgora = String(Self.chave(agora, calendario: g).prefix(7))
        let anterior = primeiroRegisto.map { $0 < chaveMes } == true
            ? g.date(byAdding: .month, value: -1, to: primeiro) : nil
        let seguinte = chaveMes < mesAgora ? g.date(byAdding: .month, value: 1, to: primeiro) : nil

        return MesRitmo(
            titulo: "\(Self.nomesMeses[c.month! - 1]) de \(c.year!)",
            vazios: vazios,
            dias: dias,
            verdes: dias.filter { $0.dia.estado == .verde }.count,
            anterior: anterior,
            seguinte: seguinte
        )
    }

    private func ritmo(_ data: Date, agora: Date, calendario g: Calendar) -> DiaRitmo {
        let chave = Self.chave(data, calendario: g)
        let hoje = Self.chave(agora, calendario: g)
        return DiaRitmo(
            dia: dia(data, calendario: g) ?? DiaHistorico(dia: chave, concluiu: false, expirou: false),
            numero: g.component(.day, from: data),
            hoje: chave == hoje,
            futuro: chave > hoje
        )
    }
}
