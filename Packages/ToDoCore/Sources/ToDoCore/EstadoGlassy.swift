import Foundation
import SwiftData

/// Como está o Glassy (a mascote) em função do dia. A areia é a pressão do tempo: toda em cima
/// quando não há nada a fechar, a descer à medida que se acumulam pontos no último dia, toda
/// em baixo quando o dia correu mal.
public struct EstadoGlassy: Codable, Equatable, Sendable {
    public enum Humor: String, Codable, Sendable {
        /// Nada por fechar: feliz, areia em cima.
        case feliz
        /// Há pontos a fechar, mas poucos.
        case calmo
        /// Muitos por fechar: a areia desce e ele fica preocupado.
        case preocupado
        /// Falhou tudo: expirou tudo e nada foi concluído.
        case ko
    }

    /// Pontos no último dia que enchem a areia por completo.
    public static let capacidade = 6
    /// A partir de que parte da areia em baixo ele fica preocupado.
    public static let limitePreocupado = 0.5
    /// Quanto tempo conta o que aconteceu. Uma janela e não "hoje": um ponto expirado às 23h
    /// não pode deixá-lo feliz à meia-noite, e `expiradoEm` guarda o limite, não a hora a que a
    /// app reparou.
    public static let janela: TimeInterval = 24 * 60 * 60

    public let humor: Humor
    /// 0 = areia toda em cima, 1 = toda em baixo.
    public let nivelAreia: Double

    /// `concluidos` e `expirados` contam só os da `janela`.
    public init(porFazer: Int, concluidos: Int, expirados: Int, totalAtivos: Int) {
        let falhou = expirados > 0 && concluidos == 0 && totalAtivos == 0
        let pressao = min(1, Double(max(0, porFazer)) / Double(Self.capacidade))
        if falhou {
            humor = .ko
            nivelAreia = 1
        } else if porFazer <= 0 {
            humor = .feliz
            nivelAreia = 0
        } else {
            humor = pressao >= Self.limitePreocupado ? .preocupado : .calmo
            nivelAreia = pressao
        }
    }
}

/// As datas de que o estado do Glassy depende. Com elas, o widget sabe o estado a qualquer hora
/// sem abrir a base de dados: um ponto cujo prazo passou conta como expirado, mesmo que a app não
/// abra há dias (ela é que os marca, em `avaliar`).
public struct DatasGlassy: Codable, Equatable, Sendable {
    /// O limite de cada ponto ativo com prazo.
    public var prazos: [Date]
    /// Pontos ativos que não expiram (fixados).
    public var semPrazo: Int
    public var concluidosEm: [Date]
    public var expiradosEm: [Date]

    public func totalAtivos(em data: Date) -> Int {
        semPrazo + prazos.filter { $0 > data }.count
    }

    /// Pontos com menos de 24 horas, como `Prazo.ultimoDia`.
    public func ultimoDia(em data: Date) -> Int {
        prazos.filter { $0 > data && $0.timeIntervalSince(data) < 24 * 60 * 60 }.count
    }

    public func estado(em data: Date) -> EstadoGlassy {
        let desde = data.addingTimeInterval(-EstadoGlassy.janela)
        let passaram = prazos.filter { $0 <= data }
        return EstadoGlassy(
            porFazer: ultimoDia(em: data),
            concluidos: concluidosEm.filter { $0 >= desde }.count,
            expirados: (expiradosEm + passaram).filter { $0 >= desde }.count,
            totalAtivos: totalAtivos(em: data)
        )
    }
}

extension Tarefas {
    /// As datas de agora, sem as listas de compras, onde nada expira.
    public func datasGlassy() throws -> DatasGlassy {
        let desde = relogio.agora.addingTimeInterval(-EstadoGlassy.janela)
        let itens = try contexto.fetch(FetchDescriptor<Item>())
            .filter { !$0.ehSubtopico && $0.apagadoEm == nil && $0.lista?.ehCompras != true }
        let ativos = itens.filter { $0.estado == .ativo }
        let prazos = ativos.filter { !$0.fixado }.compactMap(\.expiraEm)
        return DatasGlassy(
            prazos: prazos,
            semPrazo: ativos.count - prazos.count,
            concluidosEm: itens.filter { $0.estado == .concluido }.compactMap(\.concluidoEm).filter { $0 >= desde },
            expiradosEm: itens.filter { $0.estado == .expirado }.compactMap(\.expiradoEm).filter { $0 >= desde }
        )
    }

    /// O estado do Glassy agora, a partir dos pontos ativos e do que aconteceu na última janela.
    public func estadoGlassy() throws -> EstadoGlassy {
        try datasGlassy().estado(em: relogio.agora)
    }
}
