import Foundation

/// O céu do fundo da app: de dia no modo claro e de noite no modo escuro, a qualquer hora.
public struct CeuDoDia: Equatable, Sendable {
    public enum Fase: String, Equatable, Sendable {
        case dia, noite
    }

    public let fase: Fase
    /// A saudação segue o relógio, não o céu: às 9h é "Bom dia!" também no modo escuro.
    public let saudacao: String

    public init(agora: Date, escuro: Bool = false, calendario: Calendar = .current) {
        fase = escuro ? .noite : .dia
        let hora = calendario.component(.hour, from: agora)
        saudacao = switch hora {
        case 6..<12: "Bom dia!"
        case 12..<20: "Boa tarde!"
        default: "Boa noite!"
        }
    }
}
