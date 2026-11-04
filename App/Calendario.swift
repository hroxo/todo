import EventKit
import Observation
import SwiftData
import SwiftUI
import ToDoCore

/// Um participante de um convite (Melhoria 6.2).
struct Participante: Hashable, Sendable {
    let nome: String
    let resposta: RespostaConvite
}

/// Um evento de hoje, já pronto para a interface.
struct EventoHoje: Identifiable, Equatable, Sendable {
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

/// Um calendário do iPhone já em valores: sai da leitura em segundo plano e compara-se com o anterior.
struct CalendarioLocal: Equatable, Sendable {
    let id: String
    let titulo: String
    let conta: String
    let cor: Color
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
    /// Eventos de hoje do iPhone e das contas ligadas, sem os repetidos (fica a versão da
    /// conta ligada, que tem mais detalhes) nem os dos calendários escondidos. Guardados: os
    /// ecrãs leem-nos várias vezes em cada desenho, e só mudam quando há diferenças.
    private(set) var eventos: [EventoHoje] = []
    private(set) var calendarios: [CalendarioLocal] = []
    /// A app morreu ou bloqueou com o calendário: não se mostra outra vez sem a pessoa pedir, para o
    /// calendário nunca impedir a app de abrir (DESIGN.md 7.12).
    private(set) var leituraFalhou = false
    /// Contas Google e Outlook ligadas diretamente (Melhoria 7).
    let contas = ContasCalendario()
    /// Identificador do calendário → identificador do espaço (UUID da lista, em texto), ou
    /// `oculto`. Sem entrada: sem espaço.
    private(set) var espacos: [String: String]
    @ObservationIgnored private let marcaOculto = "oculto"
    /// Calendários já vistos: a associação automática por nome só se faz aos novos.
    @ObservationIgnored private var conhecidos: Set<String>

    /// Eventos de hoje do EventKit e a conversão de cada um, para só converter os que mudam.
    @ObservationIgnored private var locais: [EventoHoje] = []
    @ObservationIgnored private var convertidos: [String: Convertido<EventoHoje>] = [:]

    @ObservationIgnored private let loja = EKEventStore()
    @ObservationIgnored private let contentor: ModelContainer
    @ObservationIgnored private var observador: NSObjectProtocol?
    @ObservationIgnored private var leitura: Task<Void, Never>?
    @ObservationIgnored private let chaveLeitura = "calendarioALer"
    @ObservationIgnored private let chaveEspacos = "calendariosEspacos"
    @ObservationIgnored private let chaveConhecidos = "calendariosConhecidos"

    /// Mostra os eventos se o EventKit tiver acesso ou houver uma conta ligada.
    var mostraEventos: Bool {
        acesso == .autorizado || contas.temContas
    }

