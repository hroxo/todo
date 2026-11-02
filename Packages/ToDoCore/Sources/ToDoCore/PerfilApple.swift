import Foundation

/// O nome e o email de quem iniciou sessão com a Apple (DESIGN.md 7.20). A Apple só os dá na
/// primeira autorização; nas seguintes vêm vazios. Só valem para a conta a que pertencem.
public struct PerfilApple: Codable, Equatable, Sendable {
    public let utilizador: String
    public let nome: String?
    public let email: String?

    public init(utilizador: String, nome: String? = nil, email: String? = nil) {
        self.utilizador = utilizador
        self.nome = nome
        self.email = email
    }

    /// O perfil a guardar depois de uma autorização: o que a Apple deu agora ou, se não deu, o
    /// que já havia desta conta. O perfil de outra conta não passa para esta.
    public static func depoisDeAutorizar(
        anterior: PerfilApple?,
        utilizador: String,
        nome: String?,
        email: String?
    ) -> PerfilApple {
        let conhecido = anterior?.utilizador == utilizador ? anterior : nil
        return PerfilApple(
            utilizador: utilizador,
            nome: preenchido(nome) ?? conhecido?.nome,
            email: preenchido(email) ?? conhecido?.email
        )
    }

    private static func preenchido(_ texto: String?) -> String? {
        guard let limpo = texto?.trimmingCharacters(in: .whitespacesAndNewlines), !limpo.isEmpty else { return nil }
        return limpo
    }
}
