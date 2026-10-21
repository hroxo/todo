import Foundation
import SwiftData

/// Esquema versionado (especificação 11): uma alteração ao modelo cria um EsquemaV2 e uma
/// etapa de migração em `PlanoMigracao`, nunca altera o V1 no lugar.
public enum EsquemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [Lista.self, Item.self] }
}

public enum PlanoMigracao: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [EsquemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum BaseDados {
    public static func contentor(emMemoria: Bool = false) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: EsquemaV1.self)
        let configuracao = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: emMemoria)
        return try ModelContainer(for: esquema, migrationPlan: PlanoMigracao.self, configurations: configuracao)
    }
}
