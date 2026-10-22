import Foundation

/// Um calendário de uma conta ligada diretamente (Melhoria 7).
public struct CalendarioExterno: Equatable, Sendable {
    /// Único entre fornecedores: "google:<id>" ou "microsoft:<id>".
    public let id: String
    /// O identificador no fornecedor, para os pedidos.
    public let idFornecedor: String
    public let nome: String
    /// "#4285F4", se o fornecedor der uma cor.
    public let corHex: String?
    public let fornecedor: Fornecedor
}

public struct ParticipanteExterno: Equatable, Sendable {
    public let nome: String
    public let resposta: RespostaConvite
}

/// Um evento lido da Google ou da Microsoft, já no formato da app.
public struct EventoExterno: Equatable, Sendable {
    /// O iCalUID: o mesmo que o EventKit dá ao evento quando a conta também está no iPhone,
    /// para não aparecer duas vezes e para o ✓ do "+" funcionar nas duas fontes.
    public let id: String
    public let titulo: String
    public let inicio: Date
    public let fim: Date
    public let diaInteiro: Bool
    public let local: String
    public let notas: String
    public let organizador: String?
    public let participantes: [ParticipanteExterno]
    public let link: URL?
    public let calendarioId: String
}

/// Pedidos às APIs e leitura das respostas (Melhoria 7). Só leitura.
public enum APICalendario {
    // MARK: - Pedidos

    public static func pedidoCalendarios(_ fornecedor: Fornecedor, token: String) -> URLRequest {
        let url = switch fornecedor {
        case .google: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader")!
        case .microsoft: URL(string: "https://graph.microsoft.com/v1.0/me/calendars?$top=50")!
        }
        return pedido(url, token: token)
    }

    /// Os eventos de um calendário entre duas datas, com os recorrentes já expandidos.
    public static func pedidoEventos(_ calendario: CalendarioExterno, de inicio: Date, ate fim: Date, token: String) -> URLRequest {
        let datas = ISO8601DateFormatter()
        datas.timeZone = TimeZone(identifier: "UTC")
        var partes: URLComponents
        switch calendario.fornecedor {
        case .google:
            let id = calendario.idFornecedor.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? calendario.idFornecedor
            partes = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(id)/events")!
            partes.queryItems = [
                URLQueryItem(name: "timeMin", value: datas.string(from: inicio)),
                URLQueryItem(name: "timeMax", value: datas.string(from: fim)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "100"),
            ]
        case .microsoft:
            partes = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(calendario.idFornecedor)/calendarView")!
            partes.queryItems = [
                URLQueryItem(name: "startDateTime", value: datas.string(from: inicio)),
                URLQueryItem(name: "endDateTime", value: datas.string(from: fim)),
                URLQueryItem(name: "$top", value: "100"),
            ]
        }
        var resultado = pedido(partes.url!, token: token)
        if calendario.fornecedor == .microsoft {
            // Horas em UTC e o corpo do convite em texto simples.
            resultado.setValue("outlook.timezone=\"UTC\", outlook.body-content-type=\"text\"", forHTTPHeaderField: "Prefer")
        }
        return resultado
    }

    private static func pedido(_ url: URL, token: String) -> URLRequest {
        var pedido = URLRequest(url: url)
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return pedido
    }

    // MARK: - Calendários

    public static func lerCalendarios(_ dados: Data, fornecedor: Fornecedor) throws -> [CalendarioExterno] {
        switch fornecedor {
        case .google:
            struct Lista: Decodable {
                struct Entrada: Decodable {
                    let id: String
                    let summary: String?
                    let summaryOverride: String?
                    let backgroundColor: String?
                }
                let items: [Entrada]?
            }
            let lista = try JSONDecoder().decode(Lista.self, from: dados)
            return (lista.items ?? []).map {
                CalendarioExterno(id: "google:\($0.id)", idFornecedor: $0.id, nome: $0.summaryOverride ?? $0.summary ?? $0.id,
                                  corHex: $0.backgroundColor, fornecedor: .google)
            }
        case .microsoft:
            struct Lista: Decodable {
                struct Entrada: Decodable {
                    let id: String
                    let name: String?
                    let hexColor: String?
                }
                let value: [Entrada]?
            }
            let lista = try JSONDecoder().decode(Lista.self, from: dados)
            return (lista.value ?? []).map {
                let cor = ($0.hexColor?.isEmpty == false) ? $0.hexColor : nil
                return CalendarioExterno(id: "microsoft:\($0.id)", idFornecedor: $0.id, nome: $0.name ?? "Calendário",
                                         corHex: cor, fornecedor: .microsoft)
            }
        }
    }

