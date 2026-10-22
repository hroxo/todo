import Foundation
import Security

/// Guarda os tokens das contas ligadas no Keychain do iPhone (nunca no UserDefaults nem no
/// backup JSON).
enum Keychain {
    private static let servico = "com.hugo.todo.contas"

    static func guardar(_ dados: Data, conta: String) {
        let procura = consulta(conta)
        let atualizacao: [String: Any] = [kSecValueData as String: dados]
        if SecItemUpdate(procura as CFDictionary, atualizacao as CFDictionary) == errSecItemNotFound {
            var novo = procura
            novo[kSecValueData as String] = dados
            novo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(novo as CFDictionary, nil)
        }
    }

    static func ler(conta: String) -> Data? {
        var procura = consulta(conta)
        procura[kSecReturnData as String] = true
        procura[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: CFTypeRef?
        guard SecItemCopyMatching(procura as CFDictionary, &resultado) == errSecSuccess else { return nil }
        return resultado as? Data
    }

    static func apagar(conta: String) {
        SecItemDelete(consulta(conta) as CFDictionary)
    }

    private static func consulta(_ conta: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
        ]
    }
}
