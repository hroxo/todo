import EventKit
import Observation
import SwiftData
import SwiftUI
import ToDoCore

/// Um participante de um convite (Melhoria 6.2).
struct Participante: Hashable {
    let nome: String
    let resposta: RespostaConvite
}

/// Um evento de hoje, já pronto para a interface.
struct EventoHoje: Identifiable, Equatable {
    let id: String
    /// Identificador externo do evento (o mesmo em todos os dispositivos), para o "+" só
    /// funcionar uma vez por ocorrência (Melhoria 6.4).
    let eventoId: String
    let titulo: String
    let inicio: Date
    let fim: Date
    let diaInteiro: Bool
    /// Local ("Sala 3"), ou vazio.
    let detalhe: String
    let cor: Color
    let calendarioId: String
    let calendarioNome: String
    var organizador: String?
    var participantes: [Participante] = []
    /// Notas do evento: é aqui que costuma estar o texto do convite.
    var notas: String = ""
    var link: URL?

    func aDecorrer(em agora: Date) -> Bool {
        !diaInteiro && inicio <= agora && agora < fim
    }
}

/// Onde aparecem os eventos de um calendário no Início.
enum DestinoCalendario: Equatable {
    case espaco(UUID)
    /// Aparecem, com "Sem espaço" (Melhoria 6.1).
    case semEspaco
    /// Não aparecem.
    case oculto
}

/// Leitura do calendário pelo EventKit (especificação 4.7): com uma só permissão, vê os
/// calendários de todas as contas do iPhone (iCloud, Google, Outlook). Só lê; nada sai do
/// telemóvel. Cada calendário fica associado a um espaço (lista), sem espaço ou escondido;
/// os eventos sem espaço também aparecem no Início (Melhoria 6.1).
@MainActor
@Observable
final class Calendario {
    enum Acesso {
        case porPedir, autorizado, recusado
    }

    private(set) var acesso: Acesso = .porPedir
    /// Eventos de hoje do EventKit.
    private(set) var locais: [EventoHoje] = []
    private(set) var calendarios: [EKCalendar] = []
    /// Contas Google e Outlook ligadas diretamente (Melhoria 7).
    let contas = ContasCalendario()
    /// Identificador do calendário → identificador do espaço (UUID da lista, em texto), ou
    /// `oculto`. Sem entrada: sem espaço.
    private(set) var espacos: [String: String]
    @ObservationIgnored private let marcaOculto = "oculto"
    /// Calendários já vistos: a associação automática por nome só se faz aos novos.
    @ObservationIgnored private var conhecidos: Set<String>

    @ObservationIgnored private let loja = EKEventStore()
    @ObservationIgnored private let contentor: ModelContainer
    @ObservationIgnored private var observador: NSObjectProtocol?
    @ObservationIgnored private let chaveEspacos = "calendariosEspacos"
    @ObservationIgnored private let chaveConhecidos = "calendariosConhecidos"

    /// Eventos de hoje do iPhone e das contas ligadas, sem os repetidos (fica a versão da
    /// conta ligada, que tem mais detalhes) nem os dos calendários escondidos.
    var eventos: [EventoHoje] {
        let externos = contas.eventos.filter { destino(de: $0.calendarioId) != .oculto }
        let juntos = JuntarEventos.juntar(
            locais: locais,
            externos: externos,
            chaveLocal: { ($0.eventoId, $0.inicio) },
            chaveExterno: { ($0.id, $0.inicio) }
        )
        return (juntos.locais + juntos.externos.map(converterExterno))
            .sorted { ($0.diaInteiro ? 0 : 1, $0.inicio) < ($1.diaInteiro ? 0 : 1, $1.inicio) }
    }

