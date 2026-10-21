import EventKit
import Observation
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

    func aDecorrer(em agora: Date) -> Bool {
        !diaInteiro && inicio <= agora && agora < fim
    }
}

/// Leitura do calendário pelo EventKit (especificação 4.7): com uma só permissão, vê os
/// calendários de todas as contas do iPhone (iCloud, Google, Outlook). Só lê; nada sai do
/// telemóvel.
@MainActor
@Observable
final class Calendario {
    enum Acesso {
        case porPedir, autorizado, recusado
    }

    private(set) var acesso: Acesso = .porPedir
    private(set) var eventos: [EventoHoje] = []
    private(set) var calendarios: [EKCalendar] = []
    /// Identificadores dos calendários escondidos; os novos aparecem por defeito.
    private(set) var ocultos: Set<String>

    @ObservationIgnored private let loja = EKEventStore()
    @ObservationIgnored private var observador: NSObjectProtocol?
    @ObservationIgnored private let chaveOcultos = "calendariosOcultos"

    init() {
        ocultos = Set(UserDefaults.standard.stringArray(forKey: chaveOcultos) ?? [])
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
        let visiveis = calendarios.filter { !ocultos.contains($0.calendarIdentifier) }
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
                let detalhe = [evento.location, evento.calendar.title]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                return EventoHoje(
                    id: (evento.eventIdentifier ?? UUID().uuidString) + "-\(evento.startDate.timeIntervalSince1970)",
                    titulo: titulo.isEmpty ? "Sem título" : titulo,
                    inicio: evento.startDate,
                    fim: evento.endDate,
                    diaInteiro: evento.isAllDay,
                    detalhe: detalhe,
                    cor: Color(cgColor: evento.calendar.cgColor)
                )
            }
    }

    func visivel(_ calendario: EKCalendar) -> Bool {
        !ocultos.contains(calendario.calendarIdentifier)
    }

    func definir(_ calendario: EKCalendar, visivel: Bool) {
        if visivel {
            ocultos.remove(calendario.calendarIdentifier)
        } else {
            ocultos.insert(calendario.calendarIdentifier)
        }
        UserDefaults.standard.set(Array(ocultos), forKey: chaveOcultos)
        atualizar()
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
        eventos = [
            EventoHoje(id: "1", titulo: "Daily da equipa", inicio: agora.addingTimeInterval(-600),
                       fim: agora.addingTimeInterval(1200), diaInteiro: false, detalhe: "Teams · Trabalho", cor: .blue),
            EventoHoje(id: "2", titulo: "Revisão do roadmap Q1", inicio: as_(14, 30), fim: as_(15, 30),
                       diaInteiro: false, detalhe: "Sala 3 · Trabalho", cor: .blue),
            EventoHoje(id: "3", titulo: "Ginásio", inicio: as_(19, 0), fim: as_(20, 0),
                       diaInteiro: false, detalhe: "Pessoal", cor: .green),
        ]
    }
}
