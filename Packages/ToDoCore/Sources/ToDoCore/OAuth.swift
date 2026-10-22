import CryptoKit
import Foundation

/// Contas ligadas diretamente para ler o calendário (Melhoria 7): Google Calendar e Outlook
/// (Microsoft Graph), só leitura. Sem SDKs: OAuth 2.0 com PKCE, como numa app nativa, sem
/// segredo de cliente.
public enum Fornecedor: String, CaseIterable, Codable, Sendable {
    case google, microsoft

    public var nome: String {
        switch self {
        case .google: "Google"
        case .microsoft: "Outlook"
        }
    }
}

/// O registo da app num fornecedor: identificador de cliente, endereços e permissões.
public struct ConfiguracaoOAuth: Equatable, Sendable {
    public let fornecedor: Fornecedor
    public let clientId: String
    public let autorizacao: URL
    public let token: URL
    /// Para onde o fornecedor devolve o código; o esquema volta à app.
    public let redirecionamento: String
    public let ambitos: [String]

    /// O esquema do endereço de retorno, para o `ASWebAuthenticationSession`.
    public var esquemaRetorno: String {
        String(redirecionamento.prefix { $0 != ":" })
    }

    /// Google, com um cliente do tipo iOS: o retorno é o identificador do cliente ao
    /// contrário ("com.googleusercontent.apps.123-abc:/oauth2redirect").
    public static func google(clientId: String) -> ConfiguracaoOAuth {
        let invertido = clientId
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
        return ConfiguracaoOAuth(
            fornecedor: .google,
            clientId: clientId,
            autorizacao: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            token: URL(string: "https://oauth2.googleapis.com/token")!,
            redirecionamento: "\(invertido):/oauth2redirect",
            ambitos: ["openid", "email", "https://www.googleapis.com/auth/calendar.readonly"]
        )
    }

    /// Microsoft (contas pessoais e de trabalho), com o retorno registado no Azure como
    /// "Mobile and desktop applications".
    public static func microsoft(clientId: String, redirecionamento: String = "todo-hugo://auth") -> ConfiguracaoOAuth {
        ConfiguracaoOAuth(
            fornecedor: .microsoft,
            clientId: clientId,
            autorizacao: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            token: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
            redirecionamento: redirecionamento,
            ambitos: ["openid", "email", "offline_access", "User.Read", "Calendars.Read"]
        )
    }
}

/// Proof Key for Code Exchange (RFC 7636), método S256.
public struct PKCE: Equatable, Sendable {
    public let verificador: String
    public let desafio: String

    public init(verificador: String) {
        self.verificador = verificador
        desafio = Self.base64URL(Data(SHA256.hash(data: Data(verificador.utf8))))
    }

    /// 32 bytes aleatórios em base64url: 43 caracteres, dentro do que o RFC pede.
    public static func gerar() -> PKCE {
        PKCE(verificador: aleatorio())
    }

    public static func aleatorio(bytes: Int = 32) -> String {
        var gerador = SystemRandomNumberGenerator()
        return base64URL(Data((0..<bytes).map { _ in UInt8.random(in: .min ... .max, using: &gerador) }))
    }

