import Foundation

/// O dia contado pelo Glassy no Início (DESIGN.md 7.22): os pontos concluídos hoje e os que
/// ainda estão no último dia do prazo. A areia vem de `EstadoGlassy`.
public struct ProgressoDia: Equatable, Sendable {
    public let concluidos: Int
    public let porFazer: Int

    public init(concluidos: Int, porFazer: Int) {
        self.concluidos = concluidos
        self.porFazer = porFazer
    }

    public init(ativos: [Item], concluidos: [Item], agora: Date, calendario: Calendar = .current) {
        self.concluidos = concluidos.filter { item in
            item.concluidoEm.map { calendario.isDate($0, inSameDayAs: agora) } ?? false
        }.count
        porFazer = ativos.filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }.count
    }

    /// O dia só está ganho depois de concluir alguma coisa: um dia sem pontos não dá festa.
    public var completo: Bool { concluidos > 0 && porFazer == 0 }

    /// O que a Ampulheta diz quando não há nada mais importante. Depois da hora do Fecho do dia,
    /// com pontos a chegar ao fim (`Tarefas.fechoPendente`), convida a fechar o dia.
    public func frase(saudacao: String, fechoPendente: Int = 0) -> String {
        if fechoPendente > 0 { return Self.fraseFecho(fechoPendente) }
        if completo { return "Dia ganho! Bom trabalho." }
        switch (concluidos, porFazer) {
        case (_, 0): return "\(saudacao) Nada urgente hoje."
        case (0, 1): return "\(saudacao) Hoje é 1 ponto."
        case (0, let n): return "\(saudacao) Hoje são \(n) pontos."
        case (_, 1): return "Boa! Só falta 1 ponto hoje."
        case (_, let n): return "Boa! Faltam \(n) pontos hoje."
        }
    }

    /// O convite do Fecho do dia: no Glassy, na notificação e no widget.
    public static func fraseFecho(_ pontos: Int) -> String {
        pontos == 1 ? "Fechas o dia? 1 ponto chega ao fim." : "Fechas o dia? \(pontos) pontos chegam ao fim."
    }
}
