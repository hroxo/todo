import Foundation
import SwiftData

public enum ErroTarefas: Error, Equatable {
    case textoVazio
    /// Só há um nível de subtópicos (especificação 3).
    case subtopicoDeSubtopico
}

/// Regras de produto sobre listas e itens (especificação 4). A interface chama só isto;
/// não altera os modelos diretamente. Não grava: o contexto da app grava sozinho.
public final class Tarefas {
    public static let listasIniciais: [(nome: String, cor: CorLista)] = [
        ("Trabalho", .azul),
        ("Pessoal", .verde),
    ]

    public let contexto: ModelContext
    public let relogio: Relogio
    public let calendario: Calendar
    /// Passa a vir das Definições no M2/M3.
    public var diasExpiracao = 3

    public init(contexto: ModelContext, relogio: Relogio = RelogioSistema(), calendario: Calendar = .current) {
        self.contexto = contexto
        self.relogio = relogio
        self.calendario = calendario
    }

    // MARK: - Listas

    public func listas() throws -> [Lista] {
        try contexto.fetch(FetchDescriptor<Lista>(sortBy: [SortDescriptor(\.ordem)]))
    }

    /// Cria Trabalho e Pessoal se ainda não houver listas. Devolve verdadeiro se criou.
    @discardableResult
    public func criarListasIniciaisSeVazio() throws -> Bool {
        guard try contexto.fetchCount(FetchDescriptor<Lista>()) == 0 else { return false }
        for (ordem, inicial) in Self.listasIniciais.enumerated() {
            contexto.insert(Lista(nome: inicial.nome, cor: inicial.cor, ordem: ordem))
        }
        return true
    }

    @discardableResult
    public func criarLista(nome: String, cor: CorLista) throws -> Lista {
        let nome = try limpo(nome)
        let ordem = (try listas().map(\.ordem).max() ?? -1) + 1
        let lista = Lista(nome: nome, cor: cor, ordem: ordem)
        contexto.insert(lista)
        return lista
    }

    public func editar(_ lista: Lista, nome: String, cor: CorLista) throws {
        lista.nome = try limpo(nome)
        lista.cor = cor
    }

    /// Grava a ordem pela posição no array recebido.
    public func reordenar(_ listas: [Lista]) {
        for (ordem, lista) in listas.enumerated() {
            lista.ordem = ordem
        }
    }

    /// Quantos itens principais (em qualquer estado) são apagados com a lista.
    public func contarItens(de lista: Lista) -> Int {
        lista.itens.count
    }

    public func apagar(_ lista: Lista) {
        for item in lista.itens {
            apagar(item)
        }
        contexto.delete(lista)
    }

    // MARK: - Itens

    @discardableResult
    public func criarItem(titulo: String, em lista: Lista, tipo: TipoItem = .tarefa) throws -> Item {
        let titulo = try limpo(titulo)
        let agora = relogio.agora
        let ordem = (lista.itens.map(\.ordem).max() ?? -1) + 1
        let item = Item(titulo: titulo, tipo: tipo, criadoEm: agora, ordem: ordem)
        contexto.insert(item)
        item.lista = lista
        item.expiraEm = daquiA(diasExpiracao, desde: agora)
        return item
    }

    @discardableResult
    public func adicionarSubtopico(titulo: String, a pai: Item) throws -> Item {
        guard !pai.ehSubtopico else { throw ErroTarefas.subtopicoDeSubtopico }
        let titulo = try limpo(titulo)
        let ordem = (pai.subtopicos.map(\.ordem).max() ?? -1) + 1
        let sub = Item(titulo: titulo, tipo: .tarefa, criadoEm: relogio.agora, ordem: ordem)
        contexto.insert(sub)
        sub.pai = pai
        registarAcao(em: pai)
        return sub
    }

    public func editarTitulo(_ item: Item, para titulo: String) throws {
        item.titulo = try limpo(titulo)
        registarAcao(em: item)
    }

    /// Uma ação reinicia a contagem de expiração do item principal (especificação 4.1 e 4.3).
    public func registarAcao(em item: Item) {
        let alvo = item.pai ?? item
        let agora = relogio.agora
        alvo.ultimaAcaoEm = agora
        if alvo.estado == .ativo && !alvo.fixado {
            alvo.expiraEm = daquiA(diasExpiracao, desde: agora)
        }
    }

    public func concluir(_ item: Item) {
        item.estado = .concluido
        item.concluidoEm = relogio.agora
        if item.ehSubtopico {
            registarAcao(em: item)
        } else {
            item.expiraEm = nil
        }
    }

    public func reabrir(_ item: Item) {
        item.estado = .ativo
        item.concluidoEm = nil
        registarAcao(em: item)
    }

    /// Marca um subtópico como feito ou por fazer. Devolve verdadeiro quando ficaram todos
    /// feitos e a app deve sugerir concluir o item principal; nunca o conclui sozinha
    /// (critério 5).
    @discardableResult
    public func alternarSubtopico(_ sub: Item) -> Bool {
        guard let pai = sub.pai else { return false }
        if sub.estado == .concluido {
            reabrir(sub)
            return false
        }
        concluir(sub)
        return pai.estado == .ativo && pai.subtopicos.allSatisfy { $0.estado == .concluido }
    }

    public func definirFixado(_ item: Item, _ fixado: Bool) {
        guard !item.ehSubtopico, item.fixado != fixado else { return }
        item.fixado = fixado
        if fixado {
            item.expiraEm = nil
        } else {
            registarAcao(em: item)
        }
    }

    public func mover(_ item: Item, para lista: Lista) {
        guard !item.ehSubtopico, item.lista != lista else { return }
        item.ordem = (lista.itens.map(\.ordem).max() ?? -1) + 1
        item.lista = lista
        registarAcao(em: item)
    }

    /// Nota rápida ⇄ tarefa.
    public func converter(_ item: Item) {
        guard !item.ehSubtopico else { return }
        item.tipo = item.tipo == .tarefa ? .notaRapida : .tarefa
        registarAcao(em: item)
    }

    /// Apaga o item e todos os subtópicos (critério 6). Apagar um subtópico conta como
    /// ação no item principal.
    public func apagar(_ item: Item) {
        if let pai = item.pai {
            registarAcao(em: pai)
        }
        for sub in item.subtopicos {
            contexto.delete(sub)
        }
        contexto.delete(item)
    }

    // MARK: - Auxiliares

    private func daquiA(_ dias: Int, desde data: Date) -> Date {
        calendario.date(byAdding: .day, value: dias, to: data)!
    }

    private func limpo(_ texto: String) throws -> String {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { throw ErroTarefas.textoVazio }
        return limpo
    }
}
