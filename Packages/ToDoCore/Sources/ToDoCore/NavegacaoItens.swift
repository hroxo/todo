import Foundation

/// Ordem dos itens de uma lista e navegação entre eles no Detalhe (Melhoria 5): a mesma
/// ordem do ecrã Lista, primeiro os Fixados e depois os Ativos, cada grupo pela sua ordem.
public enum NavegacaoItens {
    /// Os itens ativos da lista, pela ordem em que aparecem no ecrã.
    public static func ordem(_ lista: Lista) -> [Item] {
        let ativos = lista.itensAtivos
        return ativos.filter(\.fixado) + ativos.filter { !$0.fixado }
    }

    /// O item a seguir, ou nil no último (ou se o item já não estiver na lista).
    public static func seguinte(de item: Item, em ordem: [Item]) -> Item? {
        guard let indice = ordem.firstIndex(where: { $0.id == item.id }), indice + 1 < ordem.count else { return nil }
        return ordem[indice + 1]
    }

    /// O item antes deste, ou nil no primeiro (ou se o item já não estiver na lista).
    public static func anterior(de item: Item, em ordem: [Item]) -> Item? {
        guard let indice = ordem.firstIndex(where: { $0.id == item.id }), indice > 0 else { return nil }
        return ordem[indice - 1]
    }
}