    // MARK: - Eventos

    /// Os eventos de uma resposta, sem os cancelados. Os de dia inteiro começam à meia-noite
    /// no fuso do iPhone.
    public static func lerEventos(_ dados: Data, calendario: CalendarioExterno, fuso: Calendar = .current) throws -> [EventoExterno] {
        switch calendario.fornecedor {
        case .google: try lerGoogle(dados, calendarioId: calendario.id, fuso: fuso)
        case .microsoft: try lerMicrosoft(dados, calendarioId: calendario.id, fuso: fuso)
        }
    }

    private static func lerGoogle(_ dados: Data, calendarioId: String, fuso: Calendar) throws -> [EventoExterno] {
        struct Resposta: Decodable {
            struct Momento: Decodable {
                let dateTime: String?
                let date: String?
            }
            struct Pessoa: Decodable {
                let email: String?
                let displayName: String?
                let responseStatus: String?
            }
            struct Conferencia: Decodable {
                struct Entrada: Decodable {
                    let entryPointType: String?
                    let uri: String?
                }
                let entryPoints: [Entrada]?
            }
            struct Evento: Decodable {
                let id: String
                let iCalUID: String?
                let status: String?
                let summary: String?
                let description: String?
                let location: String?
                let start: Momento?
                let end: Momento?
                let organizer: Pessoa?
                let attendees: [Pessoa]?
                let hangoutLink: String?
                let conferenceData: Conferencia?
            }
            let items: [Evento]?
        }
        let lida = try JSONDecoder().decode(Resposta.self, from: dados)
        return (lida.items ?? []).compactMap { evento in
            guard evento.status != "cancelled",
                  let inicio = momento(evento.start?.dateTime, dia: evento.start?.date, fuso: fuso),
                  let fim = momento(evento.end?.dateTime, dia: evento.end?.date, fuso: fuso)
            else { return nil }
            let local = evento.location ?? ""
            let notas = TextoSimples.de(evento.description ?? "")
            let video = evento.conferenceData?.entryPoints?.first { $0.entryPointType == "video" }?.uri
            let link = [evento.hangoutLink, video].compactMap { $0.flatMap(URL.init(string:)) }.first
                ?? LigacaoReuniao.encontrar(url: nil, local: local, notas: notas)
            return EventoExterno(
                id: evento.iCalUID ?? evento.id,
                titulo: (evento.summary?.isEmpty == false ? evento.summary : nil) ?? "Sem título",
                inicio: inicio,
                fim: fim,
                diaInteiro: evento.start?.date != nil,
                local: local,
                notas: notas,
                organizador: evento.organizer.map { $0.displayName ?? $0.email ?? "" },
                participantes: (evento.attendees ?? []).map {
                    ParticipanteExterno(nome: $0.displayName ?? $0.email ?? "", resposta: resposta(google: $0.responseStatus))
                },
                link: link,
                calendarioId: calendarioId
            )
        }
    }

    private static func lerMicrosoft(_ dados: Data, calendarioId: String, fuso: Calendar) throws -> [EventoExterno] {
        struct Resposta: Decodable {
            struct Momento: Decodable {
                let dateTime: String
            }
            struct Endereco: Decodable {
                let name: String?
                let address: String?
            }
            struct Pessoa: Decodable {
                struct Estado: Decodable {
                    let response: String?
                }
                let emailAddress: Endereco?
                let status: Estado?
            }
            struct Organizador: Decodable {
                let emailAddress: Endereco?
            }
            struct Corpo: Decodable {
                let contentType: String?
                let content: String?
            }
            struct Local: Decodable {
                let displayName: String?
            }
            struct Reuniao: Decodable {
                let joinUrl: String?
            }
            struct Evento: Decodable {
                let id: String
                let iCalUId: String?
                let subject: String?
                let isAllDay: Bool?
                let isCancelled: Bool?
                let start: Momento
                let end: Momento
                let location: Local?
                let body: Corpo?
                let bodyPreview: String?
                let organizer: Organizador?
                let attendees: [Pessoa]?
                let onlineMeeting: Reuniao?
            }
            let value: [Evento]?
        }
        let lida = try JSONDecoder().decode(Resposta.self, from: dados)
        return (lida.value ?? []).compactMap { evento in
            let diaInteiro = evento.isAllDay ?? false
            guard evento.isCancelled != true,
                  let inicio = momentoMicrosoft(evento.start.dateTime, diaInteiro: diaInteiro, fuso: fuso),
                  let fim = momentoMicrosoft(evento.end.dateTime, diaInteiro: diaInteiro, fuso: fuso)
            else { return nil }
            let local = evento.location?.displayName ?? ""
            let corpo = evento.body?.content ?? evento.bodyPreview ?? ""
            let notas = evento.body?.contentType?.lowercased() == "html" ? TextoSimples.de(corpo) : corpo
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let link = evento.onlineMeeting?.joinUrl.flatMap(URL.init(string:))
                ?? LigacaoReuniao.encontrar(url: nil, local: local, notas: notas)
            func nome(_ endereco: Resposta.Endereco?) -> String {
                endereco?.name ?? endereco?.address ?? ""
            }
            return EventoExterno(
                id: evento.iCalUId ?? evento.id,
                titulo: (evento.subject?.isEmpty == false ? evento.subject : nil) ?? "Sem título",
                inicio: inicio,
                fim: fim,
                diaInteiro: diaInteiro,
                local: local,
                notas: notas,
                organizador: evento.organizer.map { nome($0.emailAddress) },
                participantes: (evento.attendees ?? []).map {
                    ParticipanteExterno(nome: nome($0.emailAddress), resposta: resposta(microsoft: $0.status?.response))
                },
                link: link,
                calendarioId: calendarioId
            )
        }
    }

