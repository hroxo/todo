import Foundation
import SwiftData

public enum ErroTarefas: Error, Equatable {
    case textoVazio
    /// Só há um nível de subtópicos (especificação 3).
    case subtopicoDeSubtopico
    /// No máximo `Tarefas.maxFotos` fotos por item (DESIGN.md 7.7).
    case limiteFotos
    /// No máximo `Tarefas.maxListas` espaços (especificação 4.4).
    case limiteListas
}

/// Notificação a agendar para um item que vai expirar (especificação 6).
public struct Aviso: Equatable, Sendable {
    public let itemId: UUID
    public let titulo: String
    public let data: Date
    /// O resto serve para o texto da notificação (DESIGN.md 7.16).
    public var lista: String?
    public var expiraEm: Date
    public var subtopicosPorFazer = 0
    public var ultimaAcaoEm: Date
}

/// Estado de um item antes de ser concluído, para o poder anular.
public struct AntesDeConcluir: Equatable, Sendable {
    public let estado: EstadoItem
    public let expiraEm: Date?
    public let ultimaAcaoEm: Date
}

/// Regras de produto sobre listas e itens (especificação 4). A interface chama só isto;
/// não altera os modelos diretamente. Não grava: o contexto da app grava sozinho.
public final class Tarefas {
    public static let listasIniciais: [(nome: String, cor: CorLista, icone: String)] = [
        ("Trabalho", .azul, "briefcase.fill"),
        ("Pessoal", .roxo, "person.fill"),
    ]
    public static let maxFotos = 4
    /// Máximo de espaços (listas); com mais de 4, o Início mostra páginas com setas.
    public static let maxListas = 8
    /// A descrição é curta: 2 a 3 linhas no ecrã.
    public static let maxDescricao = 200
    /// O iOS guarda no máximo 64 notificações pendentes.
    public static let maxAvisos = 60

    public let contexto: ModelContext
    public let relogio: Relogio
    public let calendario: Calendar
    public var definicoes: Definicoes

