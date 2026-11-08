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
    static let concluido = Color("EstadoConcluido")
    static let anelTrilho = Color("AnelTrilho")
}

/// Aparência escolhida nas Definições. "Reativo" é claro de dia e escuro depois do pôr do sol.
enum Aparencia: String, CaseIterable, Identifiable {
    case sistema, claro, escuro, reativo

    /// Chave nova de propósito: a antiga ("aparencia", até à Melhoria 24) pode ainda guardar
    /// "claro" ou "escuro" e mudava o modo a quem nunca o escolheu nesta versão.
    static let chave = "aparenciaEscolhida"

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .sistema: "Sistema"
        case .claro: "Claro"
        case .escuro: "Escuro"
        case .reativo: "Reativo"
        }
    }

    func esquema(agora: Date) -> ColorScheme? {
        switch self {
        case .sistema: nil
        case .claro: .light
        case .escuro: .dark
        case .reativo: CeuDoDia.ehNoite(agora: agora) ? .dark : .light
        }
    }
}

extension Binding where Value == Definicoes {
    /// A hora dos avisos como `Date`, para o `DatePicker` (Definições e questionário).
    var horaAvisos: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: wrappedValue.horaNotificacao,
                    minute: wrappedValue.minutoNotificacao,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { nova in
                let c = Calendar.current.dateComponents([.hour, .minute], from: nova)
                wrappedValue.definirHora(c.hour ?? 9, c.minute ?? 0)
            }
        )
    }

    /// A hora do Fecho do dia como `Date`, para o `DatePicker` das Definições.
    var horaFecho: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: wrappedValue.horaFechoDia,
                    minute: wrappedValue.minutoFechoDia,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { nova in
                let c = Calendar.current.dateComponents([.hour, .minute], from: nova)
                wrappedValue.definirHoraFecho(c.hour ?? 21, c.minute ?? 0)
            }
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

/// Cabeçalho de secção ("Fixados", "Ativos").
struct TituloSecao: View {
    let texto: String
    var cor: Color = .secondary

    var body: some View {
        Text(texto)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(cor)
    }
}
