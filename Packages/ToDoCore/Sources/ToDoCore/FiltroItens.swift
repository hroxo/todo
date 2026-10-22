import Foundation

/// Intervalo de datas dos filtros de Concluídos e Expirados (Melhoria 3). Conta por dias de
/// calendário no fuso do dispositivo: "Hoje" começa à meia-noite; "Últimos 7 dias" é hoje e
/// os 6 dias antes.
public enum PeriodoFiltro: String, CaseIterable, Sendable {
    case hoje, ultimos7, ultimos30, tudo

    public var nome: String {
        switch self {
        case .hoje: "Hoje"
        case .ultimos7: "Últimos 7 dias"
        case .ultimos30: "Últimos 30 dias"
        case .tudo: "Tudo"
        }
    }

    /// Dias de calendário incluídos, contando com hoje. Nil para "Tudo".
    var dias: Int? {
        switch self {
        case .hoje: 1
        case .ultimos7: 7
        case .ultimos30: 30
        case .tudo: nil
        }
    }
}

/// Filtro por lista e por data dos ecrãs Concluídos e Expirados (Melhoria 3). A data é a de
/// conclusão nos concluídos e a de expiração nos expirados.
public struct FiltroItens: Equatable, Sendable {
    /// Nil: todas as listas.
    public var listaId: UUID?
    public var periodo: PeriodoFiltro

    public init(listaId: UUID? = nil, periodo: PeriodoFiltro = .tudo) {
        self.listaId = listaId
        self.periodo = periodo
    }

    public var ativo: Bool { listaId != nil || periodo != .tudo }

    /// Primeiro instante incluído pelo período, ou nil para "Tudo".
    public func inicio(agora: Date, calendario: Calendar) -> Date? {
        guard let dias = periodo.dias else { return nil }
        let hoje = calendario.startOfDay(for: agora)
        return calendario.date(byAdding: .day, value: -(dias - 1), to: hoje)
    }

    public func inclui(listaId: UUID?, data: Date?, agora: Date, calendario: Calendar) -> Bool {
        if let filtro = self.listaId, filtro != listaId { return false }
        guard let inicio = inicio(agora: agora, calendario: calendario) else { return true }
        guard let data else { return false }
        return data >= inicio
    }

    /// Os itens que passam no filtro, pela mesma ordem.
    public func aplicar(_ itens: [Item], agora: Date, calendario: Calendar = .current) -> [Item] {
        guard ativo else { return itens }
        return itens.filter { item in
            let data = item.estado == .expirado ? item.expiradoEm : item.concluidoEm
            return inclui(listaId: item.listaEfetiva?.id, data: data, agora: agora, calendario: calendario)
        }
    }

    /// Texto da ficha por baixo do título: "Trabalho · Últimos 7 dias".
    public func rotulo(nomeLista: String?) -> String {
        var partes: [String] = []
        if listaId != nil, let nomeLista {
            partes.append(nomeLista)
        }
        if periodo != .tudo {
            partes.append(periodo.nome)
        }
        return partes.joined(separator: " · ")
    }
}
