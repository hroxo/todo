import Foundation
import SwiftData
import ToDoCore
import UserNotifications

/// Notificações locais (especificação 6): um aviso 24 horas antes de cada item expirar, com
/// as ações Manter +5, Manter +15 e Concluir, que funcionam sem abrir a app.
final class Notificacoes: NSObject, UNUserNotificationCenterDelegate {
    static let categoria = "EXPIRA"

    private enum Acao: String {
        case manterCurto = "MANTER_CURTO"
        case manterLongo = "MANTER_LONGO"
        case concluir = "CONCLUIR"
    }

    private let contentor: ModelContainer

    init(contentor: ModelContainer) {
        self.contentor = contentor
        super.init()
    }

    /// Chamado no arranque, antes de o iOS entregar uma ação de notificação.
    func configurar() {
        let centro = UNUserNotificationCenter.current()
        centro.delegate = self
        registarCategoria()
    }

    func pedirPermissao() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Substitui todos os avisos pendentes pelos mais próximos (o iOS guarda no máximo 64).
    func reagendar() {
        registarCategoria()
        let avisos = (try? Tarefas(contexto: ModelContext(contentor)).planoAvisos()) ?? []
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()
        for aviso in avisos {
            let conteudo = UNMutableNotificationContent()
            conteudo.title = aviso.titulo
            conteudo.body = "Manter?"
            conteudo.sound = .default
            conteudo.categoryIdentifier = Self.categoria
            let quando = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: aviso.data)
            let pedido = UNNotificationRequest(
                identifier: aviso.itemId.uuidString,
                content: conteudo,
                trigger: UNCalendarNotificationTrigger(dateMatching: quando, repeats: false)
            )
            centro.add(pedido)
        }
    }

    private func registarCategoria() {
        let definicoes = Definicoes.carregar()
        let categoria = UNNotificationCategory(
            identifier: Self.categoria,
            actions: [
                UNNotificationAction(identifier: Acao.manterCurto.rawValue, title: "Manter +\(definicoes.diasManterCurto) dias"),
                UNNotificationAction(identifier: Acao.manterLongo.rawValue, title: "Manter +\(definicoes.diasManterLongo) dias"),
                UNNotificationAction(identifier: Acao.concluir.rawValue, title: "Concluir"),
            ],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([categoria])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let acao = Acao(rawValue: response.actionIdentifier)
        let id = UUID(uuidString: response.notification.request.identifier)
        DispatchQueue.main.async {
            if let acao, let id {
                self.tratar(acao, itemId: id)
            }
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func tratar(_ acao: Acao, itemId: UUID) {
        let contexto = ModelContext(contentor)
        var pedido = FetchDescriptor<Item>(predicate: #Predicate { $0.id == itemId })
        pedido.fetchLimit = 1
        guard let item = try? contexto.fetch(pedido).first, item.estado == .ativo else { return }
        let tarefas = Tarefas(contexto: contexto)
        switch acao {
        case .manterCurto: tarefas.manter(item, longo: false)
        case .manterLongo: tarefas.manter(item, longo: true)
        case .concluir: tarefas.concluir(item)
        }
        try? contexto.save()
        reagendar()
    }
}
