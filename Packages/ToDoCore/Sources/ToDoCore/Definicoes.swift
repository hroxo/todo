import Foundation

/// Valores editáveis nas Definições (especificação 9), guardados em UserDefaults.
public struct Definicoes: Codable, Equatable, Sendable {
    /// Os limites dos ecrãs de Avançado. Valem também ao ler: um backup pode vir de qualquer lado.
    public static let intervaloExpiracao = 1...30
    public static let intervaloManterCurto = 1...30
    public static let intervaloManterLongo = 1...90
    public static let intervaloRetencao = 1...60

    public var diasExpiracao = 3
    public var diasManterCurto = 5
    public var diasManterLongo = 15
    public var diasRetencaoExpirados = 14
    public var diasRetencaoConcluidos = 7
    public var horaNotificacao = 9
    public var minutoNotificacao = 0
    public var avisosAtivos = true
    /// Dias sem pontos abertos até uma lista não permanente desaparecer (DESIGN.md 7.17).
    public var diasListaVazia = 5
    /// Textos e sugestões escritos pelo modelo da Apple no iPhone (DESIGN.md 7.16).
    public var inteligenciaAtiva = true

    public init() {}

    /// Campos em falta (gravados por uma versão anterior) ficam com a predefinição e valores fora
    /// dos limites ficam no limite: 0 dias de retenção apagaria os Expirados na abertura seguinte.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Definicoes()
        func dias(_ chave: CodingKeys, _ predefinicao: Int, _ intervalo: ClosedRange<Int>) throws -> Int {
            let valor = try c.decodeIfPresent(Int.self, forKey: chave) ?? predefinicao
            return min(intervalo.upperBound, max(intervalo.lowerBound, valor))
        }
        diasExpiracao = try dias(.diasExpiracao, base.diasExpiracao, Self.intervaloExpiracao)
        diasManterCurto = try dias(.diasManterCurto, base.diasManterCurto, Self.intervaloManterCurto)
        diasManterLongo = try dias(.diasManterLongo, base.diasManterLongo, Self.intervaloManterLongo)
        diasRetencaoExpirados = try dias(.diasRetencaoExpirados, base.diasRetencaoExpirados, Self.intervaloRetencao)
        diasRetencaoConcluidos = try dias(.diasRetencaoConcluidos, base.diasRetencaoConcluidos, Self.intervaloRetencao)
        horaNotificacao = try dias(.horaNotificacao, base.horaNotificacao, 0...23)
        minutoNotificacao = try dias(.minutoNotificacao, base.minutoNotificacao, 0...59)
        avisosAtivos = try c.decodeIfPresent(Bool.self, forKey: .avisosAtivos) ?? base.avisosAtivos
        diasListaVazia = try dias(.diasListaVazia, base.diasListaVazia, Self.intervaloRetencao)
        inteligenciaAtiva = try c.decodeIfPresent(Bool.self, forKey: .inteligenciaAtiva) ?? base.inteligenciaAtiva
    }

    /// As definições depois de restaurar um backup: as dele, mas sem encurtar o que protege os
    /// dados. Um backup com 14 dias de retenção apagaria hoje os Expirados que os teus 30 guardam.
    public func aoRestaurar(_ doBackup: Definicoes) -> Definicoes {
        var novas = doBackup
        novas.diasRetencaoExpirados = max(diasRetencaoExpirados, doBackup.diasRetencaoExpirados)
        novas.diasRetencaoConcluidos = max(diasRetencaoConcluidos, doBackup.diasRetencaoConcluidos)
        novas.diasListaVazia = max(diasListaVazia, doBackup.diasListaVazia)
        return novas
    }

    private static let chave = "definicoes"

    public static func carregar(de defaults: UserDefaults = .standard) -> Definicoes {
        guard let dados = defaults.data(forKey: chave),
              let definicoes = try? JSONDecoder().decode(Definicoes.self, from: dados)
        else { return Definicoes() }
        return definicoes
    }

    public func guardar(em defaults: UserDefaults = .standard) {
        if let dados = try? JSONEncoder().encode(self) {
            defaults.set(dados, forKey: Self.chave)
        }
    }
}