    init(contentor: ModelContainer) {
        self.contentor = contentor
        // Na demonstração as listas mudam a cada arranque: nada se lê nem grava.
        espacos = Demo.ativo ? [:] : UserDefaults.standard.dictionary(forKey: chaveEspacos) as? [String: String] ?? [:]
        conhecidos = Demo.ativo ? [] : Set(UserDefaults.standard.stringArray(forKey: chaveConhecidos) ?? [])
        #if DEBUG
        if Demo.ativo {
            prepararDemo()
            return
        }
        #endif
        leituraFalhou = UserDefaults.standard.bool(forKey: chaveLeitura)
        lerAcesso()
        // A primeira leitura vem de `ToDoApp`, ao ficar ativa: aqui atrasaria o primeiro ecrã.
        observador = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: loja,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.atualizar() }
        }
    }

    /// Fontes ligadas, para as Definições ("Gmail, iCloud").
    var fontes: String {
        let ligadas = contas.contas.keys.map(\.nome)
        return Set(calendarios.map(\.conta) + ligadas).sorted().joined(separator: ", ")
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
        guard !Demo.ativo, ToDoApp.erroBaseDados == nil else { return }
        lerAcesso()
        atualizarContas()
        leitura?.cancel()
        guard acesso == .autorizado, !leituraFalhou else {
            calendarios = []
            locais = []
            convertidos = [:]
            juntarEventos()
            return
        }
        juntarEventos()
        leitura = Task {
            // Os avisos do EventKit vêm em rajadas, sobretudo depois de dar acesso: só o último lê.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            marcarLeitura(true)
            await lerEventos()
            // Os eventos ainda têm de se desenhar: só depois disso a leitura correu bem.
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            marcarLeitura(false)
        }
    }

    /// O EventKit não diz o que mudou, por isso relê-se o dia; tudo fora da thread principal, e
    /// só o que tem diferenças se converte e chega aos ecrãs.
    private func lerEventos() async {
        let lidos = await Task.detached { [loja = self.loja] in Self.lerCalendarios(loja) }.value
        guard !Task.isCancelled else { return }
        if lidos != calendarios { calendarios = lidos }
        associarNovos(lidos.map { ($0.id, $0.titulo) })
        let ocultos = Set(espacos.filter { $0.value == marcaOculto }.keys)
        let hoje = await Task.detached { [loja = self.loja, anteriores = convertidos] in
            Self.lerEventosDeHoje(loja, ocultos: ocultos, anteriores: anteriores)
        }.value
        convertidos = hoje.convertidos
        guard !Task.isCancelled, hoje.valores != locais else { return }
        locais = hoje.valores
        juntarEventos()
    }

    private func juntarEventos() {
        let externos = contas.eventos.filter { espacos[$0.calendarioId] != marcaOculto }
        let juntos = JuntarEventos.juntar(
            locais: locais,
            externos: externos,
            chaveLocal: { ($0.eventoId, $0.inicio) },
            chaveExterno: { ($0.id, $0.inicio) }
        )
        let novos = (juntos.locais + juntos.externos.map(converterExterno))
            .sorted { ($0.diaInteiro ? 0 : 1, $0.inicio) < ($1.diaInteiro ? 0 : 1, $1.inicio) }
        if novos != eventos { eventos = novos }
    }

    nonisolated private static func lerCalendarios(_ loja: EKEventStore) -> [CalendarioLocal] {
        loja.calendars(for: .event)
            .map { CalendarioLocal(id: $0.calendarIdentifier, titulo: $0.title, conta: $0.source.title, cor: Color(cgColor: $0.cgColor)) }
            .sorted { ($0.conta, $0.titulo) < ($1.conta, $1.titulo) }
    }

    nonisolated private static func lerEventosDeHoje(
        _ loja: EKEventStore,
        ocultos: Set<String>,
        anteriores: [String: Convertido<EventoHoje>]
    ) -> (valores: [EventoHoje], convertidos: [String: Convertido<EventoHoje>]) {
        let visiveis = loja.calendars(for: .event).filter { !ocultos.contains($0.calendarIdentifier) }
        guard !visiveis.isEmpty else { return ([], [:]) }
        let inicioDoDia = Calendar.current.startOfDay(for: .now)
        let fimDoDia = Calendar.current.date(byAdding: .day, value: 1, to: inicioDoDia)!
        let pedido = loja.predicateForEvents(withStart: inicioDoDia, end: fimDoDia, calendars: visiveis)
        let eventos = loja.events(matching: pedido)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
        return Diferencas.aplicar(
            eventos,
            anteriores: anteriores,
            chave: { ($0.calendarItemExternalIdentifier ?? $0.calendarItemIdentifier) + "-\($0.startDate.timeIntervalSince1970)" },
            assinatura: assinatura,
            converter: converter
        )
    }

    /// O que indica que um evento mudou, sem tocar nas partes caras de converter.
    // shortcut: não inclui os participantes nem a cor, por serem caros ou raros; a diferença pode só aparecer ao reabrir a app.
    nonisolated private static func assinatura(_ evento: EKEvent) -> String? {
        guard let alterado = evento.lastModifiedDate else { return nil }
        return [
            "\(alterado.timeIntervalSince1970)",
            "\(evento.endDate.timeIntervalSince1970)",
            "\(evento.isAllDay)",
            evento.title ?? "",
            evento.location ?? "",
            evento.calendar.calendarIdentifier,
            evento.calendar.title,
        ].joined(separator: "|")
    }

    /// Tentar outra vez, depois de a app ter morrido a ler.
    func lerOutraVez() {
        leituraFalhou = false
        marcarLeitura(false)
        atualizar()
    }

    /// Um bloqueio ao desenhar não é um crash nem chega à leitura: a marca tem de vir antes dela.
    func marcarAbertura() {
        guard !Demo.ativo, ToDoApp.erroBaseDados == nil, acesso == .autorizado, !leituraFalhou else { return }
        marcarLeitura(true)
    }

    /// Chegar ao segundo plano prova que a app sobreviveu à leitura.
    func aoSairParaSegundoPlano() {
        guard !leituraFalhou else { return }
        leitura?.cancel()
        marcarLeitura(false)
    }

    private func marcarLeitura(_ aLer: Bool) {
        UserDefaults.standard.set(aLer, forKey: chaveLeitura)
        // A marca tem de sobreviver a um crash logo a seguir.
        UserDefaults.standard.synchronize()
    }

    /// Lê as contas ligadas em segundo plano; os calendários novos ficam associados por nome.
    func atualizarContas() {
        guard contas.temContas else { return }
        let ocultos = Set(espacos.filter { $0.value == marcaOculto }.keys)
        Task {
            await contas.atualizar(ocultos: ocultos)
            associarNovos(contas.calendarios.map { ($0.id, $0.nome) })
            juntarEventos()
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

    nonisolated private static func converter(_ evento: EKEvent) -> EventoHoje {
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

    nonisolated private static func nomeParticipante(_ participante: EKParticipant) -> String {
        if let nome = participante.name, !nome.isEmpty { return nome }
        // Sem nome, o endereço vem como "mailto:ana@exemplo.pt".
        let endereco = participante.url.absoluteString
        return endereco.hasPrefix("mailto:") ? String(endereco.dropFirst(7)) : endereco
    }

    nonisolated private static func resposta(de participante: EKParticipant) -> RespostaConvite {
        switch participante.participantStatus {
        case .accepted: .aceite
        case .declined: .recusado
        case .tentative: .talvez
        default: .pendente
        }
    }

    /// O espaço guardado de um calendário. Corre por cada evento em cada desenho, por isso não
    /// vai à base de dados: quem chama procura-o nas listas, e um espaço apagado não aparece.
    func espaco(de calendarioId: String) -> UUID? {
        espacos[calendarioId].flatMap(UUID.init(uuidString:))
    }

    func destino(de calendarioId: String) -> DestinoCalendario {
        if espacos[calendarioId] == marcaOculto { return .oculto }
        guard let id = espaco(de: calendarioId), idsDosEspacos().contains(id) else { return .semEspaco }
        return .espaco(id)
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
        calendarios.first { $0.id == calendarioId }?.titulo
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

    #if DEBUG
    /// Eventos de exemplo para as capturas de ecrã (`-calendario ligar` e `-calendario falhou`
    /// mostram os cartões).
    private func prepararDemo() {
        guard UserDefaults.standard.string(forKey: "calendario") != "ligar" else {
            acesso = .porPedir
            return
        }
        acesso = .autorizado
        guard UserDefaults.standard.string(forKey: "calendario") != "falhou" else {
            leituraFalhou = true
            return
        }
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
        juntarEventos()
    }
    #endif
}
