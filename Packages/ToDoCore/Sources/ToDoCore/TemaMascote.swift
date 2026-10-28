import Foundation

/// O tema da Ampulheta no widget (DESIGN.md 7.14): reflete onde a pessoa tem andado a mexer.
public enum TemaMascote: String, Codable, CaseIterable, Sendable {
    case geral, trabalho, pessoal, viagem, desporto

    /// Dias de atividade que contam para o tema.
    public static let dias = 7
}

extension Lista {
    /// O tema de uma lista, pelo ícone, pelo emoji ou pelo nome. Nil quando não se percebe.
    public var tema: TemaMascote? {
        let nome = self.nome.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_PT"))
        func tem(_ palavras: [String]) -> Bool { palavras.contains { nome.contains($0) } }
        let simbolo = emoji ?? icone

        if ["airplane", "✈️"].contains(simbolo) || tem(["viagem", "ferias", "viajar"]) { return .viagem }
        if ["briefcase.fill", "💼"].contains(simbolo) || tem(["trabalho", "emprego", "escritorio"]) { return .trabalho }
        if ["dumbbell.fill", "🏋️"].contains(simbolo) || tem(["ginasio", "treino", "desporto", "corrida"]) { return .desporto }
        if ["person.fill", "house.fill", "book.fill", "heart.fill", "leaf.fill", "🏠", "📚", "❤️", "🌱", "🐶", "🍳"].contains(simbolo)
            || tem(["pessoal", "casa", "leitura", "familia"]) {
            return .pessoal
        }
        return nil
    }
}

extension Tarefas {
    /// O tema da Ampulheta: o das listas onde houve mais atividade nos últimos 7 dias (criar,
    /// mexer, concluir, incluindo subtópicos). Uma viagem com pontos abertos ganha sempre.
    /// Sem atividade nem viagem, `geral`.
    public func temaMascote() throws -> TemaMascote {
        let listas = try self.listas()
        if listas.contains(where: { $0.tema == .viagem && $0.temPontosAbertos }) {
            return .viagem
        }
        let desde = calendario.date(byAdding: .day, value: -TemaMascote.dias, to: relogio.agora)!
        var atividade: [TemaMascote: Int] = [:]
        for lista in listas {
            guard let tema = lista.tema else { continue }
            let itens = lista.itens + lista.itens.flatMap(\.subtopicos)
            let recentes = itens.filter { item in
                item.apagadoEm == nil
                    && [item.criadoEm, item.ultimaAcaoEm, item.concluidoEm, item.alteradoEm]
                        .contains { ($0 ?? .distantPast) >= desde }
            }
            atividade[tema, default: 0] += recentes.count
        }
        // Em caso de empate, ganha o primeiro na ordem dos casos (trabalho antes de pessoal).
        var melhor: (tema: TemaMascote, atividade: Int)?
        for tema in TemaMascote.allCases {
            if let n = atividade[tema], n > (melhor?.atividade ?? 0) {
                melhor = (tema, n)
            }
        }
        return melhor?.tema ?? .geral
    }
}
