import SwiftUI
import ToDoCore

/// Cores reais da paleta das listas. Tons vivos, como os anéis da app Fitness,
/// pensados para fundo escuro.
extension CorLista {
    var cor: Color {
        switch self {
        case .vermelho: Color(hex: 0xFA114F)
        case .laranja: Color(hex: 0xFF9F0A)
        case .amarelo: Color(hex: 0xFFD60A)
        case .verde: Color(hex: 0x92E82A)
        case .ciano: Color(hex: 0x1EEAEF)
        case .azul: Color(hex: 0x0A84FF)
        case .roxo: Color(hex: 0xBF5AF2)
        case .rosa: Color(hex: 0xFF6FB5)
        }
    }

    var nome: String {
        switch self {
        case .vermelho: "Vermelho"
        case .laranja: "Laranja"
        case .amarelo: "Amarelo"
        case .verde: "Verde"
        case .ciano: "Ciano"
        case .azul: "Azul"
        case .roxo: "Roxo"
        case .rosa: "Rosa"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
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
