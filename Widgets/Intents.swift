import AppIntents
import Foundation
import SwiftData
import ToDoCore
import WidgetKit

/// Concluir um ponto no widget, sem abrir a app (DESIGN.md 7.14). Corre na extensão: abre a
/// base de dados do App Group, conclui, grava e reescreve o resumo, e o widget recarrega.
struct ConcluirPontoIntent: AppIntent {
    static let title: LocalizedStringResource = "Concluir ponto"
    static let isDiscoverable = false

    @Parameter(title: "Ponto")
    var id: String

    init() {}

    init(id: UUID) {
        self.id = id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let itemId = UUID(uuidString: id) else { return .result() }
        let contexto = ModelContext(try BaseDados.contentor())
        var pedido = FetchDescriptor<Item>(predicate: #Predicate { $0.id == itemId })
        pedido.fetchLimit = 1
        let tarefas = Tarefas(contexto: contexto)
        if let item = try contexto.fetch(pedido).first, item.estado == .ativo {
            tarefas.concluir(item)
            try contexto.save()
        }
        if let pasta = BaseDados.pastaPartilhada {
            try? tarefas.resumoWidget().gravar(em: pasta)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Abre a app na captura rápida: o controlo Nova nota (ecrã bloqueado, Centro de Controlo,
/// Action Button). Tem de estar na app e na extensão.
struct AbrirCapturaIntent: AppIntent {
    static let title: LocalizedStringResource = "Nova nota"
    static let description = IntentDescription("Abre a ToDo para escrever um ponto novo.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(urlCaptura))
    }
}
