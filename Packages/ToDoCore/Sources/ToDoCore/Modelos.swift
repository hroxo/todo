import Foundation
import SwiftData

/// Cores da paleta fixa das listas (especificação 4.4). O núcleo só guarda o identificador;
/// a cor real é definida na interface.
public enum CorLista: String, CaseIterable, Codable, Sendable {
    case vermelho, laranja, amarelo, verde, ciano, azul, roxo, rosa
}

public enum TipoItem: String, CaseIterable, Codable, Sendable {
    case tarefa, notaRapida
}

public enum EstadoItem: String, CaseIterable, Codable, Sendable {
    case ativo, concluido, expirado
}

@Model
public final class Lista {
    @Attribute(.unique) public var id: UUID
    public var nome: String
    public var corRaw: String
    public var ordem: Int

    /// Só os itens principais; os subtópicos pertencem ao item pai.
    @Relationship(deleteRule: .cascade, inverse: \Item.lista)
    public var itens: [Item] = []

    public init(id: UUID = UUID(), nome: String, cor: CorLista, ordem: Int) {
        self.id = id
        self.nome = nome
        self.corRaw = cor.rawValue
        self.ordem = ordem
    }

    public var cor: CorLista {
        get { CorLista(rawValue: corRaw) ?? .azul }
        set { corRaw = newValue.rawValue }
    }

    public var itensAtivos: [Item] {
        itens.filter { $0.estado == .ativo }.sorted { $0.ordem < $1.ordem }
    }
}

/// Um item principal tem `lista` e não tem `pai`. Um subtópico tem `pai` e não tem `lista`
/// (pertence à lista do pai). Só há um nível de subtópicos.
@Model
public final class Item {
    @Attribute(.unique) public var id: UUID
    public var titulo: String
    public var tipoRaw: String
    public var estadoRaw: String
    public var fixado: Bool
    public var criadoEm: Date
    public var ultimaAcaoEm: Date
    public var expiraEm: Date?
    public var expiradoEm: Date?
    public var concluidoEm: Date?
    public var ordem: Int

    public var lista: Lista?
    public var pai: Item?

    @Relationship(deleteRule: .cascade, inverse: \Item.pai)
    public var subtopicos: [Item] = []

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

    public var subtopicosOrdenados: [Item] {
        subtopicos.sorted { $0.ordem < $1.ordem }
    }

    public var subtopicosFeitos: Int {
        subtopicos.filter { $0.estado == .concluido }.count
    }

    /// A lista a que o item pertence, também para subtópicos.
    public var listaEfetiva: Lista? { pai?.lista ?? lista }
}
