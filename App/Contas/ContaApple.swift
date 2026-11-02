import AuthenticationServices
import Foundation
import Observation
import ToDoCore
import UIKit

/// Iniciar sessão com a Apple, opcional (DESIGN.md 7.20). Dá um identificador estável e
/// privado, o mesmo em qualquer aparelho: é o que ligará os dados à pessoa se um dia houver
/// outra forma de lá chegar (web, outra plataforma, um servidor). Não é o login que guarda os
/// dados: isso é o iCloud. A app funciona igual sem sessão.
///
/// Precisa da capacidade "Sign in with Apple" (conta Apple Developer paga), ligada no
/// `project.yml`. Fala só com o iOS: não há servidor nem dados a sair da app.
@MainActor
@Observable
final class ContaApple {
    enum Estado: Equatable {
        case semSessao
        case ligada(nome: String?, email: String?)
    }

    private(set) var estado: Estado = .semSessao
    /// Mensagem curta depois de uma tentativa falhada.
    var erro: String?

    private enum Chave {
        static let utilizador = "appleUtilizador"
        static let perfil = "applePerfil"
    }

    @ObservationIgnored private var observadores: [NSObjectProtocol] = []

    init() {
        guard !Demo.ativo else { return }
        carregar()
        observadores = [
            NotificationCenter.default.addObserver(
                forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.esquecer() }
            },
            // A app pode ficar dias suspensa: voltar a ela também conta como abrir.
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.carregar()
                    Task { await self?.verificar() }
                }
            },
        ]
        Task { await verificar() }
    }

    var ligada: Bool { estado != .semSessao }

    /// O nome para o perfil ("Hugo"), quando a Apple o deu.
    var nome: String? {
        if case .ligada(let nome, _) = estado { return nome }
        return nil
    }

    /// Ao abrir: se a pessoa revogou o acesso nos Ajustes, a sessão termina. Uma falha na
    /// verificação (sem rede, por exemplo) não diz nada sobre o acesso: a sessão fica.
    func verificar() async {
        guard let dados = Keychain.ler(conta: Chave.utilizador),
              let utilizador = String(data: dados, encoding: .utf8)
        else { return }
        let revogado = await withCheckedContinuation { continuacao in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: utilizador) { estado, falha in
                continuacao.resume(returning: falha == nil && (estado == .revoked || estado == .notFound))
            }
        }
        if revogado { esquecer() }
    }

    /// Os dados a pedir: o nome (para o perfil) e o email.
    func configurar(_ pedido: ASAuthorizationAppleIDRequest) {
        erro = nil
        pedido.requestedScopes = [.fullName, .email]
    }

    /// Resultado do botão "Iniciar sessão com a Apple". O nome e o email só vêm na primeira
    /// vez: guardam-se logo, e voltam quando a mesma conta volta a entrar.
    func concluir(_ resultado: Result<ASAuthorization, Error>) {
        switch resultado {
        case .success(let autorizacao):
            guard let credencial = autorizacao.credential as? ASAuthorizationAppleIDCredential else { return }
            let perfil = PerfilApple.depoisDeAutorizar(
                anterior: Self.perfilGuardado(),
                utilizador: credencial.user,
                nome: credencial.fullName?.givenName,
                email: credencial.email
            )
            Keychain.guardar(Data(credencial.user.utf8), conta: Chave.utilizador)
            if let dados = try? JSONEncoder().encode(perfil) {
                Keychain.guardar(dados, conta: Chave.perfil)
            }
            estado = .ligada(nome: perfil.nome, email: perfil.email)
            erro = nil
        case .failure(let falha):
            let codigo = (falha as? ASAuthorizationError)?.code
            guard codigo != .canceled else { return }
            // `.unknown` (1000): o iOS não conseguiu tratar do pedido, em geral porque não há
            // conta Apple com sessão iniciada neste aparelho.
            erro = codigo == .unknown
                ? "Não foi possível iniciar sessão. Confirma nos Ajustes que tens a tua conta Apple com sessão iniciada e tenta outra vez."
                : "Não foi possível iniciar sessão. Tenta outra vez."
        }
    }

    /// Termina a sessão neste iPhone. Os dados ficam; só deixa de haver ligação à conta. O
    /// perfil também fica: a Apple não volta a dar o nome e o email a quem volta a entrar.
    func terminar() {
        Keychain.apagar(conta: Chave.utilizador)
        estado = .semSessao
    }

    /// O acesso foi revogado: não fica nada da conta, e a Apple volta a dar o nome e o email
    /// na próxima autorização.
    private func esquecer() {
        terminar()
        Keychain.apagar(conta: Chave.perfil)
    }

    /// O estado a partir do Keychain.
    private func carregar() {
        guard Keychain.ler(conta: Chave.utilizador) != nil else {
            estado = .semSessao
            return
        }
        let perfil = Self.perfilGuardado()
        estado = .ligada(nome: perfil?.nome, email: perfil?.email)
    }

    private static func perfilGuardado() -> PerfilApple? {
        Keychain.ler(conta: Chave.perfil).flatMap { try? JSONDecoder().decode(PerfilApple.self, from: $0) }
    }
}
