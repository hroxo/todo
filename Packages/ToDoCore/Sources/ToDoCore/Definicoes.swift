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

    public init() {}

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
