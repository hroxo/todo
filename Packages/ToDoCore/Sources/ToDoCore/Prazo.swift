import Foundation

/// Tempo que falta a um item ativo para expirar, para o anel e os textos (DESIGN.md 7.3).
public struct Prazo: Equatable, Sendable {
    private static let dia: TimeInterval = 24 * 60 * 60

    /// Segundos até expirar (nunca negativo).
    public let restante: TimeInterval
    /// Duração atual do prazo: da última ação até à expiração (3 dias, ou mais depois de Manter).
    public let duracao: TimeInterval

    /// Nil para itens fixados, concluídos, expirados ou sem prazo.
    public init?(item: Item, agora: Date) {
        guard item.estado == .ativo, !item.fixado, let limite = item.expiraEm else { return nil }
        restante = max(0, limite.timeIntervalSince(agora))
        duracao = max(1, limite.timeIntervalSince(item.ultimaAcaoEm))
    }

    /// Parte do anel ainda cheia, de 0 a 1.
    public var fracao: Double { min(1, max(0, restante / duracao)) }

    /// Menos de 24 horas: o anel fica laranja e o texto passa a "Hoje".
    public var ultimoDia: Bool { restante < Self.dia }

    /// Dias que faltam, arredondados para cima. A hora de folga evita contar um dia a mais
    /// quando o prazo atravessa a mudança da hora de inverno.
    public var dias: Int { max(1, Int(((restante - 3600) / Self.dia).rounded(.up))) }

    /// "3 d", "2 d" ou "Hoje".
    public var rotuloCurto: String { ultimoDia ? "Hoje" : "\(dias) d" }

    /// "Expira em 2 dias", "Expira em 1 dia" ou "Expira hoje".
    public var rotuloLongo: String {
        if ultimoDia { return "Expira hoje" }
        return dias == 1 ? "Expira em 1 dia" : "Expira em \(dias) dias"
    }
}
