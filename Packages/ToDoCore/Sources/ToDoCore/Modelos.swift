import Foundation
import SwiftData

/// As 12 cores da paleta das listas (DESIGN.md 3.2). O núcleo só guarda a chave; as cores
/// reais estão no catálogo de recursos da app.
public enum CorLista: String, CaseIterable, Codable, Sendable {
    case azul, roxo, amarelo, vermelho, laranja, verde, turquesa, ceu, indigo, rosa, castanho, grafite

    /// Lê a chave guardada, incluindo as cores do M1 que deixaram de existir.
    public static func deChave(_ chave: String) -> CorLista {
        if let cor = CorLista(rawValue: chave) { return cor }
        switch chave {
        case "ciano": return .turquesa
        default: return .azul
        }
    }
}

/// Ícones possíveis de uma lista (DESIGN.md 6.1): um SF Symbol ou um emoji.
public enum IconesLista {
    public static let padrao = "checkmark.circle.fill"

    public static let simbolos: [(nome: String, simbolo: String)] = [
        ("Trabalho", "briefcase.fill"),
        ("Pessoa", "person.fill"),
        ("Casa", "house.fill"),
        ("Lâmpada", "lightbulb.fill"),
        ("Coração", "heart.fill"),
        ("Carrinho", "cart.fill"),
        ("Livro", "book.fill"),
        ("Haltere", "dumbbell.fill"),
        ("Avião", "airplane"),
        ("Estrela", "star.fill"),
        ("Lua", "moon.fill"),
        ("Folha", "leaf.fill"),
        ("Presente", "gift.fill"),
        ("Música", "music.note"),
        ("Câmara", "camera.fill"),
        ("Código", "chevron.left.forwardslash.chevron.right"),
        ("Calendário", "calendar"),
        ("Visto", "checkmark.circle.fill"),
    ]

    public static let emojis = [
        "💼", "🏠", "💡", "🛒", "🏋️", "✈️", "📚", "🎯", "🧠",
        "🎵", "🌱", "🐶", "🍳", "💰", "🎮", "❤️", "🚗", "⭐",
    ]
}

public enum TipoItem: String, CaseIterable, Codable, Sendable {
    case tarefa, notaRapida
}

public enum EstadoItem: String, CaseIterable, Codable, Sendable {
    case ativo, concluido, expirado
}

/// Uma lista normal (itens que expiram) ou de compras (DESIGN.md 7.15): os itens são lojas,
/// os subtópicos são artigos, e nada expira.
public enum TipoLista: String, CaseIterable, Codable, Sendable {
    case normal, compras
}

/// Compatível com o CloudKit (EsquemaV6): sem atributos únicos, tudo com valor por defeito e
/// as relações para muitos opcionais; `itens` dá sempre uma lista.
@Model
public final class Lista {
    public var id = UUID()
    public var nome = ""
    public var corRaw = CorLista.azul.rawValue
    public var ordem = 0
    /// Nome do SF Symbol. Ignorado quando há `emoji`.
    public var icone: String = "checkmark.circle.fill"
    public var emoji: String?
    public var tipoRaw: String = TipoLista.normal.rawValue
    /// Igual nas cópias de uma lista partilhada, para as juntar.
    public var partilhaId: UUID?
    /// Uma lista permanente nunca desaparece; as outras saem do Início ao fim de 5 dias sem
    /// pontos abertos (DESIGN.md 7.17). No máximo 4.
    public var permanente = false
    /// Desde quando a lista está sem pontos abertos; nil quando tem algum.
    public var vaziaDesde: Date?

    /// Só os itens principais; os subtópicos pertencem ao item pai.
    @Relationship(deleteRule: .cascade, originalName: "itens", inverse: \Item.lista)
    public var itensGuardados: [Item]? = []

    public var itens: [Item] {
        get { itensGuardados ?? [] }
        set { itensGuardados = newValue }
    }

    public init(id: UUID = UUID(), nome: String, cor: CorLista, ordem: Int, icone: String = IconesLista.padrao, emoji: String? = nil) {
        self.id = id
        self.nome = nome
        self.corRaw = cor.rawValue
        self.ordem = ordem
        self.icone = icone
        self.emoji = emoji
    }

    public var cor: CorLista {
        get { CorLista.deChave(corRaw) }
        set { corRaw = newValue.rawValue }
    }

    public var tipo: TipoLista {
        get { TipoLista(rawValue: tipoRaw) ?? .normal }
        set { tipoRaw = newValue.rawValue }
    }

    public var ehCompras: Bool { tipo == .compras }

    /// Há algum ponto ativo na lista.
    public var temPontosAbertos: Bool { !itensAtivos.isEmpty }

    public var itensAtivos: [Item] {
        itens.filter { $0.estado == .ativo && $0.apagadoEm == nil }.sorted { $0.ordem < $1.ordem }
    }

