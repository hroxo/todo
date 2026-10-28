import Foundation

/// O cartão "Para ti" no topo do Início (DESIGN.md 7.21): o que importa agora, numa frase
/// curta e com até duas ações. O núcleo decide o que é relevante; o modelo do iPhone só reescreve a
/// frase (a `fraseBase` fica quando ele não está disponível). Sem nada relevante, não há
/// cartão.
public struct ParaTi: Equatable, Sendable {
    public enum Motivo: String, Equatable, Sendable {
        case prazos, listaASair, evento, vistaPartilhada
    }

    public enum Acao: Equatable, Sendable {
        case abrirItem(UUID)
        case manter(UUID)
        case abrirLista(UUID)
        case tornarPermanente(UUID)
        case manterLista(UUID)
    }

    public struct Botao: Equatable, Sendable, Identifiable {
        public let rotulo: String
        public let acao: Acao
        public var id: String { rotulo }
    }

    public let motivo: Motivo
    public let fraseBase: String
    /// Os factos para o modelo do iPhone escrever a frase (sem inventar nada).
    public let factos: [String]
    public let botoes: [Botao]

    /// Muda quando muda o que o cartão diz: para não repetir o modelo e para "dispensar".
    public var chave: String {
        ([motivo.rawValue, fraseBase] + botoes.map(\.rotulo)).joined(separator: "|")
    }
}

/// Um evento do calendário nas próximas horas, já com o espaço (lista) a que pertence.
public struct EventoProximo: Equatable, Sendable {
    public let titulo: String
    public let inicio: Date
    public let listaId: UUID?

    public init(titulo: String, inicio: Date, listaId: UUID?) {
        self.titulo = titulo
        self.inicio = inicio
        self.listaId = listaId
    }
}

extension Tarefas {
    /// O que mostrar em "Para ti", pela ordem de importância:
    /// 1. pontos no último dia do prazo;
    /// 2. uma lista vazia que sai nas próximas 24 horas;
    /// 3. um evento nas próximas 3 horas cujo espaço tem um ponto com subtópicos por fazer;
    /// 4. uma vista partilhada a meio, mexida nos últimos 2 dias.
    /// Nil quando nada disto existe: o cartão não aparece.
    public func paraTi(eventos: [EventoProximo] = []) throws -> ParaTi? {
        let agora = relogio.agora
        if let prazos = try paraTiPrazos(agora) { return prazos }
        if let lista = try paraTiListaASair(agora) { return lista }
        if let evento = try paraTiEvento(eventos, agora: agora) { return evento }
        return try paraTiVistaPartilhada(agora)
    }

    private func paraTiPrazos(_ agora: Date) throws -> ParaTi? {
        let hoje = try prioridades(limite: 10).filter { Prazo(item: $0.item, agora: agora)?.ultimoDia == true }
        guard let primeiro = hoje.first?.item, let limite = primeiro.expiraEm else { return nil }
        let hora = Formatos.hora(limite, calendario: calendario)
        let dia = calendario.isDate(limite, inSameDayAs: agora) ? "hoje" : "amanhã"
        // A hora antes do título: no cartão compacto, um título longo corta-se no fim.
        let fraseBase = hoje.count == 1
            ? "Expira \(dia) às \(hora): «\(primeiro.titulo)»."
            : "\(hoje.count) pontos expiram em breve, o primeiro \(dia) às \(hora): «\(primeiro.titulo)»."
        var factos = hoje.prefix(3).map { "\($0.item.titulo) (\($0.item.lista?.nome ?? "")): \($0.razao)" }
        factos.insert("Pontos a expirar nas próximas 24 horas: \(hoje.count)", at: 0)
        let botoes = [
            ParaTi.Botao(rotulo: "Abrir", acao: .abrirItem(primeiro.id)),
            ParaTi.Botao(rotulo: "Manter +\(definicoes.diasManterCurto)", acao: .manter(primeiro.id)),
        ]
        return ParaTi(motivo: .prazos, fraseBase: fraseBase, factos: factos, botoes: botoes)
    }

