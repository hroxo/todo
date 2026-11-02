import Foundation

/// O céu do fundo da app: segue o sol de cada dia, sem rede nem localização.
public struct CeuDoDia: Equatable, Sendable {
    public enum Fase: String, Equatable, Sendable {
        case amanhecer, dia, porDoSol, noite
    }

    public let fase: Fase
    public let nascer: Date
    public let por: Date
    /// O caminho do sol, de 0 ao nascer a 1 ao pôr; fora disso fica em 0 ou 1.
    public let percurso: Double
    /// Bom dia até ao meio-dia, boa tarde até o sol se pôr e boa noite depois.
    public let saudacao: String

    // shortcut: Lisboa para todos, porque a app não pede localização; usar CoreLocation se o dono viajar muito.
    public static let latitudeLisboa = 38.72
    public static let longitudeLisboa = -9.14

    private static let antesDoNascer: TimeInterval = 30 * 60
    private static let depoisDoNascer: TimeInterval = 45 * 60
    private static let antesDoPor: TimeInterval = 45 * 60
    private static let depoisDoPor: TimeInterval = 25 * 60

    public init(
        agora: Date,
        calendario: Calendar = .current,
        latitude: Double = CeuDoDia.latitudeLisboa,
        longitude: Double = CeuDoDia.longitudeLisboa
    ) {
        let (nascer, por) = Self.sol(em: agora, calendario: calendario, latitude: latitude, longitude: longitude)
        self.nascer = nascer
        self.por = por
        percurso = min(1, max(0, agora.timeIntervalSince(nascer) / por.timeIntervalSince(nascer)))

        if agora >= nascer.addingTimeInterval(-Self.antesDoNascer), agora < nascer.addingTimeInterval(Self.depoisDoNascer) {
            fase = .amanhecer
        } else if agora >= por.addingTimeInterval(-Self.antesDoPor), agora < por.addingTimeInterval(Self.depoisDoPor) {
            fase = .porDoSol
        } else if agora >= nascer, agora < por {
            fase = .dia
        } else {
            fase = .noite
        }

        if agora < nascer.addingTimeInterval(-Self.antesDoNascer) || agora >= por.addingTimeInterval(Self.depoisDoPor) {
            saudacao = "Boa noite!"
        } else {
            saudacao = calendario.component(.hour, from: agora) < 12 ? "Bom dia!" : "Boa tarde!"
        }
    }

    /// A saudação da Ampulheta, com uma palavra sobre o céu quando ele merece.
    public var saudacaoDoMomento: String {
        switch fase {
        case .amanhecer: "\(saudacao) O sol está a nascer."
        case .porDoSol: "\(saudacao) Olha o pôr do sol."
        case .dia, .noite: saudacao
        }
    }

    /// A equação do nascer do sol: dá as horas do dia civil de `agora`, com a refração da atmosfera.
    private static func sol(em agora: Date, calendario: Calendar, latitude: Double, longitude: Double) -> (Date, Date) {
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
