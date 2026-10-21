import Foundation
import SwiftData

/// Esquema versionado (especificação 11). Cada versão antiga fica congelada aqui, com cópias
/// exatas dos modelos dessa altura, e `PlanoMigracao` leva os dados até à versão atual.
/// Uma alteração ao modelo cria um EsquemaV3 e uma nova etapa; nunca altera as anteriores.
public enum EsquemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [Lista.self, Item.self] }

    @Model
    final class Lista {
        @Attribute(.unique) var id: UUID
        var nome: String
        var corRaw: String
        var ordem: Int

        @Relationship(deleteRule: .cascade, inverse: \Item.lista)
        var itens: [Item] = []

        init(id: UUID = UUID(), nome: String, corRaw: String, ordem: Int) {
            self.id = id
            self.nome = nome
            self.corRaw = corRaw
            self.ordem = ordem
        }
    }

    @Model
    final class Item {
        @Attribute(.unique) var id: UUID
        var titulo: String
        var tipoRaw: String
        var estadoRaw: String
        var fixado: Bool
        var criadoEm: Date
        var ultimaAcaoEm: Date
        var expiraEm: Date?
        var expiradoEm: Date?
        var concluidoEm: Date?
        var ordem: Int

        var lista: Lista?
        var pai: Item?

        @Relationship(deleteRule: .cascade, inverse: \Item.pai)
        var subtopicos: [Item] = []

        init(id: UUID = UUID(), titulo: String, criadoEm: Date, ordem: Int) {
            self.id = id
            self.titulo = titulo
            self.tipoRaw = "tarefa"
            self.estadoRaw = "ativo"
            self.fixado = false
            self.criadoEm = criadoEm
            self.ultimaAcaoEm = criadoEm
            self.ordem = ordem
        }
    }
}

/// V2 (design): ícone e emoji nas listas, fotos nos itens.
public enum EsquemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
    public static var models: [any PersistentModel.Type] { [Lista.self, Item.self, Foto.self] }

    @Model
    final class Lista {
        @Attribute(.unique) var id: UUID
        var nome: String
        var corRaw: String
        var ordem: Int
        var icone: String = "checkmark.circle.fill"
        var emoji: String?

        @Relationship(deleteRule: .cascade, inverse: \Item.lista)
        var itens: [Item] = []

        init(id: UUID = UUID(), nome: String, corRaw: String, ordem: Int) {
            self.id = id
            self.nome = nome
            self.corRaw = corRaw
            self.ordem = ordem
        }
    }

    @Model
    final class Item {
        @Attribute(.unique) var id: UUID
        var titulo: String
        var tipoRaw: String
        var estadoRaw: String
        var fixado: Bool
        var criadoEm: Date
        var ultimaAcaoEm: Date
        var expiraEm: Date?
        var expiradoEm: Date?
        var concluidoEm: Date?
        var ordem: Int

        var lista: Lista?
        var pai: Item?

        @Relationship(deleteRule: .cascade, inverse: \Item.pai)
        var subtopicos: [Item] = []

        @Relationship(deleteRule: .cascade, inverse: \Foto.item)
        var fotos: [Foto] = []

        init(id: UUID = UUID(), titulo: String, criadoEm: Date, ordem: Int) {
            self.id = id
            self.titulo = titulo
            self.tipoRaw = "tarefa"
            self.estadoRaw = "ativo"
            self.fixado = false
            self.criadoEm = criadoEm
            self.ultimaAcaoEm = criadoEm
            self.ordem = ordem
        }
    }

    @Model
    final class Foto {
        @Attribute(.unique) var id: UUID
        @Attribute(.externalStorage) var dados: Data
        var ordem: Int
        var criadaEm: Date
        var item: Item?

        init(id: UUID = UUID(), dados: Data, ordem: Int, criadaEm: Date) {
            self.id = id
            self.dados = dados
            self.ordem = ordem
            self.criadaEm = criadaEm
        }
    }
}

/// V3 (M4): nota de texto em cada item e subtópico.
public enum EsquemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)
    public static var models: [any PersistentModel.Type] { [Lista.self, Item.self, Foto.self] }
}

public enum PlanoMigracao: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [EsquemaV1.self, EsquemaV2.self, EsquemaV3.self] }
    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: EsquemaV1.self, toVersion: EsquemaV2.self),
            .lightweight(fromVersion: EsquemaV2.self, toVersion: EsquemaV3.self),
        ]
    }
}

public enum BaseDados {
    /// Sem `url`, usa o ficheiro por defeito da app.
    public static func contentor(emMemoria: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: EsquemaV3.self)
        let configuracao: ModelConfiguration
        if let url {
            configuracao = ModelConfiguration(schema: esquema, url: url)
        } else {
            configuracao = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: emMemoria)
        }
        return try ModelContainer(for: esquema, migrationPlan: PlanoMigracao.self, configurations: configuracao)
    }
}