    /// Mostra os eventos se o EventKit tiver acesso ou houver uma conta ligada.
    var mostraEventos: Bool {
        acesso == .autorizado || contas.temContas
    }

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
        let ligadas = contas.contas.keys.map(\.nome)
        return Set(calendarios.map(\.source.title) + ligadas).sorted().joined(separator: ", ")
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
        atualizarContas()
        guard acesso == .autorizado else {
            calendarios = []
            locais = []
            return
        }
        calendarios = loja.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
        associarNovos(calendarios.map { ($0.calendarIdentifier, $0.title) })
        let visiveis = calendarios.filter { destino(de: $0.calendarIdentifier) != .oculto }
        guard !visiveis.isEmpty else {
            locais = []
            return
        }
        let inicioDoDia = Calendar.current.startOfDay(for: .now)
        let fimDoDia = Calendar.current.date(byAdding: .day, value: 1, to: inicioDoDia)!
        let pedido = loja.predicateForEvents(withStart: inicioDoDia, end: fimDoDia, calendars: visiveis)
        locais = loja.events(matching: pedido)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map(Self.converter)
    }

    /// Lê as contas ligadas em segundo plano; os calendários novos ficam associados por nome.
    func atualizarContas() {
        guard contas.temContas else { return }
        let ocultos = Set(espacos.filter { $0.value == marcaOculto }.keys)
        Task {
            await contas.atualizar(ocultos: ocultos)
            associarNovos(contas.calendarios.map { ($0.id, $0.nome) })
        }
    }

    private func converterExterno(_ evento: EventoExterno) -> EventoHoje {
        let calendario = contas.calendarios.first { $0.id == evento.calendarioId }
        let cor = calendario?.corHex.flatMap(Color.init(hex:))
            ?? (calendario?.fornecedor == .microsoft ? Color.blue : Color.green)
        return EventoHoje(
            id: evento.id + "-\(evento.inicio.timeIntervalSince1970)",
            eventoId: evento.id,
            titulo: evento.titulo,
            inicio: evento.inicio,
            fim: evento.fim,
            diaInteiro: evento.diaInteiro,
            detalhe: evento.local,
            cor: cor,
            calendarioId: evento.calendarioId,
            calendarioNome: calendario?.nome ?? "",
            organizador: evento.organizador,
            participantes: evento.participantes.map { Participante(nome: $0.nome, resposta: $0.resposta) },
            notas: evento.notas,
            link: evento.link
        )
    }

    private static func converter(_ evento: EKEvent) -> EventoHoje {
        let titulo = evento.title ?? ""
        let local = evento.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let notas = evento.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let eventoId = evento.calendarItemExternalIdentifier ?? evento.calendarItemIdentifier
        return EventoHoje(
            id: eventoId + "-\(evento.startDate.timeIntervalSince1970)",
            eventoId: eventoId,
            titulo: titulo.isEmpty ? "Sem título" : titulo,
            inicio: evento.startDate,
            fim: evento.endDate,
            diaInteiro: evento.isAllDay,
            detalhe: local,
            cor: Color(cgColor: evento.calendar.cgColor),
            calendarioId: evento.calendar.calendarIdentifier,
            calendarioNome: evento.calendar.title,
            organizador: evento.organizer.map(nomeParticipante),
            // Em algumas contas os participantes vêm vazios: a vista esconde a secção.
            participantes: (evento.attendees ?? []).map { Participante(nome: nomeParticipante($0), resposta: resposta(de: $0)) },
            notas: notas,
            link: LigacaoReuniao.encontrar(url: evento.url, local: local, notas: notas)
        )
    }

    private static func nomeParticipante(_ participante: EKParticipant) -> String {
        if let nome = participante.name, !nome.isEmpty { return nome }
        // Sem nome, o endereço vem como "mailto:ana@exemplo.pt".
        let endereco = participante.url.absoluteString
        return endereco.hasPrefix("mailto:") ? String(endereco.dropFirst(7)) : endereco
    }

    private static func resposta(de participante: EKParticipant) -> RespostaConvite {
        switch participante.participantStatus {
        case .accepted: .aceite
        case .declined: .recusado
        case .tentative: .talvez
        default: .pendente
        }
    }

    /// O espaço de um calendário, se ainda existir.
    func espaco(de calendarioId: String) -> UUID? {
        guard let texto = espacos[calendarioId], let id = UUID(uuidString: texto) else { return nil }
        return idsDosEspacos().contains(id) ? id : nil
    }

    func destino(de calendarioId: String) -> DestinoCalendario {
        if espacos[calendarioId] == marcaOculto { return .oculto }
        return espaco(de: calendarioId).map(DestinoCalendario.espaco) ?? .semEspaco
    }

    /// Associa um calendário a um espaço, deixa-o sem espaço ou esconde-o.
    func definir(_ calendarioId: String, destino: DestinoCalendario) {
        switch destino {
        case .espaco(let id): espacos[calendarioId] = id.uuidString
        case .semEspaco: espacos[calendarioId] = nil
        case .oculto: espacos[calendarioId] = marcaOculto
        }
        if !Demo.ativo { UserDefaults.standard.set(espacos, forKey: chaveEspacos) }
        if Demo.ativo { return }
        atualizar()
    }

    /// Nome de um calendário, para as Definições e a vista de um evento.
    func nome(de calendarioId: String) -> String {
        calendarios.first { $0.calendarIdentifier == calendarioId }?.title
            ?? contas.calendarios.first { $0.id == calendarioId }?.nome
            ?? eventos.first { $0.calendarioId == calendarioId }?.calendarioNome
            ?? ""
    }

    /// Calendários vistos pela primeira vez: os que têm o nome de um espaço ficam nele; os
    /// outros ficam sem espaço (especificação 4.7).
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
        func evento(_ id: String, _ titulo: String, _ inicio: Date, _ fim: Date, _ local: String, _ cor: Color, _ calendario: String) -> EventoHoje {
            EventoHoje(id: id, eventoId: "demo-\(id)", titulo: titulo, inicio: inicio, fim: fim, diaInteiro: false,
                       detalhe: local, cor: cor, calendarioId: calendario, calendarioNome: calendario)
        }
        var convite = evento("5", "Alinhamento com a agência", as_(16, 0), as_(16, 45), "", .purple, "Convites")
        convite.organizador = "Marta Silva"
        convite.participantes = [
            Participante(nome: "Marta Silva", resposta: .aceite),
            Participante(nome: "Hugo Roxo", resposta: .pendente),
            Participante(nome: "Rui Costa", resposta: .talvez),
            Participante(nome: "Inês Lopes", resposta: .recusado),
        ]
        convite.notas = "Olá a todos,\nVamos rever a proposta da campanha de novembro e fechar o calendário de entregas.\n\nReunião do Microsoft Teams\nhttps://teams.microsoft.com/l/meetup-join/exemplo"
        convite.link = LigacaoReuniao.encontrar(url: nil, local: nil, notas: convite.notas)
        // Os calendários de exemplo têm o nome dos espaços, para a associação por nome; o de
        // "Convites" fica sem espaço.
        locais = [
            evento("1", "Treino de força", as_(7, 30), as_(8, 30), "", .red, "Ginásio"),
            evento("2", "Daily da equipa", agora.addingTimeInterval(-600), agora.addingTimeInterval(1200), "Teams", .blue, "Trabalho"),
            evento("3", "Revisão do roadmap Q1", as_(14, 30), as_(15, 30), "Sala 3", .blue, "Trabalho"),
            convite,
            evento("4", "Jantar com a Ana", as_(21, 0), as_(22, 30), "", .green, "Pessoal"),
        ].sorted { $0.inicio < $1.inicio }
        associarNovos(locais.map { ($0.calendarioId, $0.calendarioId) })
    }
}
