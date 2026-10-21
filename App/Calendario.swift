import EventKit
import Observation
import SwiftData
import SwiftUI
import ToDoCore

/// Um evento de hoje, já pronto para a interface.
struct EventoHoje: Identifiable, Equatable {
    let id: String
    let titulo: String
    let inicio: Date
    let fim: Date
    let diaInteiro: Bool
    /// Local e calendário ("Sala 3 · Trabalho").
    let detalhe: String
    let cor: Color
    let calendarioId: String

    func aDecorrer(em agora: Date) -> Bool {
        !diaInteiro && inicio <= agora && agora < fim
    }
}

/// Leitura do calendário pelo EventKit (especificação 4.7): com uma só permissão, vê os
/// calendários de todas as contas do iPhone (iCloud, Google, Outlook). Só lê; nada sai do
/// telemóvel. Cada calendário fica associado a um espaço (lista) ou a nenhum; só os eventos
/// de calendários com espaço aparecem no Início.
@MainActor
@Observable
final class Calendario {
    enum Acesso {
        case porPedir, autorizado, recusado
    }

    private(set) var acesso: Acesso = .porPedir
    private(set) var eventos: [EventoHoje] = []
    private(set) var calendarios: [EKCalendar] = []
    /// Identificador do calendário → identificador do espaço (UUID da lista, em texto).
    private(set) var espacos: [String: String]
    /// Calendários já vistos: a associação automática por nome só se faz aos novos.
    @ObservationIgnored private var conhecidos: Set<String>

    @ObservationIgnored private let loja = EKEventStore()
    @ObservationIgnored private let contentor: ModelContainer
    @ObservationIgnored private var observador: NSObjectProtocol?
    @ObservationIgnored private let chaveEspacos = "calendariosEspacos"
    @ObservationIgnored private let chaveConhecidos = "calendariosConhecidos"