    public init(
        contexto: ModelContext,
        relogio: Relogio = RelogioSistema(),
        calendario: Calendar = .current,
        definicoes: Definicoes = .carregar()
    ) {
        self.contexto = contexto
        self.relogio = relogio
        self.calendario = calendario
        self.definicoes = definicoes
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
            contexto.insert(Lista(nome: inicial.nome, cor: inicial.cor, ordem: ordem, icone: inicial.icone))
        }
        return true
    }

    @discardableResult
    public func criarLista(
        nome: String,
        cor: CorLista,
        icone: String = IconesLista.padrao,
        emoji: String? = nil,
        tipo: TipoLista = .normal
    ) throws -> Lista {
        let nome = try limpo(nome)
        let existentes = try listas()
        guard existentes.count < Self.maxListas else { throw ErroTarefas.limiteListas }
        let ordem = (existentes.map(\.ordem).max() ?? -1) + 1
        let lista = Lista(nome: nome, cor: cor, ordem: ordem, icone: icone, emoji: emojiLimpo(emoji))
        lista.tipo = tipo
        contexto.insert(lista)
        return lista
    }

    public func editar(_ lista: Lista, nome: String, cor: CorLista, icone: String, emoji: String?) throws {
        lista.nome = try limpo(nome)
        lista.cor = cor
        lista.icone = icone
        lista.emoji = emojiLimpo(emoji)
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
        aApagarLista = true
        defer { aApagarLista = false }
        for item in lista.itens {
            apagar(item)
        }
        contexto.delete(lista)
    }

    /// A lista inteira sai: os itens apagam-se mesmo, sem lápides.
    private var aApagarLista = false

    // MARK: - Itens

    @discardableResult
    public func criarItem(titulo: String, em lista: Lista, tipo: TipoItem = .tarefa) throws -> Item {
        let titulo = try limpo(titulo)
        let agora = relogio.agora
        let ordem = (lista.itens.map(\.ordem).max() ?? -1) + 1
        let item = Item(titulo: titulo, tipo: tipo, criadoEm: agora, ordem: ordem)
        contexto.insert(item)
        item.lista = lista
        item.alteradoEm = agora
        // Nas listas de compras nada expira (DESIGN.md 7.15).
        if !lista.ehCompras {
            item.expiraEm = daquiA(definicoes.diasExpiracao, desde: agora)
        }
        return item
    }

    /// Ponto criado a partir de um evento do calendário (especificação 4.7): ativo, com o
    /// título do evento e a hora (e o local) na descrição. Guarda o evento de origem
    /// (Melhoria 6.4) para o "+" só funcionar uma vez por evento.
    @discardableResult
    public func criarPontoDeEvento(
        titulo: String,
        inicio: Date,
        fim: Date,
        diaInteiro: Bool,
        detalhe: String?,
        eventoId: String? = nil,
        em lista: Lista
    ) throws -> Item {
        let item = try criarItem(titulo: titulo, em: lista)
        if let eventoId {
            item.eventoId = eventoId
            item.eventoInicio = inicio
        }
        var partes = ["Calendário: " + (diaInteiro ? "todo o dia" : Formatos.intervalo(inicio, fim, calendario: calendario))]
        if let detalhe, !detalhe.isEmpty {
            partes.append(detalhe)
        }
        definirNota(item, partes.joined(separator: " · "))
        return item
    }

    /// O ponto que já foi criado a partir desta ocorrência de um evento, se ainda contar
    /// (Melhoria 6.4): ativo ou concluído. Se foi apagado ou expirou, o evento pode voltar a
    /// ser adicionado.
    public func pontoDeEvento(id eventoId: String, inicio: Date) throws -> Item? {
        let ativo = EstadoItem.ativo.rawValue
        let concluido = EstadoItem.concluido.rawValue
        let pedido = FetchDescriptor<Item>(predicate: #Predicate {
            $0.eventoId == eventoId && ($0.estadoRaw == ativo || $0.estadoRaw == concluido)
        })
        return Self.pontoDeEvento(em: try contexto.fetch(pedido), id: eventoId, inicio: inicio)
    }

    /// A mesma regra sobre itens já carregados (a interface usa-a com uma `@Query`).
    public static func pontoDeEvento(em itens: [Item], id eventoId: String, inicio: Date) -> Item? {
        itens.first {
            $0.eventoId == eventoId && $0.eventoInicio == inicio && ($0.estado == .ativo || $0.estado == .concluido)
        }
    }

    @discardableResult
    public func adicionarSubtopico(titulo: String, a pai: Item) throws -> Item {
        guard !pai.ehSubtopico else { throw ErroTarefas.subtopicoDeSubtopico }
        let titulo = try limpo(titulo)
        let ordem = (pai.subtopicos.map(\.ordem).max() ?? -1) + 1
        let sub = Item(titulo: titulo, tipo: .tarefa, criadoEm: relogio.agora, ordem: ordem)
        contexto.insert(sub)
        sub.pai = pai
        sub.alteradoEm = relogio.agora
        registarAcao(em: pai)
        return sub
    }

    public func editarTitulo(_ item: Item, para titulo: String) throws {
        item.titulo = try limpo(titulo)
        registarAcao(em: item)
    }

    /// Escreve, muda ou apaga (texto vazio) a descrição curta de um item principal
    /// (especificação 4.6). Os subtópicos não têm descrição. Conta como ação quando muda.
    public func definirNota(_ item: Item, _ texto: String) {
        guard !item.ehSubtopico else { return }
        let limpo = String(texto.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxDescricao))
        let nova = limpo.isEmpty ? nil : limpo
        guard nova != item.nota else { return }
        item.nota = nova
        registarAcao(em: item)
    }

    /// Uma ação reinicia a contagem de expiração do item principal (especificação 4.1 e 4.3).
    /// Nas listas de compras não há prazo: só fica registado quando o item mudou.
    public func registarAcao(em item: Item) {
        let alvo = item.pai ?? item
        let agora = relogio.agora
        item.alteradoEm = agora
        alvo.ultimaAcaoEm = agora
        if alvo.lista?.ehCompras == true {
            alvo.expiraEm = nil
        } else if alvo.estado == .ativo && !alvo.fixado {
            alvo.expiraEm = daquiA(definicoes.diasExpiracao, desde: agora)
        }
    }

    /// Manter: o prazo passa a agora + 5 dias (curto) ou + 15 dias (longo).
    public func manter(_ item: Item, longo: Bool) {
        guard !item.ehSubtopico, item.estado == .ativo, !item.fixado else { return }
        let agora = relogio.agora
        item.ultimaAcaoEm = agora
        let dias = longo ? definicoes.diasManterLongo : definicoes.diasManterCurto
        item.expiraEm = daquiA(dias, desde: agora)
    }

    /// Conclui o item. Devolve o que é preciso para o `anular` logo a seguir.
    @discardableResult
    public func concluir(_ item: Item) -> AntesDeConcluir {
        let antes = AntesDeConcluir(estado: item.estado, expiraEm: item.expiraEm, ultimaAcaoEm: item.ultimaAcaoEm)
        item.estado = .concluido
        item.concluidoEm = relogio.agora
        if item.ehSubtopico {
            registarAcao(em: item)
        } else {
            item.expiraEm = nil
        }
        return antes
    }

    /// "Anular" depois de concluir (Melhoria 2): o item volta ao estado de antes, com o mesmo
    /// prazo e o mesmo anel. Não conta como ação. Só vale para itens principais ainda
    /// concluídos.
    public func anular(_ item: Item, para antes: AntesDeConcluir) {
        guard !item.ehSubtopico, item.estado == .concluido else { return }
        item.estado = antes.estado
        item.concluidoEm = nil
        item.expiraEm = antes.expiraEm
        item.ultimaAcaoEm = antes.ultimaAcaoEm
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

    /// Apaga o item, os subtópicos e as fotos (critério 6). Apagar um subtópico conta como
    /// ação no item principal.
    public func apagar(_ item: Item) {
        // Numa lista de compras fica uma lápide, para o artigo não voltar ao juntar cópias.
        if item.listaEfetiva?.ehCompras == true && item.apagadoEm == nil && !aApagarLista {
            let agora = relogio.agora
            for alvo in [item] + item.subtopicos {
                alvo.apagadoEm = agora
                alvo.alteradoEm = agora
            }
            return
        }
        if let pai = item.pai {
            registarAcao(em: pai)
        }
        for sub in item.subtopicos {
            apagar(sub)
        }
        for foto in item.fotos {
            contexto.delete(foto)
        }
        contexto.delete(item)
    }

    // MARK: - Fotos

    /// `dados` já vem em JPEG reduzido pela interface. Conta como ação.
    @discardableResult
    public func adicionarFoto(_ dados: Data, a item: Item) throws -> Foto {
        guard item.fotos.count < Self.maxFotos else { throw ErroTarefas.limiteFotos }
        let ordem = (item.fotos.map(\.ordem).max() ?? -1) + 1
        let foto = Foto(dados: dados, ordem: ordem, criadaEm: relogio.agora)
        contexto.insert(foto)
        foto.item = item
        registarAcao(em: item)
        return foto
    }

    public func remover(_ foto: Foto) {
        if let item = foto.item {
            registarAcao(em: item)
        }
        contexto.delete(foto)
    }

    // MARK: - Expiração (especificação 4.1 e 4.2)

    /// Corre sempre que a app abre ou volta ao primeiro plano: expira o que passou do prazo
    /// e apaga o que já ficou tempo suficiente em Expirados ou Concluídos.
    @discardableResult
    public func avaliar() throws -> (expirados: Int, apagados: Int) {
        let agora = relogio.agora
        var expirados = 0
        var apagados = 0
        for item in try itensPrincipais() {
            if item.estado == .ativo, !item.fixado, let limite = item.expiraEm, agora >= limite {
                item.estado = .expirado
                // Conta a partir do momento em que expirou, mesmo que a app estivesse fechada.
                item.expiradoEm = limite
                item.expiraEm = nil
                expirados += 1
            }
            if let fim = fimDaRetencao(de: item), agora >= fim {
                apagar(item)
                apagados += 1
            }
        }
        return (expirados, apagados)
    }

    /// Volta à lista original, ativo, com um prazo novo de 3 dias.
    public func recuperar(_ item: Item) {
        guard item.estado == .expirado else { return }
        item.estado = .ativo
        item.expiradoEm = nil
        registarAcao(em: item)
    }

    /// Dias até um item expirado ou concluído ser apagado (arredondado para cima).
    public func diasAteApagar(_ item: Item) -> Int? {
        guard let fim = fimDaRetencao(de: item) else { return nil }
        let segundos = max(0, fim.timeIntervalSince(relogio.agora))
        return Int((segundos / (24 * 60 * 60)).rounded(.up))
    }

    /// Itens principais num estado, os mais recentes primeiro.
    public func itens(_ estado: EstadoItem) throws -> [Item] {
        try itensPrincipais()
            .filter { $0.estado == estado }
            .sorted { ($0.expiradoEm ?? $0.concluidoEm ?? $0.criadoEm) > ($1.expiradoEm ?? $1.concluidoEm ?? $1.criadoEm) }
    }

    // MARK: - Notificações (especificação 6)

    /// Avisos a agendar: 24 horas antes de cada item ativo expirar, os mais próximos primeiro.
    /// Um aviso que calharia entre as 22:00 e as 08:00 passa para a hora das notificações.
    public func planoAvisos() throws -> [Aviso] {
        guard definicoes.avisosAtivos else { return [] }
        let agora = relogio.agora
        let avisos: [Aviso] = try itensPrincipais().compactMap { item in
            guard item.estado == .ativo, !item.fixado, let limite = item.expiraEm else { return nil }
            let data = horaDoAviso(paraExpiracaoEm: limite)
            guard data > agora, data < limite else { return nil }
            return Aviso(
                itemId: item.id,
                titulo: item.titulo,
                data: data,
                lista: item.lista?.nome,
                expiraEm: limite,
                subtopicosPorFazer: item.subtopicos.count - item.subtopicosFeitos,
                ultimaAcaoEm: item.ultimaAcaoEm
            )
        }
        return Array(avisos.sorted { $0.data < $1.data }.prefix(Self.maxAvisos))
    }

    func horaDoAviso(paraExpiracaoEm limite: Date) -> Date {
        let base = calendario.date(byAdding: .hour, value: -24, to: limite)!
        let hora = calendario.component(.hour, from: base)
        guard hora >= 22 || hora < 8 else { return base }
        var dia = calendario.startOfDay(for: base)
        if hora >= 22 {
            dia = calendario.date(byAdding: .day, value: 1, to: dia)!
        }
        return calendario.date(
            bySettingHour: definicoes.horaNotificacao,
            minute: definicoes.minutoNotificacao,
            second: 0,
            of: dia
        )!
    }

    // MARK: - Auxiliares

    private func itensPrincipais() throws -> [Item] {
        try contexto.fetch(FetchDescriptor<Item>()).filter { !$0.ehSubtopico }
    }

    private func fimDaRetencao(de item: Item) -> Date? {
        switch item.estado {
        case .expirado:
            return item.expiradoEm.map { daquiA(definicoes.diasRetencaoExpirados, desde: $0) }
        case .concluido:
            guard !item.ehSubtopico else { return nil }
            return item.concluidoEm.map { daquiA(definicoes.diasRetencaoConcluidos, desde: $0) }
        case .ativo:
            return nil
        }
    }

    private func daquiA(_ dias: Int, desde data: Date) -> Date {
        calendario.date(byAdding: .day, value: dias, to: data)!
    }

    private func limpo(_ texto: String) throws -> String {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { throw ErroTarefas.textoVazio }
        return limpo
    }

    private func emojiLimpo(_ emoji: String?) -> String? {
        guard let emoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines), let primeiro = emoji.first else {
            return nil
        }
        return String(primeiro)
    }
}
