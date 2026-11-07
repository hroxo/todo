import Foundation

/// Os espaços que a app cria sozinha numa base vazia: Trabalho e Pessoal por defeito, ou os
/// escolhidos no questionário ("Para que vais usar a ToDo?"), com Pessoal sempre. A ordem dos
/// casos é a do Início.
public enum EspacoInicial: String, CaseIterable, Sendable {
    case trabalho, pessoal, estudos, casa, compras

    public static let predefinidos: [EspacoInicial] = [.trabalho, .pessoal]

    public var nome: String {
        switch self {
        case .trabalho: "Trabalho"
        case .pessoal: "Pessoal"
        case .estudos: "Estudos"
        case .casa: "Casa"
        case .compras: "Compras"
        }
    }

    public var cor: CorLista {
        switch self {
        case .trabalho: .azul
        case .pessoal: .roxo
        case .estudos: .indigo
        case .casa: .verde
        case .compras: .turquesa
        }
    }

    public var icone: String {
        switch self {
        case .trabalho: "briefcase.fill"
        case .pessoal: "person.fill"
        case .estudos: "book.fill"
        case .casa: "house.fill"
        case .compras: "cart.fill"
        }
    }

    /// Nas compras nada expira (DESIGN.md 7.15).
    public var tipo: TipoLista { self == .compras ? .compras : .normal }
}
