import Foundation

/// O dia contado pela Ampulheta no Início (DESIGN.md 7.22): os pontos concluídos hoje e os que
/// ainda estão no último dia do prazo. A areia desce com os concluídos.
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

    /// Parte do dia feita, de 0 a 1. Sem pontos para hoje, a areia fica toda em cima.
    public var fracao: Double {
        let total = concluidos + porFazer
        return total == 0 ? 0 : Double(concluidos) / Double(total)
    }

    /// O dia só está ganho depois de concluir alguma coisa: um dia sem pontos não dá festa.
    public var completo: Bool { concluidos > 0 && porFazer == 0 }

    /// O que a Ampulheta diz quando não há nada mais importante.
    public func frase(hora: Int) -> String {
        if completo { return "Dia ganho! Bom trabalho." }
        let saudacao = hora < 12 ? "Bom dia!" : (hora < 20 ? "Boa tarde!" : "Boa noite!")
        switch (concluidos, porFazer) {
        case (_, 0): return "\(saudacao) Nada urgente hoje."
        case (0, 1): return "\(saudacao) Hoje é 1 ponto."
        case (0, let n): return "\(saudacao) Hoje são \(n) pontos."
        case (_, 1): return "Boa! Só falta 1 ponto hoje."
        case (_, let n): return "Boa! Faltam \(n) pontos hoje."
        }
    }
}
