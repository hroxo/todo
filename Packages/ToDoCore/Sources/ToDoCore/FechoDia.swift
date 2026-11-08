import Foundation
import SwiftData

/// A próxima notificação do Fecho do dia: quando, e quantos pontos chegam ao fim nessa altura.
public struct PlanoFecho: Equatable, Sendable {
    public let data: Date
    public let pontos: Int
}

/// O Fecho do dia (Melhoria 33, DESIGN.md 7.25): à hora escolhida, os pontos que chegam ao fim
/// (no último dia do prazo) decidem-se um a um no ecrã de cartas. Aparece por notificação, na
/// frase do Glassy e no widget "O teu ritmo".
extension Tarefas {
    /// Os pontos principais ativos que expiram nas 24 horas seguintes a `data`, o mais urgente
    /// primeiro. Fora ficam os fixados, os das listas de compras e os que já passaram do prazo.
    public func pontosEmRisco(em data: Date) throws -> [Item] {
        Self.emRisco(try itens(.ativo), em: data)
    }

    /// A mesma regra sobre itens já lidos (as `@Query` dos ecrãs): é ela que decide se aparece
    /// "Rever" e quantos pontos as cartas mostram (Melhoria 35).
    public static func emRisco(_ itens: [Item], em data: Date) -> [Item] {
        itens
            .filter { item in
                guard !item.foiApagado, item.estado == .ativo, !item.fixado, item.apagadoEm == nil,
                      item.lista?.ehCompras != true, let limite = item.expiraEm, limite > data
                else { return false }
                return Prazo(item: item, agora: data)?.ultimoDia == true
            }
            .sorted { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) }
    }

    /// A hora do fecho num dado dia.
    public func horaFecho(em dia: Date) -> Date {
        calendario.date(
            bySettingHour: min(21, max(8, definicoes.horaFechoDia)),
            minute: definicoes.minutoFechoDia,
            second: 0,
            of: dia
        )!
    }

    /// O primeiro fecho, a partir de agora, com pontos em risco. Só um: a app reagenda sempre
    /// que sai, e assim nunca chega um fecho sem nada para decidir.
    public func planoFechoDia() throws -> PlanoFecho? {
        guard definicoes.avisosAtivos, definicoes.fechoDiaAtivo else { return nil }
        let agora = relogio.agora
        guard let ultimo = try candidatosFecho().compactMap(\.expiraEm).max() else { return nil }
        var dia = calendario.startOfDay(for: agora)
        while true {
            let fecho = horaFecho(em: dia)
            if fecho > ultimo { return nil }
            if fecho > agora {
                let pontos = try pontosEmRisco(em: fecho).count
                if pontos > 0 { return PlanoFecho(data: fecho, pontos: pontos) }
            }
            dia = calendario.date(byAdding: .day, value: 1, to: dia)!
        }
    }

    /// Quantos pontos o Glassy pede para fechar agora: zero antes da hora de hoje, com o fecho
    /// (ou os avisos) desligado, ou se já fechaste o dia depois da hora (`feitoEm`): "Deixar ir"
    /// não muda os pontos, e o convite não pode voltar.
    public func fechoPendente(feitoEm: Date? = nil) throws -> Int {
        let agora = relogio.agora
        let hora = horaFecho(em: agora)
        guard definicoes.avisosAtivos, definicoes.fechoDiaAtivo, agora >= hora,
              (feitoEm ?? .distantPast) < hora
        else { return 0 }
        return try pontosEmRisco(em: agora).count
    }

    private func candidatosFecho() throws -> [Item] {
        try itens(.ativo).filter { !$0.fixado && $0.apagadoEm == nil && $0.lista?.ehCompras != true }
    }
}