    static func base64URL(_ dados: Data) -> String {
        dados.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Tokens de uma conta. O de acesso dura cerca de uma hora; o de renovação dá novos.
public struct Tokens: Codable, Equatable, Sendable {
    public var acesso: String
    public var renovacao: String?
    public var expiraEm: Date

    public init(acesso: String, renovacao: String?, expiraEm: Date) {
        self.acesso = acesso
        self.renovacao = renovacao
        self.expiraEm = expiraEm
    }

    /// Com um minuto de folga, para não falhar a meio de um pedido.
    public func valido(agora: Date) -> Bool {
        expiraEm.timeIntervalSince(agora) > 60
    }

    /// Junta uma renovação: a Google não devolve outro token de renovação, e aí fica o antigo.
    public func renovado(com novos: Tokens) -> Tokens {
        Tokens(acesso: novos.acesso, renovacao: novos.renovacao ?? renovacao, expiraEm: novos.expiraEm)
    }
}

public enum ErroOAuth: Error, Equatable {
    /// O utilizador recusou, ou o fornecedor devolveu um erro ("access_denied").
    case recusado(String)
    /// O `state` não coincide: o retorno não é deste pedido.
    case estadoInvalido
    case semCodigo
    case respostaInvalida
}

/// Os passos do OAuth que não precisam de rede, para serem testados.
public enum OAuth {
    /// Página de início de sessão do fornecedor.
    public static func urlAutorizacao(_ config: ConfiguracaoOAuth, pkce: PKCE, estado: String) -> URL {
        var partes = URLComponents(url: config.autorizacao, resolvingAgainstBaseURL: false)!
        var parametros = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirecionamento),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.ambitos.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: pkce.desafio),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: estado),
        ]
        switch config.fornecedor {
        case .google:
            // Sem isto a Google não devolve o token de renovação.
            parametros.append(URLQueryItem(name: "access_type", value: "offline"))
            parametros.append(URLQueryItem(name: "prompt", value: "consent"))
        case .microsoft:
            parametros.append(URLQueryItem(name: "response_mode", value: "query"))
            parametros.append(URLQueryItem(name: "prompt", value: "select_account"))
        }
        partes.queryItems = parametros
        return partes.url!
    }

    /// O código de autorização do endereço de retorno.
    public static func codigo(deRetorno url: URL, estado: String) throws -> String {
        let parametros = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func valor(_ nome: String) -> String? { parametros.first { $0.name == nome }?.value }
        if let erro = valor("error") {
            throw ErroOAuth.recusado(erro)
        }
        guard valor("state") == estado else { throw ErroOAuth.estadoInvalido }
        guard let codigo = valor("code"), !codigo.isEmpty else { throw ErroOAuth.semCodigo }
        return codigo
    }

    /// Troca o código pelos tokens.
    public static func pedidoToken(_ config: ConfiguracaoOAuth, codigo: String, pkce: PKCE) -> URLRequest {
        formulario(config.token, [
            "client_id": config.clientId,
            "grant_type": "authorization_code",
            "code": codigo,
            "redirect_uri": config.redirecionamento,
            "code_verifier": pkce.verificador,
        ])
    }

    /// Pede um token de acesso novo com o de renovação.
    public static func pedidoRenovacao(_ config: ConfiguracaoOAuth, renovacao: String) -> URLRequest {
        var campos = [
            "client_id": config.clientId,
            "grant_type": "refresh_token",
            "refresh_token": renovacao,
        ]
        if config.fornecedor == .microsoft {
            campos["scope"] = config.ambitos.joined(separator: " ")
        }
        return formulario(config.token, campos)
    }

    /// Lê a resposta do endereço de tokens.
    public static func lerTokens(_ dados: Data, agora: Date) throws -> Tokens {
        struct Resposta: Decodable {
            let access_token: String?
            let refresh_token: String?
            let expires_in: Double?
            let error: String?
        }
        guard let resposta = try? JSONDecoder().decode(Resposta.self, from: dados) else {
            throw ErroOAuth.respostaInvalida
        }
        if let erro = resposta.error { throw ErroOAuth.recusado(erro) }
        guard let acesso = resposta.access_token else { throw ErroOAuth.respostaInvalida }
        return Tokens(
            acesso: acesso,
            renovacao: resposta.refresh_token,
            expiraEm: agora.addingTimeInterval(resposta.expires_in ?? 3600)
        )
    }

    private static func formulario(_ url: URL, _ campos: [String: String]) -> URLRequest {
        var pedido = URLRequest(url: url)
        pedido.httpMethod = "POST"
        pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // Ordem fixa, para os testes e para os registos serem legíveis.
        let corpo = campos.keys.sorted().map { chave in
            "\(chave)=\(codificar(campos[chave]!))"
        }
        pedido.httpBody = Data(corpo.joined(separator: "&").utf8)
        return pedido
    }

    /// Codificação de formulário: só letras, números e `-._~` ficam como estão.
    static func codificar(_ texto: String) -> String {
        let permitidos = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return texto.addingPercentEncoding(withAllowedCharacters: permitidos) ?? texto
    }
}
