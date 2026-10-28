import Foundation
import SwiftData
import ToDoCore
import UIKit
import UserNotifications

/// Notificações locais (especificação 6): um aviso 24 horas antes de cada item expirar, com
/// as ações Manter +5, Manter +15 e Concluir, e outro antes de uma lista vazia desaparecer,
/// com Manter mais 5 dias e Tornar permanente (DESIGN.md 7.17). Funcionam sem abrir a app.
final class Notificacoes: NSObject, UNUserNotificationCenterDelegate {
    static let categoria = "EXPIRA"
    static let categoriaLista = "LISTA_VAZIA"
    /// Prefixo dos identificadores dos avisos de listas; os dos itens são só o id do item.
    private static let prefixoLista = "lista-"

    private enum Acao: String {
        case manterCurto = "MANTER_CURTO"
        case manterLongo = "MANTER_LONGO"
        case concluir = "CONCLUIR"
        case manterLista = "MANTER_LISTA"
        case permanente = "PERMANENTE"
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

    /// Textos já escritos pelo modelo, para não os pedir outra vez enquanto o aviso não muda.
    private var escritos: [String: String] = [:]
    private var escrita: Task<Void, Never>?

    /// Avisos escritos pelo modelo em cada reagendamento: os mais próximos, que são os que
    /// importam e cabem no tempo que o iOS dá em segundo plano.
    private static let maxEscritos = 12

    /// Substitui todos os avisos pendentes pelos mais próximos (o iOS guarda no máximo 64).
    /// Agenda logo com o texto de base; se o modelo do iPhone estiver disponível, reescreve
    /// os mais próximos e substitui-os (o mesmo identificador troca o pedido).
    func reagendar() {
        registarCategoria()
        let definicoes = Definicoes.carregar()
        let tarefas = Tarefas(contexto: ModelContext(contentor))
        let avisosListas = (try? tarefas.planoAvisosListas()) ?? []
        // As listas primeiro: são poucas (no máximo 8) e o iOS só guarda 64 avisos.
        let avisos = Array(((try? tarefas.planoAvisos()) ?? []).prefix(Tarefas.maxAvisos - avisosListas.count))
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()
        for aviso in avisosListas {
            agendar(aviso)
        }
        let inteligente = definicoes.inteligenciaAtiva
        for aviso in avisos {
            agendar(aviso, corpo: (inteligente ? escritos[Self.chave(aviso)] : nil) ?? TextoAviso.corpo(aviso))
        }

        escrita?.cancel()
        guard inteligente, Inteligencia.disponivel else { return }
        let porEscrever = avisos.prefix(Self.maxEscritos).filter { escritos[Self.chave($0)] == nil }
        guard !porEscrever.isEmpty else { return }
        escrita = Task { @MainActor in
            let tarefa = UIApplication.shared.beginBackgroundTask()
            defer { UIApplication.shared.endBackgroundTask(tarefa) }
            for aviso in porEscrever {
                guard !Task.isCancelled else { return }
                guard let corpo = await Inteligencia.corpoAviso(aviso, base: TextoAviso.corpo(aviso)) else { continue }
                escritos[Self.chave(aviso)] = corpo
                agendar(aviso, corpo: corpo)
            }
        }
    }

    /// Título = item, subtítulo = lista, corpo = uma linha com contexto (DESIGN.md 7.16).
    private func agendar(_ aviso: Aviso, corpo: String) {
        let conteudo = UNMutableNotificationContent()
        conteudo.title = aviso.titulo
        if let lista = aviso.lista {
            conteudo.subtitle = lista
            conteudo.threadIdentifier = lista
        }
        conteudo.body = corpo
        conteudo.sound = .default
        conteudo.categoryIdentifier = Self.categoria
        let quando = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: aviso.data)
        let pedido = UNNotificationRequest(
            identifier: aviso.itemId.uuidString,
            content: conteudo,
            trigger: UNCalendarNotificationTrigger(dateMatching: quando, repeats: false)
        )
        UNUserNotificationCenter.current().add(pedido)
    }

    private func agendar(_ aviso: AvisoLista) {
        let conteudo = UNMutableNotificationContent()
        conteudo.title = TextoAviso.tituloLista(aviso)
        conteudo.body = TextoAviso.corpoLista(aviso)
        conteudo.sound = .default
        conteudo.categoryIdentifier = Self.categoriaLista
        let quando = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: aviso.data)
        let pedido = UNNotificationRequest(
            identifier: Self.prefixoLista + aviso.listaId.uuidString,
            content: conteudo,
            trigger: UNCalendarNotificationTrigger(dateMatching: quando, repeats: false)
        )
        UNUserNotificationCenter.current().add(pedido)
    }

    /// Muda quando muda alguma coisa que o texto diz.
    private static func chave(_ aviso: Aviso) -> String {
        "\(aviso.itemId)|\(aviso.data.timeIntervalSince1970)|\(aviso.expiraEm.timeIntervalSince1970)|\(aviso.subtopicosPorFazer)|\(aviso.lista ?? "")"
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
        let lista = UNNotificationCategory(
            identifier: Self.categoriaLista,
            actions: [
                UNNotificationAction(identifier: Acao.manterLista.rawValue, title: "Manter mais \(definicoes.diasListaVazia) dias"),
                UNNotificationAction(identifier: Acao.permanente.rawValue, title: "Tornar permanente"),
            ],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([categoria, lista])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let acao = Acao(rawValue: response.actionIdentifier)
        let identificador = response.notification.request.identifier
        DispatchQueue.main.async {
            if let acao {
                if identificador.hasPrefix(Self.prefixoLista),
                   let id = UUID(uuidString: String(identificador.dropFirst(Self.prefixoLista.count))) {
                    self.tratar(acao, listaId: id)
                } else if let id = UUID(uuidString: identificador) {
                    self.tratar(acao, itemId: id)
                }
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
        case .manterLista, .permanente: return
        }
        try? contexto.save()
        reagendar()
    }

    /// "Tornar permanente" com as 4 já ocupadas mantém a lista mais 5 dias, em vez de não
    /// fazer nada: o pedido era que não desaparecesse.
    private func tratar(_ acao: Acao, listaId: UUID) {
        let contexto = ModelContext(contentor)
        var pedido = FetchDescriptor<Lista>(predicate: #Predicate { $0.id == listaId })
        pedido.fetchLimit = 1
        guard let lista = try? contexto.fetch(pedido).first else { return }
        let tarefas = Tarefas(contexto: contexto)
        switch acao {
        case .permanente:
            if (try? tarefas.definirPermanente(lista, true)) == nil {
                tarefas.manterLista(lista)
            }
        case .manterLista:
            tarefas.manterLista(lista)
        case .manterCurto, .manterLongo, .concluir:
            return
        }
        try? contexto.save()
        reagendar()
    }
}
