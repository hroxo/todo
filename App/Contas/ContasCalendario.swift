import AuthenticationServices
import Foundation
import Observation
import SwiftUI
import ToDoCore
import UIKit

/// Contas Google e Outlook ligadas diretamente para ler o calendário (Melhoria 7). O login
/// abre a página do fornecedor (`ASWebAuthenticationSession`); os tokens ficam no Keychain.
/// Só lê: o calendário de cada conta e os eventos de hoje.
@MainActor
@Observable
final class ContasCalendario {
    /// O que fica guardado de cada conta.
    struct Conta: Codable, Equatable {
        var email: String?
        var tokens: Tokens
    }

    private(set) var contas: [Fornecedor: Conta] = [:]
    private(set) var calendarios: [CalendarioExterno] = []
    private(set) var eventos: [EventoExterno] = []
    /// Fornecedor a ligar, para a interface mostrar o progresso.
    private(set) var aLigar: Fornecedor?
    private(set) var erro: String?

    @ObservationIgnored private var sessao: ASWebAuthenticationSession?
    @ObservationIgnored private let contexto = ContextoApresentacao()

    init() {
        guard !Demo.ativo else { return }
        for fornecedor in Fornecedor.allCases {
            if let dados = Keychain.ler(conta: fornecedor.rawValue),
               let conta = try? JSONDecoder().decode(Conta.self, from: dados) {
                contas[fornecedor] = conta
            }
        }
    }

    /// A configuração do fornecedor, ou nil se a app ainda não foi registada nele.
    static func configuracao(_ fornecedor: Fornecedor) -> ConfiguracaoOAuth? {
        switch fornecedor {
        case .google: RegistoApps.googleClientId.isEmpty ? nil : .google(clientId: RegistoApps.googleClientId)
        case .microsoft: RegistoApps.microsoftClientId.isEmpty ? nil : .microsoft(clientId: RegistoApps.microsoftClientId)
        }
    }

    var temContas: Bool { !contas.isEmpty }

    // MARK: - Ligar e desligar

    func ligar(_ fornecedor: Fornecedor) async {
        guard let config = Self.configuracao(fornecedor) else { return }
        erro = nil
        aLigar = fornecedor
        defer { aLigar = nil }
        do {
            let pkce = PKCE.gerar()
            let estado = PKCE.aleatorio(bytes: 16)
            let retorno = try await iniciarSessao(OAuth.urlAutorizacao(config, pkce: pkce, estado: estado), esquema: config.esquemaRetorno)
            let codigo = try OAuth.codigo(deRetorno: retorno, estado: estado)
            let (dados, _) = try await URLSession.shared.data(for: OAuth.pedidoToken(config, codigo: codigo, pkce: pkce))
            let tokens = try OAuth.lerTokens(dados, agora: .now)
            var conta = Conta(email: nil, tokens: tokens)
            conta.email = try? await email(fornecedor, token: tokens.acesso)
            guardar(conta, fornecedor)
            await atualizar()
        } catch let erro as ASWebAuthenticationSessionError where erro.code == .canceledLogin {
            // O utilizador fechou a página: não é um erro.
        } catch {
            self.erro = "Não foi possível ligar a conta \(fornecedor.nome). \(Self.descricao(error))"
        }
    }

    func desligar(_ fornecedor: Fornecedor) {
        contas[fornecedor] = nil
        Keychain.apagar(conta: fornecedor.rawValue)
        calendarios.removeAll { $0.fornecedor == fornecedor }
        eventos.removeAll { evento in !calendarios.contains { $0.id == evento.calendarioId } }
    }

    // MARK: - Ler

