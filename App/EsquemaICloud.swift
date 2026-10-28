#if DEBUG
import CoreData
import Foundation
import SwiftData
import ToDoCore

/// Só em compilações de desenvolvimento (DESIGN.md 7.19): cria no ambiente de desenvolvimento
/// do CloudKit a estrutura dos dados da app (os tipos de registo de Lista, Item e Foto). Depois
/// publica-se em produção no painel do CloudKit (docs/CONTA-DEVELOPER.md). Sem isto, as
/// versões do TestFlight não sincronizam. Sem a conta paga e o iCloud ligado, falha e diz porquê.
enum EsquemaICloud {
    enum Erro: Error {
        case semModelo
    }

    static func criar() throws {
        guard let modelo = NSManagedObjectModel.makeManagedObjectModel(for: [Lista.self, Item.self, Foto.self]) else {
            throw Erro.semModelo
        }
        // Uma base de dados à parte, temporária: só serve para enviar a estrutura.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("esquema-icloud.store")
        let descricao = NSPersistentStoreDescription(url: url)
        descricao.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Backups.contentorICloud)
        descricao.shouldAddStoreAsynchronously = false

        let contentor = NSPersistentCloudKitContainer(name: "ToDo", managedObjectModel: modelo)
        contentor.persistentStoreDescriptions = [descricao]
        var falha: Error?
        contentor.loadPersistentStores { _, erro in falha = erro }
        if let falha { throw falha }
        try contentor.initializeCloudKitSchema()
        for loja in contentor.persistentStoreCoordinator.persistentStores {
            try contentor.persistentStoreCoordinator.remove(loja)
        }
    }
}
#endif
