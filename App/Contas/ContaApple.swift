import AuthenticationServices
import Foundation
import Observation

/// Iniciar sessão com a Apple, opcional (DESIGN.md 7.20). Dá um identificador estável e
/// privado, o mesmo em qualquer aparelho: é o que ligará os dados à pessoa se um dia houver
/// outra forma de lá chegar (web, outra plataforma, um servidor). Não é o login que guarda os
/// dados: isso é o iCloud. A app funciona igual sem sessão.
///
/// Precisa da capacidade "Sign in with Apple" (conta Apple Developer paga); sem ela, o iOS
/// recusa o pedido e a app explica-o.
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
        static let nome = "appleNome"
        static let email = "appleEmail"
    }

    @ObservationIgnored private var observador: NSObjectProtocol?

    init() {
        guard !Demo.ativo else { return }
        if Keychain.ler(conta: Chave.utilizador) != nil {
            estado = .ligada(nome: Self.texto(Chave.nome), email: Self.texto(Chave.email))
        }
        observador = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.terminar() }
        }
        Task { await verificar() }
    }

    var ligada: Bool { estado != .semSessao }

    /// O nome para o perfil ("Hugo"), quando a Apple o deu.
    var nome: String? {
        if case .ligada(let nome, _) = estado { return nome }
        return nil
    }

    /// Ao abrir: se a pessoa revogou o acesso nos Ajustes, a sessão termina.
    func verificar() async {
        guard let dados = Keychain.ler(conta: Chave.utilizador),
              let utilizador = String(data: dados, encoding: .utf8)
        else { return }
        let estadoApple = await withCheckedContinuation { continuacao in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: utilizador) { estado, _ in
                continuacao.resume(returning: estado)
            }
        }
        if estadoApple == .revoked || estadoApple == .notFound {
            terminar()
        }
    }

    /// Os dados a pedir: o nome (para o perfil) e o email.
    func configurar(_ pedido: ASAuthorizationAppleIDRequest) {
        pedido.requestedScopes = [.fullName, .email]
    }

    /// Resultado do botão "Iniciar sessão com a Apple". O nome e o email só vêm na primeira
    /// vez: guardam-se logo.
    func concluir(_ resultado: Result<ASAuthorization, Error>) {
        switch resultado {
        case .success(let autorizacao):
            guard let credencial = autorizacao.credential as? ASAuthorizationAppleIDCredential else { return }
            Keychain.guardar(Data(credencial.user.utf8), conta: Chave.utilizador)
            if let nome = credencial.fullName?.givenName, !nome.isEmpty {
                UserDefaults.standard.set(nome, forKey: Chave.nome)
            }
            if let email = credencial.email {
                UserDefaults.standard.set(email, forKey: Chave.email)
            }
            estado = .ligada(nome: Self.texto(Chave.nome), email: Self.texto(Chave.email))
            erro = nil
        case .failure(let falha):
            let codigo = (falha as? ASAuthorizationError)?.code
            guard codigo != .canceled else { return }
            // Sem a capacidade "Sign in with Apple" (Apple ID gratuito), o iOS falha com
            // `.unknown` (1000).
            erro = codigo == .unknown
                ? "O início de sessão com a Apple fica disponível quando a ToDo tiver a conta Apple Developer."
                : "Não foi possível iniciar sessão. Tenta outra vez."
        }
    }

    /// Termina a sessão neste iPhone. Os dados ficam; só deixa de haver ligação à conta.
    func terminar() {
        Keychain.apagar(conta: Chave.utilizador)
        UserDefaults.standard.removeObject(forKey: Chave.nome)
        UserDefaults.standard.removeObject(forKey: Chave.email)
        estado = .semSessao
    }

    private static func texto(_ chave: String) -> String? {
        UserDefaults.standard.string(forKey: chave)
    }
}
