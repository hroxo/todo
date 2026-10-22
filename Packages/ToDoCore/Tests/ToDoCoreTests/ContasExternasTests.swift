import XCTest
@testable import ToDoCore

/// Melhoria 7: login Google e Microsoft (OAuth com PKCE) e leitura dos calendários.
final class OAuthTests: XCTestCase {
    private let google = ConfiguracaoOAuth.google(clientId: "123-abc.apps.googleusercontent.com")
    private let microsoft = ConfiguracaoOAuth.microsoft(clientId: "00000000-1111-2222-3333-444444444444")

    private func parametros(_ url: URL) -> [String: String] {
        let itens = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: itens.map { ($0.name, $0.value ?? "") })
    }

    private func corpo(_ pedido: URLRequest) -> [String: String] {
        let texto = String(decoding: pedido.httpBody ?? Data(), as: UTF8.self)
        return Dictionary(uniqueKeysWithValues: texto.split(separator: "&").map { par in
            let partes = par.split(separator: "=", maxSplits: 1).map(String.init)
            return (partes[0], partes[1].removingPercentEncoding ?? partes[1])
        })
    }

    // MARK: - Configuração

    func testRetornoDaGoogleEOClienteAoContrario() {
        XCTAssertEqual(google.redirecionamento, "com.googleusercontent.apps.123-abc:/oauth2redirect")
        XCTAssertEqual(google.esquemaRetorno, "com.googleusercontent.apps.123-abc")
        XCTAssertTrue(google.ambitos.contains("https://www.googleapis.com/auth/calendar.readonly"))
    }

    func testRetornoDaMicrosoft() {
        XCTAssertEqual(microsoft.redirecionamento, "todo-hugo://auth")
        XCTAssertEqual(microsoft.esquemaRetorno, "todo-hugo")
        XCTAssertTrue(microsoft.ambitos.contains("offline_access"))
        XCTAssertTrue(microsoft.ambitos.contains("Calendars.Read"))
    }

    // MARK: - PKCE

    /// Exemplo do RFC 7636, apêndice B.
    func testDesafioDoRFC() {
        let pkce = PKCE(verificador: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        XCTAssertEqual(pkce.desafio, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testVerificadorAleatorio() {
        let a = PKCE.gerar()
        let b = PKCE.gerar()
        XCTAssertNotEqual(a.verificador, b.verificador)
        XCTAssertEqual(a.verificador.count, 43)
        XCTAssertNil(a.verificador.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
    }

    // MARK: - Autorização

    func testURLDeAutorizacaoDaGoogle() {
        let pkce = PKCE(verificador: "verificador")
        let url = OAuth.urlAutorizacao(google, pkce: pkce, estado: "abc")
        let p = parametros(url)
        XCTAssertEqual(url.host, "accounts.google.com")
        XCTAssertEqual(p["client_id"], google.clientId)
        XCTAssertEqual(p["redirect_uri"], google.redirecionamento)
        XCTAssertEqual(p["response_type"], "code")
        XCTAssertEqual(p["code_challenge"], pkce.desafio)
        XCTAssertEqual(p["code_challenge_method"], "S256")
        XCTAssertEqual(p["state"], "abc")
        XCTAssertEqual(p["access_type"], "offline")
        XCTAssertEqual(p["scope"], "openid email https://www.googleapis.com/auth/calendar.readonly")
    }

    func testURLDeAutorizacaoDaMicrosoft() {
        let url = OAuth.urlAutorizacao(microsoft, pkce: PKCE(verificador: "v"), estado: "xyz")
        let p = parametros(url)
        XCTAssertEqual(url.host, "login.microsoftonline.com")
        XCTAssertEqual(p["response_mode"], "query")
        XCTAssertNil(p["access_type"])
        XCTAssertEqual(p["redirect_uri"], "todo-hugo://auth")
    }

    func testCodigoDoRetorno() throws {
        let url = URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=abc&code=4/0Ab-xyz")!
        XCTAssertEqual(try OAuth.codigo(deRetorno: url, estado: "abc"), "4/0Ab-xyz")
    }

    func testRetornoComErroOuEstadoErrado() {
        let recusado = URL(string: "todo-hugo://auth?error=access_denied&state=abc")!
        XCTAssertThrowsError(try OAuth.codigo(deRetorno: recusado, estado: "abc")) {
            XCTAssertEqual($0 as? ErroOAuth, .recusado("access_denied"))
        }
        let outro = URL(string: "todo-hugo://auth?code=1&state=outro")!
        XCTAssertThrowsError(try OAuth.codigo(deRetorno: outro, estado: "abc")) {
            XCTAssertEqual($0 as? ErroOAuth, .estadoInvalido)
        }
        let semCodigo = URL(string: "todo-hugo://auth?state=abc")!
        XCTAssertThrowsError(try OAuth.codigo(deRetorno: semCodigo, estado: "abc")) {
            XCTAssertEqual($0 as? ErroOAuth, .semCodigo)
        }
    }

    // MARK: - Tokens

    func testPedidoDeToken() {
        let pkce = PKCE(verificador: "o-meu-verificador")
        let pedido = OAuth.pedidoToken(google, codigo: "4/0Ab+xyz", pkce: pkce)
        XCTAssertEqual(pedido.httpMethod, "POST")
        XCTAssertEqual(pedido.url, google.token)
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let campos = corpo(pedido)
        XCTAssertEqual(campos["grant_type"], "authorization_code")
        XCTAssertEqual(campos["code"], "4/0Ab+xyz")
        XCTAssertEqual(campos["code_verifier"], "o-meu-verificador")
        XCTAssertEqual(campos["redirect_uri"], google.redirecionamento)
        XCTAssertNil(campos["client_secret"])
        // O "+" e o "/" vão codificados no corpo.
        XCTAssertTrue(String(decoding: pedido.httpBody!, as: UTF8.self).contains("code=4%2F0Ab%2Bxyz"))
    }

    func testPedidoDeRenovacao() {
        XCTAssertNil(corpo(OAuth.pedidoRenovacao(google, renovacao: "r")).keys.first { $0 == "scope" })
        let campos = corpo(OAuth.pedidoRenovacao(microsoft, renovacao: "r"))
        XCTAssertEqual(campos["grant_type"], "refresh_token")
        XCTAssertEqual(campos["refresh_token"], "r")
        XCTAssertEqual(campos["scope"], microsoft.ambitos.joined(separator: " "))
    }

    func testLerTokensERenovar() throws {
        let agora = Date(timeIntervalSince1970: 1_792_573_200)
        let json = #"{"access_token":"a1","refresh_token":"r1","expires_in":3599,"token_type":"Bearer"}"#
        let tokens = try OAuth.lerTokens(Data(json.utf8), agora: agora)
        XCTAssertEqual(tokens, Tokens(acesso: "a1", renovacao: "r1", expiraEm: agora.addingTimeInterval(3599)))
        XCTAssertTrue(tokens.valido(agora: agora))
        XCTAssertFalse(tokens.valido(agora: agora.addingTimeInterval(3560)))

        // A Google não devolve outro token de renovação: fica o antigo.
        let novos = try OAuth.lerTokens(Data(#"{"access_token":"a2","expires_in":3600}"#.utf8), agora: agora)
        XCTAssertEqual(tokens.renovado(com: novos).renovacao, "r1")
        XCTAssertEqual(tokens.renovado(com: novos).acesso, "a2")
    }

    func testErroNaRespostaDeTokens() {
        XCTAssertThrowsError(try OAuth.lerTokens(Data(#"{"error":"invalid_grant"}"#.utf8), agora: .now)) {
            XCTAssertEqual($0 as? ErroOAuth, .recusado("invalid_grant"))
        }
        XCTAssertThrowsError(try OAuth.lerTokens(Data("não é json".utf8), agora: .now)) {
            XCTAssertEqual($0 as? ErroOAuth, .respostaInvalida)
        }
    }
}

final class APICalendarioTests: BaseTestes {
    private let calendarioGoogle = CalendarioExterno(id: "google:primary", idFornecedor: "primary", nome: "Hugo",
                                                     corHex: "#4285F4", fornecedor: .google)
    private let calendarioMicrosoft = CalendarioExterno(id: "microsoft:AAA", idFornecedor: "AAA", nome: "Calendário",
                                                        corHex: nil, fornecedor: .microsoft)

    func testCalendariosDaGoogle() throws {
        let json = #"{"items":[{"id":"primary@gmail.com","summary":"Hugo","backgroundColor":"#4285F4"},{"id":"pt#holiday@group.v.calendar.google.com","summary":"Feriados","summaryOverride":"Feriados em Portugal"}]}"#
        let calendarios = try APICalendario.lerCalendarios(Data(json.utf8), fornecedor: .google)
        XCTAssertEqual(calendarios.map(\.id), ["google:primary@gmail.com", "google:pt#holiday@group.v.calendar.google.com"])
        XCTAssertEqual(calendarios.map(\.nome), ["Hugo", "Feriados em Portugal"])
        XCTAssertEqual(calendarios.first?.corHex, "#4285F4")
    }

    func testCalendariosDaMicrosoft() throws {
        let json = #"{"value":[{"id":"AAA=","name":"Calendário","hexColor":""},{"id":"BBB=","name":"Equipa","hexColor":"#e3008c"}]}"#
        let calendarios = try APICalendario.lerCalendarios(Data(json.utf8), fornecedor: .microsoft)
        XCTAssertEqual(calendarios.map(\.nome), ["Calendário", "Equipa"])
        XCTAssertNil(calendarios[0].corHex)
        XCTAssertEqual(calendarios[1].corHex, "#e3008c")
        XCTAssertEqual(calendarios[1].fornecedor, .microsoft)
    }

    func testEventosDaGoogle() throws {
        let json = """
        {"items":[
          {"id":"e1","iCalUID":"uid-1@google.com","summary":"Revisão do roadmap",
           "description":"Olá<br>Agenda: <b>riscos</b> &amp; datas","location":"Sala 3",
           "start":{"dateTime":"2026-10-21T14:30:00+01:00"},"end":{"dateTime":"2026-10-21T15:30:00+01:00"},
           "organizer":{"email":"marta@exemplo.pt","displayName":"Marta"},
           "attendees":[{"email":"marta@exemplo.pt","displayName":"Marta","responseStatus":"accepted"},
                        {"email":"rui@exemplo.pt","responseStatus":"tentative"},
                        {"email":"ines@exemplo.pt","responseStatus":"declined"},
                        {"email":"hugo@exemplo.pt","responseStatus":"needsAction"}],
           "hangoutLink":"https://meet.google.com/abc-defg-hij"},
          {"id":"e2","summary":"Aniversário","start":{"date":"2026-10-21"},"end":{"date":"2026-10-22"}},
          {"id":"e3","status":"cancelled","start":{"date":"2026-10-21"},"end":{"date":"2026-10-22"}}
        ]}
        """
        let eventos = try APICalendario.lerEventos(Data(json.utf8), calendario: calendarioGoogle, fuso: calendario)
        XCTAssertEqual(eventos.count, 2)

        let reuniao = eventos[0]
        XCTAssertEqual(reuniao.id, "uid-1@google.com")
        XCTAssertEqual(reuniao.titulo, "Revisão do roadmap")
        XCTAssertEqual(reuniao.inicio, data(2026, 10, 21, 14, 30))
        XCTAssertEqual(reuniao.fim, data(2026, 10, 21, 15, 30))
        XCTAssertFalse(reuniao.diaInteiro)
        XCTAssertEqual(reuniao.local, "Sala 3")
        XCTAssertEqual(reuniao.notas, "Olá\nAgenda: riscos & datas")
        XCTAssertEqual(reuniao.organizador, "Marta")
        XCTAssertEqual(reuniao.participantes.map(\.nome), ["Marta", "rui@exemplo.pt", "ines@exemplo.pt", "hugo@exemplo.pt"])
        XCTAssertEqual(reuniao.participantes.map(\.resposta), [.aceite, .talvez, .recusado, .pendente])
        XCTAssertEqual(reuniao.link?.host, "meet.google.com")
        XCTAssertEqual(reuniao.calendarioId, "google:primary")

        let aniversario = eventos[1]
        XCTAssertTrue(aniversario.diaInteiro)
        XCTAssertEqual(aniversario.id, "e2")
        XCTAssertEqual(aniversario.inicio, data(2026, 10, 21, 0))
        XCTAssertTrue(aniversario.participantes.isEmpty)
        XCTAssertNil(aniversario.link)
    }

    func testEventosDaMicrosoft() throws {
        let json = """
        {"value":[
          {"id":"m1","iCalUId":"040000008200E00074C5B7101A82E008","subject":"Daily da equipa","isAllDay":false,
           "isCancelled":false,"start":{"dateTime":"2026-10-21T08:30:00.0000000","timeZone":"UTC"},
           "end":{"dateTime":"2026-10-21T09:00:00.0000000","timeZone":"UTC"},
           "location":{"displayName":"Microsoft Teams Meeting"},
           "body":{"contentType":"text","content":"Ponto de situação.\\n\\nhttps://teams.microsoft.com/l/meetup-join/xyz"},
           "organizer":{"emailAddress":{"name":"Rui Costa","address":"rui@exemplo.pt"}},
           "attendees":[{"emailAddress":{"name":"Hugo","address":"hugo@exemplo.pt"},"status":{"response":"tentativelyAccepted"}},
                        {"emailAddress":{"address":"ana@exemplo.pt"},"status":{"response":"notResponded"}}],
           "onlineMeeting":{"joinUrl":"https://teams.microsoft.com/l/meetup-join/xyz"}},
          {"id":"m2","subject":"Feriado","isAllDay":true,
           "start":{"dateTime":"2026-10-21T00:00:00.0000000","timeZone":"UTC"},
           "end":{"dateTime":"2026-10-22T00:00:00.0000000","timeZone":"UTC"}},
          {"id":"m3","subject":"Cancelado","isCancelled":true,
           "start":{"dateTime":"2026-10-21T10:00:00.0000000"},"end":{"dateTime":"2026-10-21T11:00:00.0000000"}}
        ]}
        """
        let eventos = try APICalendario.lerEventos(Data(json.utf8), calendario: calendarioMicrosoft, fuso: calendario)
        XCTAssertEqual(eventos.count, 2)

        let daily = eventos[0]
        XCTAssertEqual(daily.id, "040000008200E00074C5B7101A82E008")
        // 08:30 UTC = 09:30 em Lisboa (hora de verão).
        XCTAssertEqual(daily.inicio, data(2026, 10, 21, 9, 30))
        XCTAssertEqual(daily.fim, data(2026, 10, 21, 10, 0))
        XCTAssertEqual(daily.organizador, "Rui Costa")
        XCTAssertEqual(daily.participantes.map(\.nome), ["Hugo", "ana@exemplo.pt"])
        XCTAssertEqual(daily.participantes.map(\.resposta), [.talvez, .pendente])
        XCTAssertEqual(daily.notas, "Ponto de situação.\n\nhttps://teams.microsoft.com/l/meetup-join/xyz")
        XCTAssertEqual(daily.link?.host, "teams.microsoft.com")

        let feriado = eventos[1]
        XCTAssertTrue(feriado.diaInteiro)
        XCTAssertEqual(feriado.inicio, data(2026, 10, 21, 0))
        XCTAssertEqual(feriado.fim, data(2026, 10, 22, 0))
    }

    func testPedidoDeEventosDaMicrosoftEmUTCETextoSimples() {
        let pedido = APICalendario.pedidoEventos(calendarioMicrosoft, de: data(2026, 10, 21, 0), ate: data(2026, 10, 22, 0), token: "t")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "Authorization"), "Bearer t")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "Prefer"), "outlook.timezone=\"UTC\", outlook.body-content-type=\"text\"")
        let texto = pedido.url!.absoluteString
        XCTAssertTrue(texto.hasPrefix("https://graph.microsoft.com/v1.0/me/calendars/AAA/calendarView"))
        XCTAssertTrue(texto.contains("startDateTime=2026-10-20T23:00:00Z"))
    }

    func testPedidoDeEventosDaGoogleCodificaOCalendario() {
        let feriados = CalendarioExterno(id: "google:x", idFornecedor: "pt#holiday@group.v.calendar.google.com", nome: "Feriados",
                                         corHex: nil, fornecedor: .google)
        let pedido = APICalendario.pedidoEventos(feriados, de: data(2026, 10, 21, 0), ate: data(2026, 10, 22, 0), token: "t")
        let texto = pedido.url!.absoluteString
        XCTAssertTrue(texto.contains("/calendars/pt%23holiday@group.v.calendar.google.com/events"))
        XCTAssertTrue(texto.contains("singleEvents=true"))
    }

    // MARK: - Juntar com o EventKit

    func testMesmoEventoNasDuasFontesApareceUmaVez() {
        let inicio = data(2026, 10, 21, 9, 30)
        let locais = [("uid-1", inicio, "local 1"), ("uid-2", inicio, "local 2")]
        let externos = [("uid-1", inicio, "externo 1"), ("uid-3", inicio, "externo 3")]

        let juntos = JuntarEventos.juntar(
            locais: locais,
            externos: externos,
            chaveLocal: { ($0.0, $0.1) },
            chaveExterno: { ($0.0, $0.1) }
        )

        XCTAssertEqual(juntos.locais.map(\.2), ["local 2"])
        XCTAssertEqual(juntos.externos.map(\.2), ["externo 1", "externo 3"])
    }

    func testOcorrenciasDiferentesNaoSeJuntam() {
        let externos = [("daily", data(2026, 10, 21, 9, 30))]
        let locais = [("daily", data(2026, 10, 22, 9, 30))]
        let juntos = JuntarEventos.juntar(locais: locais, externos: externos, chaveLocal: { ($0.0, $0.1) }, chaveExterno: { ($0.0, $0.1) })
        XCTAssertEqual(juntos.locais.count, 1)
        XCTAssertEqual(juntos.externos.count, 1)
    }

    // MARK: - Texto simples

    func testTextoSimplesDeHTML() {
        XCTAssertEqual(TextoSimples.de("<p>Olá&nbsp;Ana</p><p>Até <a href=\"x\">amanhã</a></p>"), "Olá Ana\nAté amanhã")
        XCTAssertEqual(TextoSimples.de("Sem HTML  "), "Sem HTML")
        XCTAssertEqual(TextoSimples.de("a<br><br><br><br>b"), "a\n\nb")
    }
}