    static func resposta(google estado: String?) -> RespostaConvite {
        switch estado {
        case "accepted": .aceite
        case "declined": .recusado
        case "tentative": .talvez
        default: .pendente
        }
    }

    static func resposta(microsoft estado: String?) -> RespostaConvite {
        switch estado {
        case "accepted", "organizer": .aceite
        case "declined": .recusado
        case "tentativelyAccepted": .talvez
        default: .pendente
        }
    }

    // MARK: - Datas

    /// Google: "2026-10-22T14:30:00+01:00", ou só o dia ("2026-10-22") nos de dia inteiro.
    static func momento(_ dataHora: String?, dia: String?, fuso: Calendar) -> Date? {
        if let dataHora {
            let formato = ISO8601DateFormatter()
            if let data = formato.date(from: dataHora) { return data }
            formato.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formato.date(from: dataHora)
        }
        return dia.flatMap { meiaNoite($0, fuso: fuso) }
    }

    /// Microsoft: "2026-10-22T13:30:00.0000000", em UTC (pedido no cabeçalho `Prefer`). Os de
    /// dia inteiro vêm à meia-noite e contam como dias, no fuso do iPhone.
    static func momentoMicrosoft(_ texto: String, diaInteiro: Bool, fuso: Calendar) -> Date? {
        if diaInteiro {
            return meiaNoite(String(texto.prefix(10)), fuso: fuso)
        }
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = TimeZone(identifier: "UTC")
        formato.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formato.date(from: String(texto.prefix(19)))
    }

    private static func meiaNoite(_ dia: String, fuso: Calendar) -> Date? {
        let partes = dia.split(separator: "-").compactMap { Int($0) }
        guard partes.count == 3 else { return nil }
        return fuso.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2]))
    }
}

/// Junta os eventos do EventKit com os das contas ligadas: o mesmo evento (mesmo iCalUID e
/// mesmo início) aparece uma só vez, e fica a versão da conta ligada, que tem mais detalhes.
public enum JuntarEventos {
    public static func juntar<Local, Externo>(
        locais: [Local],
        externos: [Externo],
        chaveLocal: (Local) -> (id: String, inicio: Date),
        chaveExterno: (Externo) -> (id: String, inicio: Date)
    ) -> (locais: [Local], externos: [Externo]) {
        func chave(_ par: (id: String, inicio: Date)) -> String {
            "\(par.id)|\(Int(par.inicio.timeIntervalSince1970))"
        }
        var vistos = Set<String>()
        let externosUnicos = externos.filter { vistos.insert(chave(chaveExterno($0))).inserted }
        let locaisUnicos = locais.filter { !vistos.contains(chave(chaveLocal($0))) }
        return (locaisUnicos, externosUnicos)
    }
}

/// Texto simples a partir do HTML das descrições dos convites.
public enum TextoSimples {
    public static func de(_ html: String) -> String {
        guard html.contains("<") || html.contains("&") else {
            return html.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var texto = html
        for quebra in ["<br>", "<br/>", "<br />", "</p>", "</div>", "</li>"] {
            texto = texto.replacingOccurrences(of: quebra, with: "\n", options: .caseInsensitive)
        }
        texto = texto.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entidades = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
        for (entidade, caracter) in entidades {
            texto = texto.replacingOccurrences(of: entidade, with: caracter)
        }
        // No máximo uma linha em branco seguida.
        texto = texto.replacingOccurrences(of: "\n[ \t]*\n([ \t]*\n)+", with: "\n\n", options: .regularExpression)
        return texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