    /// Os calendários de cada conta e os eventos de hoje dos que não estão escondidos.
    func atualizar(ocultos: Set<String> = []) async {
        guard !Demo.ativo else { return }
        let hoje = Calendar.current.startOfDay(for: .now)
        let amanha = Calendar.current.date(byAdding: .day, value: 1, to: hoje)!
        var novosCalendarios: [CalendarioExterno] = []
        var novosEventos: [EventoExterno] = []
        for fornecedor in Fornecedor.allCases where contas[fornecedor] != nil {
            do {
                let token = try await tokenValido(fornecedor)
                let (dados, _) = try await URLSession.shared.data(for: APICalendario.pedidoCalendarios(fornecedor, token: token))
                let lista = try APICalendario.lerCalendarios(dados, fornecedor: fornecedor)
                novosCalendarios += lista
                for calendario in lista where !ocultos.contains(calendario.id) {
                    let pedido = APICalendario.pedidoEventos(calendario, de: hoje, ate: amanha, token: token)
                    let (dados, _) = try await URLSession.shared.data(for: pedido)
                    novosEventos += (try? APICalendario.lerEventos(dados, calendario: calendario)) ?? []
                }
            } catch {
                // Sem rede, ou a sessão expirou: fica o que já havia desta conta.
                novosCalendarios += calendarios.filter { $0.fornecedor == fornecedor }
                novosEventos += eventos.filter { evento in calendarios.contains { $0.id == evento.calendarioId && $0.fornecedor == fornecedor } }
                if case ErroOAuth.recusado = error {
                    erro = "A sessão \(fornecedor.nome) expirou. Volta a ligar a conta em Definições › Calendário."
                }
            }
        }
        calendarios = novosCalendarios
        eventos = novosEventos
    }

    /// Um token de acesso válido, renovado se for preciso.
    private func tokenValido(_ fornecedor: Fornecedor) async throws -> String {
        guard var conta = contas[fornecedor], let config = Self.configuracao(fornecedor) else {
            throw ErroOAuth.respostaInvalida
        }
        if conta.tokens.valido(agora: .now) { return conta.tokens.acesso }
        guard let renovacao = conta.tokens.renovacao else { throw ErroOAuth.recusado("sem token de renovação") }
        let (dados, _) = try await URLSession.shared.data(for: OAuth.pedidoRenovacao(config, renovacao: renovacao))
        conta.tokens = conta.tokens.renovado(com: try OAuth.lerTokens(dados, agora: .now))
        guardar(conta, fornecedor)
        return conta.tokens.acesso
    }

    private func email(_ fornecedor: Fornecedor, token: String) async throws -> String? {
        struct Perfil: Decodable {
            let email: String?
            let mail: String?
            let userPrincipalName: String?
        }
        let url = switch fornecedor {
        case .google: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!
        case .microsoft: URL(string: "https://graph.microsoft.com/v1.0/me")!
        }
        var pedido = URLRequest(url: url)
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (dados, _) = try await URLSession.shared.data(for: pedido)
        let perfil = try JSONDecoder().decode(Perfil.self, from: dados)
        return perfil.email ?? perfil.mail ?? perfil.userPrincipalName
    }

    private func guardar(_ conta: Conta, _ fornecedor: Fornecedor) {
        contas[fornecedor] = conta
        if let dados = try? JSONEncoder().encode(conta) {
            Keychain.guardar(dados, conta: fornecedor.rawValue)
        }
    }

    // MARK: - Sessão de login

    private func iniciarSessao(_ url: URL, esquema: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuacao in
            let sessao = ASWebAuthenticationSession(url: url, callback: .customScheme(esquema)) { retorno, erro in
                if let retorno {
                    continuacao.resume(returning: retorno)
                } else {
                    continuacao.resume(throwing: erro ?? ErroOAuth.semCodigo)
                }
            }
            sessao.presentationContextProvider = contexto
            sessao.prefersEphemeralWebBrowserSession = false
            self.sessao = sessao
            sessao.start()
        }
    }

    private static func descricao(_ erro: Error) -> String {
        switch erro {
        case ErroOAuth.recusado(let motivo): "O fornecedor recusou (\(motivo))."
        case ErroOAuth.estadoInvalido: "A resposta não corresponde ao pedido."
        case is URLError: "Sem ligação à internet?"
        default: ""
        }
    }

    /// Mostra a página de login por cima da janela da app.
    private final class ContextoApresentacao: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .first ?? ASPresentationAnchor()
            }
        }
    }
}

extension Color {
    /// "#4285F4" ou "4285F4".
    init?(hex: String) {
        let limpo = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard limpo.count == 6, let valor = UInt32(limpo, radix: 16) else { return nil }
        self.init(
            red: Double((valor >> 16) & 0xFF) / 255,
            green: Double((valor >> 8) & 0xFF) / 255,
            blue: Double(valor & 0xFF) / 255
        )
    }
}
