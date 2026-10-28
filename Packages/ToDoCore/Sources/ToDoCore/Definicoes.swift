import Foundation

/// Valores editáveis nas Definições (especificação 9), guardados em UserDefaults.
public struct Definicoes: Codable, Equatable, Sendable {
    public var diasExpiracao = 3
    public var diasManterCurto = 5
    public var diasManterLongo = 15
    public var diasRetencaoExpirados = 14
    public var diasRetencaoConcluidos = 7
    public var horaNotificacao = 9
    public var minutoNotificacao = 0
    public var avisosAtivos = true
    /// Textos e sugestões escritos pelo modelo da Apple no iPhone (DESIGN.md 7.16).
    public var inteligenciaAtiva = true

    public init() {}

    /// Campos em falta (gravados por uma versão anterior) ficam com a predefinição.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Definicoes()
        diasExpiracao = try c.decodeIfPresent(Int.self, forKey: .diasExpiracao) ?? base.diasExpiracao
        diasManterCurto = try c.decodeIfPresent(Int.self, forKey: .diasManterCurto) ?? base.diasManterCurto
        diasManterLongo = try c.decodeIfPresent(Int.self, forKey: .diasManterLongo) ?? base.diasManterLongo
        diasRetencaoExpirados = try c.decodeIfPresent(Int.self, forKey: .diasRetencaoExpirados) ?? base.diasRetencaoExpirados
        diasRetencaoConcluidos = try c.decodeIfPresent(Int.self, forKey: .diasRetencaoConcluidos) ?? base.diasRetencaoConcluidos
        horaNotificacao = try c.decodeIfPresent(Int.self, forKey: .horaNotificacao) ?? base.horaNotificacao
        minutoNotificacao = try c.decodeIfPresent(Int.self, forKey: .minutoNotificacao) ?? base.minutoNotificacao
        avisosAtivos = try c.decodeIfPresent(Bool.self, forKey: .avisosAtivos) ?? base.avisosAtivos
        inteligenciaAtiva = try c.decodeIfPresent(Bool.self, forKey: .inteligenciaAtiva) ?? base.inteligenciaAtiva
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
