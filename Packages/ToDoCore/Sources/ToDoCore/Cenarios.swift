import Foundation

/// Os cenários do fundo do Início (Melhoria 35, mock "O mundo do Glassy" em
/// `design/mocks/html/Engagement.html`). O identificador fica gravado na base: nunca mudar o
/// `rawValue` de um que já exista.
public enum CenarioId: String, CaseIterable, Codable, Sendable {
    case ceu, parque, praia, biblioteca, viagem, montanha
}

/// Um cenário e quantos grãos custa. O catálogo é o único sítio com os preços.
public struct Cenario: Equatable, Sendable, Identifiable {
    public let id: CenarioId
    public let nome: String
    public let custo: Int

    /// Por ordem de preço; o Céu (o fundo de sempre) é grátis e de todos.
    public static let catalogo: [Cenario] = [
        Cenario(id: .ceu, nome: "Céu", custo: 0),
        Cenario(id: .parque, nome: "Parque", custo: 3),
        Cenario(id: .praia, nome: "Praia", custo: 7),
        Cenario(id: .biblioteca, nome: "Biblioteca", custo: 10),
        Cenario(id: .viagem, nome: "Viagem", custo: 14),
        Cenario(id: .montanha, nome: "Montanha", custo: 21),
    ]

    public static func de(_ id: CenarioId) -> Cenario {
        catalogo.first { $0.id == id }!
    }
}
