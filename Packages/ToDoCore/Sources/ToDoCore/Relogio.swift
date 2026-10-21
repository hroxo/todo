import Foundation

/// Fonte da hora atual. Nos testes usa-se um relógio fixo para controlar as datas.
public protocol Relogio {
    var agora: Date { get }
}

public struct RelogioSistema: Relogio {
    public init() {}
    public var agora: Date { Date() }
}
