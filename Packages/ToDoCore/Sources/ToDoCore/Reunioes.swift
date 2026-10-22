import Foundation

/// Resposta de um participante a um convite (Melhoria 6.2).
public enum RespostaConvite: String, CaseIterable, Sendable {
    case aceite, talvez, recusado, pendente

    public var nome: String {
        switch self {
        case .aceite: "Aceite"
        case .talvez: "Talvez"
        case .recusado: "Recusado"
        case .pendente: "Pendente"
        }
    }
}

/// Link da reunião de um evento (Melhoria 6.2): o URL do evento, se existir; senão, o
/// primeiro link de uma reunião conhecida (Teams, Zoom, Meet, Webex) no local ou nas notas,
/// que é onde os convites o costumam pôr; senão, o primeiro link web.
public enum LigacaoReuniao {
    static let anfitrioes = ["teams.microsoft.com", "teams.live.com", "zoom.us", "meet.google.com", "webex.com", "whereby.com"]

    public static func encontrar(url: URL?, local: String?, notas: String?) -> URL? {
        if let url, ["http", "https"].contains(url.scheme?.lowercased()) {
            return url
        }
        let links = [local, notas].compactMap { $0 }.flatMap(Self.links(em:))
        let reuniao = links.first { link in
            guard let anfitriao = link.host?.lowercased() else { return false }
            return anfitrioes.contains { anfitriao == $0 || anfitriao.hasSuffix("." + $0) }
        }
        return reuniao ?? links.first
    }

    static func links(em texto: String) -> [URL] {
        guard let detetor = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let intervalo = NSRange(texto.startIndex..., in: texto)
        return detetor.matches(in: texto, range: intervalo).compactMap(\.url).filter {
            ["http", "https"].contains($0.scheme?.lowercased())
        }
    }
}