    /// Itens ativos que expiram nas próximas 24 horas.
    public func expiramHoje(agora: Date) -> [Item] {
        itensAtivos.filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }
    }

    /// Proporção dos itens com prazo que ainda não estão no último dia (o mini-anel do
    /// cartão). Sem itens com prazo, a lista está "fresca".
    public func frescura(agora: Date) -> Double {
        let prazos = itensAtivos.compactMap { Prazo(item: $0, agora: agora) }
        guard !prazos.isEmpty else { return 1 }
        return Double(prazos.filter { !$0.ultimoDia }.count) / Double(prazos.count)
    }
}

/// Um item principal tem `lista` e não tem `pai`. Um subtópico tem `pai` e não tem `lista`
/// (pertence à lista do pai). Só há um nível de subtópicos.
@Model
public final class Item {
    public var id = UUID()
    public var titulo = ""
    public var tipoRaw = TipoItem.tarefa.rawValue
    public var estadoRaw = EstadoItem.ativo.rawValue
    public var fixado = false
    public var criadoEm = Date.distantPast
    public var ultimaAcaoEm = Date.distantPast
    public var expiraEm: Date?
    public var expiradoEm: Date?
    public var concluidoEm: Date?
    public var ordem = 0
    /// Descrição curta do item principal (especificação 4.6). Vazia nos subtópicos.
    public var nota: String?
    /// Evento do calendário de onde veio o item: identificador externo do evento e início
    /// da ocorrência (cada ocorrência de um evento recorrente conta à parte).
    public var eventoId: String?
    public var eventoInicio: Date?
    /// Última alteração, para juntar as cópias de uma lista partilhada (ganha a mais recente).
    public var alteradoEm: Date?
    /// Lápide: numa lista partilhada, apagar só marca, para o apagado não voltar ao juntar.
    public var apagadoEm: Date?

    public var lista: Lista?
    public var pai: Item?

    @Relationship(deleteRule: .cascade, originalName: "subtopicos", inverse: \Item.pai)
    public var subtopicosGuardados: [Item]? = []

    @Relationship(deleteRule: .cascade, originalName: "fotos", inverse: \Foto.item)
    public var fotosGuardadas: [Foto]? = []

    public var subtopicos: [Item] {
        get { subtopicosGuardados ?? [] }
        set { subtopicosGuardados = newValue }
    }

    public var fotos: [Foto] {
        get { fotosGuardadas ?? [] }
        set { fotosGuardadas = newValue }
    }

    public init(id: UUID = UUID(), titulo: String, tipo: TipoItem, criadoEm: Date, ordem: Int) {
        self.id = id
        self.titulo = titulo
        self.tipoRaw = tipo.rawValue
        self.estadoRaw = EstadoItem.ativo.rawValue
        self.fixado = false
        self.criadoEm = criadoEm
        self.ultimaAcaoEm = criadoEm
        self.ordem = ordem
    }

    public var tipo: TipoItem {
        get { TipoItem(rawValue: tipoRaw) ?? .tarefa }
        set { tipoRaw = newValue.rawValue }
    }

    public var estado: EstadoItem {
        get { EstadoItem(rawValue: estadoRaw) ?? .ativo }
        set { estadoRaw = newValue.rawValue }
    }

    public var ehSubtopico: Bool { pai != nil }

    /// Sem as lápides das listas partilhadas.
    public var subtopicosOrdenados: [Item] {
        subtopicos.filter { $0.apagadoEm == nil }.sorted { $0.ordem < $1.ordem }
    }

    public var subtopicosFeitos: Int {
        subtopicos.filter { $0.estado == .concluido && $0.apagadoEm == nil }.count
    }

    public var fotosOrdenadas: [Foto] {
        fotos.sorted { $0.ordem < $1.ordem }
    }

    /// A lista a que o item pertence, também para subtópicos.
    public var listaEfetiva: Lista? { pai?.lista ?? lista }

    /// "2/4 subtópicos · descrição · 2 fotos", ou o tipo quando não há subtópicos.
    public var resumo: String {
        var partes: [String] = []
        if subtopicos.isEmpty {
            partes.append(tipo == .tarefa ? "Tarefa" : "Nota rápida")
        } else {
            partes.append("\(subtopicosFeitos)/\(subtopicos.count) subtópicos")
        }
        if nota != nil {
            partes.append("descrição")
        }
        switch fotos.count {
        case 0: break
        case 1: partes.append("1 foto")
        case let n: partes.append("\(n) fotos")
        }
        return partes.joined(separator: " · ")
    }
}

/// Foto anexada a um item, em JPEG reduzido, guardada fora da base de dados.
@Model
public final class Foto {
    public var id = UUID()
    @Attribute(.externalStorage) public var dados = Data()
    public var ordem = 0
    public var criadaEm = Date.distantPast
    public var item: Item?

    public init(id: UUID = UUID(), dados: Data, ordem: Int, criadaEm: Date) {
        self.id = id
        self.dados = dados
        self.ordem = ordem
        self.criadaEm = criadaEm
    }
}
