import SwiftUI
import ToDoCore

/// Cores do catálogo `Assets.xcassets` (DESIGN.md 3). Cada cor de lista tem 4 variantes:
/// base (preenchimentos e anéis), tinta (texto colorido), fundo (ecrãs da lista) e texto
/// (texto sobre a base).
extension CorLista {
    private var nomeAsset: String {
        switch self {
        case .azul: "Azul"
        case .roxo: "Roxo"
        case .amarelo: "Amarelo"
        case .vermelho: "Vermelho"
        case .laranja: "Laranja"
        case .verde: "Verde"
        case .turquesa: "Turquesa"
        case .ceu: "Ceu"
        case .indigo: "Indigo"
        case .rosa: "Rosa"
        case .castanho: "Castanho"
        case .grafite: "Grafite"
        }
    }

    var base: Color { Color("Lista\(nomeAsset)") }
    var tinta: Color { Color("Lista\(nomeAsset)Tinta") }
    var fundo: Color { Color("Lista\(nomeAsset)Fundo") }
    var texto: Color { Color("Lista\(nomeAsset)Texto") }

    /// Cores claras levam texto escuro e fichas escuras por cima.
    var ehClara: Bool {
        [.amarelo, .laranja, .verde, .turquesa, .ceu].contains(self)
    }

    /// Fundo do círculo do ícone quando está por cima da cor base.
    var ficha: Color {
        ehClara ? Color.black.opacity(0.12) : Color.white.opacity(0.25)
    }

    var nome: String {
        switch self {
        case .azul: "Azul"
        case .roxo: "Roxo"
        case .amarelo: "Amarelo"
        case .vermelho: "Vermelho"
        case .laranja: "Laranja"
        case .verde: "Verde"
        case .turquesa: "Turquesa"
        case .ceu: "Céu"
        case .indigo: "Índigo"
        case .rosa: "Rosa"
        case .castanho: "Castanho"
        case .grafite: "Grafite"
        }
    }
}

enum CoresEstado {
    static let expira = Color("EstadoExpira")
    static let expiraTinta = Color("EstadoExpiraTinta")
    static let expiradosFundo = Color("EstadoExpiradosFundo")
    static let concluido = Color("EstadoConcluido")
    static let anelTrilho = Color("AnelTrilho")
}

/// Aparência escolhida nas Definições.
enum Aparencia: String, CaseIterable, Identifiable {
    case sistema, claro, escuro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .sistema: "Sistema"
        case .claro: "Claro"
        case .escuro: "Escuro"
        }
    }

    var esquema: ColorScheme? {
        switch self {
        case .sistema: nil
        case .claro: .light
        case .escuro: .dark
        }
    }
}

extension Binding where Value == Bool {
    /// Verdadeiro enquanto o opcional tiver valor; ao fechar, limpa-o.
    init<T>(presente opcional: Binding<T?>) {
        self.init(
            get: { opcional.wrappedValue != nil },
            set: { if !$0 { opcional.wrappedValue = nil } }
        )
    }
}

/// Cabeçalho de secção em maiúsculas ("FIXADOS", "ATIVOS").
struct TituloSecao: View {
    let texto: String
    var cor: Color = .secondary

    var body: some View {
        Text(texto.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(cor)
    }
}
