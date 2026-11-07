import Foundation

/// O céu do fundo da app: de dia no modo claro e de noite no modo escuro. Na Aparência "Reativo"
/// é o sol de Lisboa que escolhe o modo (`ehNoite`).
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

    // shortcut: Lisboa para todos, porque a app não pede localização; usar CoreLocation se o dono viajar muito.
    public static let latitudeLisboa = 38.72
    public static let longitudeLisboa = -9.14

    /// A Aparência "Reativo": noite antes do nascer e depois do pôr do sol, sem rede nem localização.
    public static func ehNoite(agora: Date, calendario: Calendar = .current) -> Bool {
        let (nascer, por) = sol(em: agora, calendario: calendario, latitude: latitudeLisboa, longitude: longitudeLisboa)
        return agora < nascer || agora >= por
    }

    /// A equação do nascer do sol: dá as horas do dia civil de `agora`, com a refração da atmosfera.
    static func sol(em agora: Date, calendario: Calendar, latitude: Double, longitude: Double) -> (Date, Date) {
        func rad(_ graus: Double) -> Double { graus * .pi / 180 }
        // Meio-dia local, para o dia solar ser o do calendário em qualquer fuso.
        let meioDia = calendario.date(bySettingHour: 12, minute: 0, second: 0, of: agora) ?? agora
        let juliano = meioDia.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let dias = (juliano - 2_451_545.0 - 0.0009 - longitude / 360).rounded()
        let medio = dias + 0.0009 - longitude / 360
        let anomalia = (357.5291 + 0.98560028 * medio).truncatingRemainder(dividingBy: 360)
        let centro = 1.9148 * sin(rad(anomalia)) + 0.02 * sin(rad(2 * anomalia)) + 0.0003 * sin(rad(3 * anomalia))
        let eclitica = (anomalia + centro + 180 + 102.9372).truncatingRemainder(dividingBy: 360)
        let transito = 2_451_545.0 + medio + 0.0053 * sin(rad(anomalia)) - 0.0069 * sin(rad(2 * eclitica))
        let declinacao = asin(sin(rad(eclitica)) * sin(rad(23.44)))
        let cosseno = (sin(rad(-0.833)) - sin(rad(latitude)) * sin(declinacao)) / (cos(rad(latitude)) * cos(declinacao))
        let arco = acos(min(1, max(-1, cosseno))) * 180 / .pi / 360
        func data(_ dia: Double) -> Date { Date(timeIntervalSince1970: (dia - 2_440_587.5) * 86_400) }
        return (data(transito - arco), data(transito + arco))
    }
}