    private func paraTiListaASair(_ agora: Date) throws -> ParaTi? {
        let lista = try listas().first { lista in
            guard let fim = quandoDesaparece(lista) else { return false }
            return fim.timeIntervalSince(agora) <= 24 * 3600
        }
        guard let lista, let fim = quandoDesaparece(lista) else { return nil }
        let quando = calendario.isDate(fim, inSameDayAs: agora) ? "hoje" : "amanhã"
        let botoes = try [
            podeSerPermanente()
                ? ParaTi.Botao(rotulo: "Tornar permanente", acao: .tornarPermanente(lista.id))
                : nil,
            ParaTi.Botao(rotulo: "Mais \(Formatos.dias(definicoes.diasListaVazia))", acao: .manterLista(lista.id)),
        ].compactMap { $0 }
        return ParaTi(
            motivo: .listaASair,
            fraseBase: "A lista «\(lista.nome)» está sem pontos e sai do Início \(quando). Queres guardá-la?",
            factos: [
                "Lista: \(lista.nome)",
                "Sem pontos abertos desde: \(Formatos.dia(lista.vaziaDesde ?? agora, agora: agora, calendario: calendario))",
                "Sai do Início: \(quando) às \(Formatos.hora(fim, calendario: calendario))",
            ],
            botoes: botoes
        )
    }

    private func paraTiEvento(_ eventos: [EventoProximo], agora: Date) throws -> ParaTi? {
        let listas = try listas()
        for evento in eventos.sorted(by: { $0.inicio < $1.inicio }) {
            let falta = evento.inicio.timeIntervalSince(agora)
            guard falta > 0, falta <= 3 * 3600,
                  let lista = listas.first(where: { $0.id == evento.listaId })
            else { continue }
            let porFazer: (Item) -> Int = { $0.subtopicosOrdenados.count - $0.subtopicosFeitos }
            guard let item = lista.itensAtivos
                .filter({ porFazer($0) > 0 })
                .min(by: { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) })
            else { continue }
            let n = porFazer(item)
            let subtopicos = n == 1 ? "1 subtópico" : "\(n) subtópicos"
            let hora = Formatos.hora(evento.inicio, calendario: calendario)
            return ParaTi(
                motivo: .evento,
                fraseBase: "Às \(hora) tens «\(evento.titulo)». «\(item.titulo)» ainda tem \(subtopicos) por fazer.",
                factos: [
                    "Evento: \(evento.titulo), às \(hora) (daqui a \(Int(falta / 60)) minutos)",
                    "Ponto do mesmo espaço (\(lista.nome)): \(item.titulo), com \(subtopicos) por fazer",
                ],
                    botoes: [ParaTi.Botao(rotulo: "Ver subtópicos", acao: .abrirItem(item.id))]
            )
        }
        return nil
    }

    private func paraTiVistaPartilhada(_ agora: Date) throws -> ParaTi? {
        let desde = agora.addingTimeInterval(-2 * 86_400)
        for lista in try listas() where lista.ehCompras {
            let seccoes = lista.itensAtivos
            let artigos = seccoes.flatMap(\.subtopicosOrdenados)
            let feitos = artigos.filter { $0.estado == .concluido }.count
            let recente = artigos.contains { ($0.alteradoEm ?? .distantPast) >= desde }
            guard recente, feitos > 0, feitos < artigos.count else { continue }
            let porSeccao = seccoes.map { s in (s.titulo, s.subtopicosOrdenados.count - s.subtopicosFeitos) }
            let falta = porSeccao.filter { $0.1 > 0 }
            let feitas = porSeccao.filter { $0.1 == 0 }.map(\.0)
            guard let principal = falta.max(by: { $0.1 < $1.1 }) else { continue }
            var frase = "\(principal.1 == 1 ? "Falta 1 ponto" : "Faltam \(principal.1) pontos") em «\(principal.0)»"
            if let feita = feitas.first {
                frase += " e «\(feita)» já está feita"
            }
            return ParaTi(
                motivo: .vistaPartilhada,
                fraseBase: frase + ".",
                factos: ["Vista partilhada: \(lista.nome)"] + porSeccao.map { "Secção \($0.0): \($0.1) por fazer" },
                    botoes: [ParaTi.Botao(rotulo: "Abrir \(lista.nome)", acao: .abrirLista(lista.id))]
            )
        }
        return nil
    }
}