    init(contentor: ModelContainer) {
        self.contentor = contentor
        // Na demonstração as listas mudam a cada arranque: nada se lê nem grava.
        espacos = Demo.ativo ? [:] : UserDefaults.standard.dictionary(forKey: chaveEspacos) as? [String: String] ?? [:]
        conhecidos = Demo.ativo ? [] : Set(UserDefaults.standard.stringArray(forKey: chaveConhecidos) ?? [])
        if Demo.ativo {
            prepararDemo()
            return
        }
        lerAcesso()
        observador = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: loja,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.atualizar() }
        }
        atualizar()
    }

    /// Fontes ligadas, para as Definições ("Gmail, iCloud").
    var fontes: String {
        Set(calendarios.map(\.source.title)).sorted().joined(separator: ", ")
    }

    func pedirAcesso() async {
        if Demo.ativo {
            acesso = .autorizado
            return
        }
        _ = try? await loja.requestFullAccessToEvents()
        lerAcesso()
        atualizar()
    }

    func atualizar() {
        guard !Demo.ativo else { return }
        lerAcesso()
        guard acesso == .autorizado else {
            calendarios = []
            eventos = []
            return
        }
        calendarios = loja.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
        associarNovos(calendarios.map { ($0.calendarIdentifier, $0.title) })
        let visiveis = calendarios.filter { espaco(de: $0.calendarIdentifier) != nil }
        guard !visiveis.isEmpty else {
            eventos = []
            return
        }
        let inicioDoDia = Calendar.current.startOfDay(for: .now)
        let fimDoDia = Calendar.current.date(byAdding: .day, value: 1, to: inicioDoDia)!
        let pedido = loja.predicateForEvents(withStart: inicioDoDia, end: fimDoDia, calendars: visiveis)
        eventos = loja.events(matching: pedido)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map { evento in
                let titulo = evento.title ?? ""
                let detalhe = evento.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return EventoHoje(
                    id: (evento.eventIdentifier ?? UUID().uuidString) + "-\(evento.startDate.timeIntervalSince1970)",
                    titulo: titulo.isEmpty ? "Sem título" : titulo,
                    inicio: evento.startDate,
                    fim: evento.endDate,
                    diaInteiro: evento.isAllDay,
                    detalhe: detalhe,
                    cor: Color(cgColor: evento.calendar.cgColor),
                    calendarioId: evento.calendar.calendarIdentifier
                )
            }
    }

    /// O espaço de um calendário, se ainda existir.
    func espaco(de calendarioId: String) -> UUID? {
        guard let texto = espacos[calendarioId], let id = UUID(uuidString: texto) else { return nil }
        return idsDosEspacos().contains(id) ? id : nil
    }

    /// Associa um calendário a um espaço, ou a nenhum (`nil`).
    func definir(_ calendarioId: String, espaco: UUID?) {
        espacos[calendarioId] = espaco?.uuidString
        if !Demo.ativo { UserDefaults.standard.set(espacos, forKey: chaveEspacos) }
        atualizar()
    }

    /// Calendários vistos pela primeira vez: os que têm o nome de um espaço ficam nele; os
    /// outros ficam em "Nenhum" (especificação 4.7).
    private func associarNovos(_ lista: [(id: String, titulo: String)]) {
        let novos = lista.filter { !conhecidos.contains($0.id) }
        guard !novos.isEmpty else { return }
        let contexto = ModelContext(contentor)
        let espacosAtuais = ((try? contexto.fetch(FetchDescriptor<Lista>())) ?? []).map { ($0.id, $0.nome) }
        for (calendarioId, espacoId) in Espacos.associarPorNome(calendarios: novos, espacos: espacosAtuais) {
            espacos[calendarioId] = espacoId.uuidString
        }
        conhecidos.formUnion(novos.map(\.id))
        guard !Demo.ativo else { return }
        UserDefaults.standard.set(espacos, forKey: chaveEspacos)
        UserDefaults.standard.set(Array(conhecidos), forKey: chaveConhecidos)
    }

    private func idsDosEspacos() -> Set<UUID> {
        Set(((try? ModelContext(contentor).fetch(FetchDescriptor<Lista>())) ?? []).map(\.id))
    }

    private func lerAcesso() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: acesso = .autorizado
        case .notDetermined: acesso = .porPedir
        default: acesso = .recusado
        }
    }

    /// Eventos de exemplo para as capturas de ecrã (`-calendario ligar` mostra o cartão).
    private func prepararDemo() {
        guard UserDefaults.standard.string(forKey: "calendario") != "ligar" else {
            acesso = .porPedir
            return
        }
        acesso = .autorizado
        let agora = Date.now
        let hoje = Calendar.current.startOfDay(for: agora)
        func as_(_ hora: Int, _ minuto: Int) -> Date {
            Calendar.current.date(bySettingHour: hora, minute: minuto, second: 0, of: hoje)!
        }
        // Os calendários de exemplo têm o nome dos espaços, para a associação por nome.
        eventos = [
            EventoHoje(id: "1", titulo: "Treino de força", inicio: as_(7, 30), fim: as_(8, 30),
                       diaInteiro: false, detalhe: "", cor: .red, calendarioId: "Ginásio"),
            EventoHoje(id: "2", titulo: "Daily da equipa", inicio: agora.addingTimeInterval(-600),
                       fim: agora.addingTimeInterval(1200), diaInteiro: false, detalhe: "Teams", cor: .blue,
                       calendarioId: "Trabalho"),
            EventoHoje(id: "3", titulo: "Revisão do roadmap Q1", inicio: as_(14, 30), fim: as_(15, 30),
                       diaInteiro: false, detalhe: "Sala 3", cor: .blue, calendarioId: "Trabalho"),
            EventoHoje(id: "4", titulo: "Jantar com a Ana", inicio: as_(21, 0), fim: as_(22, 30),
                       diaInteiro: false, detalhe: "", cor: .green, calendarioId: "Pessoal"),
        ]
        associarNovos(eventos.map { ($0.calendarioId, $0.calendarioId) })
    }
}
