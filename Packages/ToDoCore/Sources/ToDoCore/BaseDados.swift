import Foundation
import SwiftData

/// Esquema versionado (especificação 11). Cada versão antiga fica congelada aqui, com cópias
/// exatas dos modelos dessa altura, e `PlanoMigracao` leva os dados até à versão atual.
/// Uma alteração ao modelo cria um EsquemaV7 e uma nova etapa; nunca altera as anteriores.
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

/// V3 (M4): descrição curta (`nota`) nos itens.
public enum EsquemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)
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
        var nota: String?

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

/// V4 (Melhoria 6): o evento do calendário de onde veio o item (identificador externo e
/// início da ocorrência), para o "+" só funcionar uma vez por evento.
public enum EsquemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)
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
        var nota: String?
        var eventoId: String?
        var eventoInicio: Date?

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

/// V5 (listas de compras partilhadas, DESIGN.md 7.15, e listas que se apagam sozinhas, 7.17):
/// o tipo da lista, o identificador da partilha, se é permanente e desde quando está vazia;
/// nos itens, quando mudaram (para juntar cópias) e a lápide dos apagados.
public enum EsquemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)
    public static var models: [any PersistentModel.Type] { [Lista.self, Item.self, Foto.self] }

    @Model
    final class Lista {
        @Attribute(.unique) var id: UUID
        var nome: String
        var corRaw: String
        var ordem: Int
        var icone: String = "checkmark.circle.fill"
        var emoji: String?
        var tipoRaw: String = "normal"
        var partilhaId: UUID?
        var permanente = false
        var vaziaDesde: Date?

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
        var nota: String?
        var eventoId: String?
        var eventoInicio: Date?
        var alteradoEm: Date?
        var apagadoEm: Date?

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

/// V6 (DESIGN.md 7.19): pronto para sincronizar com o iCloud (SwiftData com CloudKit). O
/// CloudKit não aceita atributos únicos e exige valores por defeito e relações opcionais:
/// os `id` deixam de ser `.unique` e as relações para muitos passam a opcionais (com o mesmo
/// nome guardado, via `originalName`). Os dados não mudam.
public enum EsquemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)
    public static var models: [any PersistentModel.Type] { [Lista.self, Item.self, Foto.self] }
}

public enum PlanoMigracao: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [EsquemaV1.self, EsquemaV2.self, EsquemaV3.self, EsquemaV4.self, EsquemaV5.self, EsquemaV6.self]
    }
    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: EsquemaV1.self, toVersion: EsquemaV2.self),
            .lightweight(fromVersion: EsquemaV2.self, toVersion: EsquemaV3.self),
            .lightweight(fromVersion: EsquemaV3.self, toVersion: EsquemaV4.self),
            migrarV4ParaV5,
            .lightweight(fromVersion: EsquemaV5.self, toVersion: EsquemaV6.self),
        ]
    }
}

extension PlanoMigracao {
    /// As listas que já existiam não podem começar a desaparecer: as 4 primeiras do Início
    /// ficam permanentes (o máximo); as outras seguem a regra dos 5 dias (DESIGN.md 7.17).
    static let migrarV4ParaV5 = MigrationStage.custom(
        fromVersion: EsquemaV4.self,
        toVersion: EsquemaV5.self,
        willMigrate: nil,
        didMigrate: { contexto in
            let listas = try contexto.fetch(FetchDescriptor<EsquemaV5.Lista>(sortBy: [SortDescriptor(\.ordem)]))
            for lista in listas.prefix(Tarefas.maxPermanentes) {
                lista.permanente = true
            }
            try contexto.save()
        }
    )
}

public enum BaseDados {
    /// App Group partilhado com o widget (DESIGN.md 7.14).
    public static let grupo = "group.com.hugo.todo"
    private static let sufixos = ["", "-wal", "-shm"]

    /// A pasta do App Group, ou nil quando a app não o tem (testes, `.ipa` sem assinatura).
    public static var pastaPartilhada: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grupo)
    }

    /// Sem `url`, usa o ficheiro no App Group, se houver, ou o ficheiro por defeito da app.
    public static func contentor(emMemoria: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: EsquemaV6.self)
        // iCloud (DESIGN.md 7.19): `.automatic` sincroniza com o contentor CloudKit das
        // entitlements da app e não faz nada sem elas (hoje, sem a conta paga). Os testes, a
        // memória e os ficheiros explícitos nunca sincronizam.
        let configuracao: ModelConfiguration
        if let url {
            configuracao = ModelConfiguration(schema: esquema, url: url, cloudKitDatabase: .none)
        } else if emMemoria {
            configuracao = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let pasta = pastaPartilhada {
            let destino = pasta.appendingPathComponent("ToDo.store")
            mudar(de: URL.applicationSupportDirectory.appendingPathComponent("default.store"), para: destino)
            configuracao = ModelConfiguration(schema: esquema, url: destino, cloudKitDatabase: .automatic)
        } else {
            configuracao = ModelConfiguration(schema: esquema, cloudKitDatabase: .automatic)
        }
        return try ModelContainer(for: esquema, migrationPlan: PlanoMigracao.self, configurations: configuracao)
    }

    /// Muda a base de dados (e os ficheiros `-wal` e `-shm`) para o App Group, uma só vez.
    /// Copia tudo primeiro e só depois apaga o original: se alguma cópia falhar, desfaz e a app
    /// continua com o ficheiro antigo (nada se perde). Devolve verdadeiro se mudou.
    @discardableResult
    public static func mudar(de origem: URL, para destino: URL) -> Bool {
        let gestor = FileManager.default
        guard gestor.fileExists(atPath: origem.path), !gestor.fileExists(atPath: destino.path) else { return false }
        let pares = sufixos
            .map { (URL(fileURLWithPath: origem.path + $0), URL(fileURLWithPath: destino.path + $0)) }
            .filter { gestor.fileExists(atPath: $0.0.path) }
        do {
            try gestor.createDirectory(at: destino.deletingLastPathComponent(), withIntermediateDirectories: true)
            for (de, para) in pares {
                try gestor.copyItem(at: de, to: para)
            }
        } catch {
            for (_, para) in pares {
                try? gestor.removeItem(at: para)
            }
            return false
        }
        for (de, _) in pares {
            try? gestor.removeItem(at: de)
        }
        return true
    }
}
