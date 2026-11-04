import Foundation

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
    /// Dia ganho: feliz com algo concluído, para celebrar.
    public let celebrar: Bool

    /// `concluidos` e `expirados` contam só os da `janela`.
    public init(porFazer: Int, concluidos: Int, expirados: Int, totalAtivos: Int) {
        let falhou = expirados > 0 && concluidos == 0 && totalAtivos == 0
        let pressao = min(1, Double(max(0, porFazer)) / Double(Self.capacidade))
        if falhou {
            humor = .ko
            nivelAreia = 1
            celebrar = false
        } else if porFazer <= 0 {
            humor = .feliz
            nivelAreia = 0
            celebrar = concluidos > 0
        } else {
            humor = pressao >= Self.limitePreocupado ? .preocupado : .calmo
            nivelAreia = pressao
            celebrar = false
        }
    }
}

extension Tarefas {
    /// O estado do Glassy agora, a partir dos pontos ativos e do que aconteceu na última janela.
    public func estadoGlassy() throws -> EstadoGlassy {
        let agora = relogio.agora
        let desde = agora.addingTimeInterval(-EstadoGlassy.janela)
        let principais: (Item) -> Bool = { !$0.ehSubtopico && $0.apagadoEm == nil && $0.lista?.ehCompras != true }
        let ativos = try itens(.ativo).filter(principais)
        let concluidos = try itens(.concluido).filter(principais).filter { ($0.concluidoEm ?? .distantPast) >= desde }.count
        let expirados = try itens(.expirado).filter(principais).filter { ($0.expiradoEm ?? .distantPast) >= desde }.count
        let porFazer = ativos.filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }.count
        return EstadoGlassy(porFazer: porFazer, concluidos: concluidos, expirados: expirados, totalAtivos: ativos.count)
    }
}
