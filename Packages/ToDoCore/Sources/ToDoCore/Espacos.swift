import Foundation

/// Regras dos espaços no Início e da ligação entre calendários e espaços
/// (especificação 4.4 e 4.7).
public enum Espacos {
    /// Espaços por página no Início quando há mais de 4.
    public static let porPagina = 4

    /// Divide os elementos da grelha (espaços e, no fim, "Nova lista") em páginas de 4.
    /// Até 4 espaços há uma só página com tudo.
    public static func paginas<T>(_ elementos: [T], espacos: Int) -> [[T]] {
        guard espacos > porPagina else { return [elementos] }
        return stride(from: 0, to: elementos.count, by: porPagina).map {
            Array(elementos[$0..<min($0 + porPagina, elementos.count)])
        }
    }

    /// "Espaços 1–4 de 6".
    public static func rotuloPagina(_ pagina: Int, espacos: Int) -> String {
        let primeiro = pagina * porPagina + 1
        let ultimo = min((pagina + 1) * porPagina, espacos)
        return primeiro == ultimo ? "Espaço \(primeiro) de \(espacos)" : "Espaços \(primeiro)–\(ultimo) de \(espacos)"
    }

    /// Associação automática ao ligar o calendário: cada calendário cujo nome coincide com o
    /// de um espaço (sem contar maiúsculas nem acentos) fica nesse espaço. Devolve
    /// identificador do calendário → identificador do espaço.
    public static func associarPorNome(
        calendarios: [(id: String, titulo: String)],
        espacos: [(id: UUID, nome: String)]
    ) -> [String: UUID] {
        var resultado: [String: UUID] = [:]
        for calendario in calendarios {
            let chave = normalizar(calendario.titulo)
            if let espaco = espacos.first(where: { normalizar($0.nome) == chave }) {
                resultado[calendario.id] = espaco.id
            }
        }
        return resultado
    }

    static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_PT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
