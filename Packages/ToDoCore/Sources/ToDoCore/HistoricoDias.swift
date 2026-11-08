import Foundation
import SwiftData

/// Como correu um dia, no widget "O teu ritmo" (Melhoria 33).
public enum EstadoDia: String, Codable, Sendable {
    case verde, vermelho, neutro
}

/// Um dia do histórico. É binário de propósito: concluir 1 ponto ou mil dá o mesmo dia verde,
/// para que despejar e fechar pontos em massa não compre nada.
public struct DiaHistorico: Codable, Equatable, Sendable, Identifiable {
    /// "2026-10-21", sempre no calendário gregoriano e no fuso de quem o registou.
    public var dia: String
    public var concluiu: Bool
    public var expirou: Bool

    public init(dia: String, concluiu: Bool, expirou: Bool) {
        self.dia = dia
        self.concluiu = concluiu
        self.expirou = expirou
    }

    public var id: String { dia }

    /// Num dia com as duas coisas, o verde ganha.
    public var estado: EstadoDia {
        concluiu ? .verde : expirou ? .vermelho : .neutro
    }

    /// A chave já é o dia: lê-se em UTC, ao meio-dia, só para não mudar de data.
    private static let utc: Calendar = {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc
    }()

    /// "Quarta, 21 out".
    private var cabecalho: String? {
        let partes = dia.split(separator: "-").compactMap { Int($0) }
        guard partes.count == 3,
              let data = Self.utc.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2], hour: 12))
        else { return nil }
        return Formatos.cabecalho(data, calendario: Self.utc)
    }

    /// "S", "T", "Q"…, por baixo de cada dia no widget.
    public var letra: String {
        String(cabecalho?.prefix(1) ?? "")
    }

    /// Para o VoiceOver: a cor nunca é o único sinal (DESIGN.md 9).
    public var rotulo: String {
        let estado = switch self.estado {
        case .verde: "concluíste pontos"
        case .vermelho: "expiraram pontos"
        case .neutro: "sem atividade"
        }
        return "\(cabecalho ?? dia): \(estado)"
    }
}

/// Os dias guardados no App Group. Concluídos e Expirados apagam-se ao fim da retenção (e
/// recuperar limpa o `expiradoEm`), por isso os dias passados não se podem tirar só dos pontos:
/// a app junta o que os pontos ainda mostram ao que já estava gravado. Fica fora do SwiftData
/// por ser um dado derivado: cada aparelho tem o seu, e os dias dentro da retenção convergem
/// com os pontos que o iCloud traz.
public struct HistoricoDias: Codable, Equatable, Sendable {
    public static let nomeFicheiro = "historico-dias.json"

    /// Por ordem, o mais antigo primeiro.
    public var dias: [DiaHistorico]

    public init(dias: [DiaHistorico] = []) {
        self.dias = dias.sorted { $0.dia < $1.dia }
    }

    public func dia(_ data: Date, calendario: Calendar) -> DiaHistorico? {
        let chave = Self.chave(data, calendario: calendario)
        return dias.first { $0.dia == chave }
    }

    /// Os `n` dias que acabam em `data`, com os dias sem registo neutros.
    public func ultimos(_ n: Int, ate data: Date, calendario: Calendar) -> [DiaHistorico] {
        let porDia = Dictionary(dias.map { ($0.dia, $0) }, uniquingKeysWith: { a, _ in a })
        return (0..<n).reversed().map { atras in
            let chave = Self.chave(calendario.date(byAdding: .day, value: -atras, to: data)!, calendario: calendario)
            return porDia[chave] ?? DiaHistorico(dia: chave, concluiu: false, expirou: false)
        }
    }

    /// Junta dia a dia: o que um dos lados viu fica.
    public func juntado(com outro: HistoricoDias) -> HistoricoDias {
        var porDia = Dictionary(dias.map { ($0.dia, $0) }, uniquingKeysWith: { a, _ in a })
        for dia in outro.dias {
            let antes = porDia[dia.dia]
            porDia[dia.dia] = DiaHistorico(
                dia: dia.dia,
                concluiu: dia.concluiu || antes?.concluiu == true,
                expirou: dia.expirou || antes?.expirou == true
            )
        }
        return HistoricoDias(dias: Array(porDia.values))
    }

    /// O dia de uma data no calendário gregoriano, com o fuso do calendário dado
    /// (`Calendar.current` pode não ser gregoriano).
    static func chave(_ data: Date, calendario: Calendar) -> String {
        var gregoriano = Calendar(identifier: .gregorian)
        gregoriano.timeZone = calendario.timeZone
        let c = gregoriano.dateComponents([.year, .month, .day], from: data)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    // MARK: - Ficheiro no App Group

    public func gravar(em pasta: URL) throws {
        try JSONEncoder().encode(self).write(to: pasta.appendingPathComponent(Self.nomeFicheiro), options: .atomic)
    }

    /// Junta dias vindos de fora (um backup) aos do ficheiro, sem apagar nenhum.
    public static func juntarAoGuardado(_ outro: HistoricoDias, em pasta: URL) throws {
        try ler(de: pasta).juntado(com: outro).gravar(em: pasta)
    }

    /// Sem ficheiro, ou com um ficheiro ilegível, começa vazio: o histórico não é dado do
    /// utilizador e nunca pode impedir a app de abrir.
    public static func ler(de pasta: URL) -> HistoricoDias {
        guard let dados = try? Data(contentsOf: pasta.appendingPathComponent(nomeFicheiro)),
              let historico = try? JSONDecoder().decode(HistoricoDias.self, from: dados)
        else { return HistoricoDias() }
        return historico
    }
}

extension Tarefas {
    /// O histórico com o que os pontos mostram agora, junto ao `anterior`. Os dias passados só
    /// ganham informação; o de hoje vem só dos pontos, para "Anular" e "Reabrir" o desfazerem.
    /// Contam os pontos principais fora das listas de compras, como em `prioridades()`.
    public func historico(juntandoA anterior: HistoricoDias = HistoricoDias()) throws -> HistoricoDias {
        var concluiu = Set<String>()
        var expirou = Set<String>()
        for item in try contexto.fetch(FetchDescriptor<Item>())
        where !item.ehSubtopico && item.apagadoEm == nil && item.lista?.ehCompras != true {
            if item.estado == .concluido, let data = item.concluidoEm {
                concluiu.insert(HistoricoDias.chave(data, calendario: calendario))
            }
            if item.estado == .expirado, let data = item.expiradoEm {
                expirou.insert(HistoricoDias.chave(data, calendario: calendario))
            }
        }
        let hoje = HistoricoDias.chave(relogio.agora, calendario: calendario)
        let agora = HistoricoDias(dias: concluiu.union(expirou).map {
            DiaHistorico(dia: $0, concluiu: concluiu.contains($0), expirou: expirou.contains($0))
        })
        let passado = HistoricoDias(dias: anterior.dias.filter { $0.dia != hoje })
        return passado.juntado(com: agora)
    }

    /// Lê o ficheiro do App Group, junta o que os pontos mostram e grava. A app chama-o antes de
    /// `avaliar()` (que apaga os concluídos no fim da retenção) e depois (para os que acabaram
    /// de expirar).
    @discardableResult
    public func registarHistorico(em pasta: URL) throws -> HistoricoDias {
        let historico = try historico(juntandoA: HistoricoDias.ler(de: pasta))
        try historico.gravar(em: pasta)
        return historico
    }
}
