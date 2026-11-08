import Foundation

/// O que o widget mostra (DESIGN.md 7.14): uma frase no topo e os pontos que importam agora,
/// cada um com a razão. A app escreve-o no App Group sempre que algo muda; o widget só o lê,
/// e calcula-o para a hora de cada entrada da timeline (`noMomento`), para continuar certo com a
/// app fechada dias a fio.
public struct ResumoWidget: Codable, Equatable, Sendable {
    public static let maxPontos = 3
    /// Pontos guardados de reserva, além dos que se mostram.
    public static let maxReserva = 5
    public static let nomeFicheiro = "resumo-widget.json"
    /// Dias no widget "O teu ritmo" (o médio); o pequeno mostra os últimos 7.
    public static let diasRitmo = 15

    public var frase: String
    public var pontos: [Ponto]
    public var totalAtivos: Int
    public var expiramHoje: Int
    public var geradoEm: Date
    /// O tema da Ampulheta; nil em resumos gravados antes de haver temas.
    public var tema: TemaMascote?
    /// O humor e a areia do Glassy; nil em resumos gravados antes de os haver.
    public var glassy: EstadoGlassy?
    /// Para recalcular os números e o Glassy sem a app; nil em resumos antigos.
    public var datas: DatasGlassy?
    /// Os pontos que entram quando os de `pontos` expirarem.
    public var seguintes: [Ponto]?
    /// Os últimos `diasRitmo` dias, até ao do resumo; nil em resumos antigos.
    public var dias: [DiaHistorico]?
    /// A hora do Fecho do dia, em minutos desde a meia-noite; nil com o fecho desligado ou em
    /// resumos antigos.
    public var minutosFecho: Int?
    /// Quando fechaste o dia pela última vez: depois da hora do fecho, tira o convite até ao dia seguinte.
    public var fechoFeitoEm: Date?

    public struct Ponto: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var titulo: String
        public var lista: String
        /// Chave de `CorLista`.
        public var cor: String
        public var razao: String
        public var expiraEm: Date?
        public var ultimaAcaoEm: Date
        /// Para reescrever a razão noutra hora; nil em resumos antigos.
        public var subtopicos: Int?
        public var subtopicosPorFazer: Int?

        /// Parte do anel ainda cheia numa dada hora, como `Prazo.fracao`.
        public func fracao(em data: Date) -> Double {
            guard let expiraEm else { return 1 }
            let duracao = max(1, expiraEm.timeIntervalSince(ultimaAcaoEm))
            return min(1, max(0, expiraEm.timeIntervalSince(data) / duracao))
        }

        /// Menos de 24 horas para expirar: o anel fica laranja.
        public func ultimoDia(em data: Date) -> Bool {
            guard let expiraEm else { return false }
            return expiraEm.timeIntervalSince(data) < 24 * 60 * 60
        }
    }

    public init(frase: String, pontos: [Ponto], totalAtivos: Int, expiramHoje: Int, geradoEm: Date, tema: TemaMascote? = nil, glassy: EstadoGlassy? = nil, datas: DatasGlassy? = nil, seguintes: [Ponto]? = nil, dias: [DiaHistorico]? = nil, minutosFecho: Int? = nil, fechoFeitoEm: Date? = nil) {
        self.frase = frase
        self.pontos = pontos
        self.totalAtivos = totalAtivos
        self.expiramHoje = expiramHoje
        self.geradoEm = geradoEm
        self.tema = tema
        self.glassy = glassy
        self.datas = datas
        self.seguintes = seguintes
        self.dias = dias
        self.minutosFecho = minutosFecho
        self.fechoFeitoEm = fechoFeitoEm
    }

    /// Quantos pontos o widget pede para fechar a uma dada hora: os do último dia, só depois da
    /// hora do fecho. Usa os números de `noMomento` dessa hora.
    public func fechoPendente(em data: Date, calendario: Calendar = .current) -> Int {
        guard let minutosFecho,
              let hora = calendario.date(bySettingHour: minutosFecho / 60, minute: minutosFecho % 60, second: 0, of: data),
              data >= hora, (fechoFeitoEm ?? .distantPast) < hora
        else { return 0 }
        return expiramHoje
    }

    /// O resumo tal como deve ser visto a uma dada hora: sem os pontos cujo prazo já passou, com
    /// as razões, os números e o Glassy dessa hora. A frase do modelo só fica se os números não
    /// mudaram. shortcut: com mais de `maxReserva` pontos todos vencidos o widget fica sem linhas
    /// até a app abrir; chega para quem abandona a app, senão guardar todos os pontos.
    public func noMomento(_ data: Date, calendario: Calendar = .current) -> ResumoWidget {
        guard let datas else { return self }
        var novo = self
        novo.pontos = (pontos + (seguintes ?? []))
            .filter { ($0.expiraEm ?? .distantFuture) > data }
            .prefix(Self.maxPontos)
            .map { ponto in
                var ponto = ponto
                if let limite = ponto.expiraEm, let total = ponto.subtopicos, let falta = ponto.subtopicosPorFazer {
                    ponto.razao = Self.razao(limite: limite, ultimaAcao: ponto.ultimaAcaoEm, total: total, falta: falta, agora: data, calendario: calendario)
                }
                return ponto
            }
        novo.totalAtivos = datas.totalAtivos(em: data)
        novo.expiramHoje = datas.ultimoDia(em: data)
        if novo.totalAtivos != totalAtivos || novo.expiramHoje != expiramHoje {
            novo.frase = Self.fraseBase(totalAtivos: novo.totalAtivos, expiramHoje: novo.expiramHoje)
        }
        novo.glassy = datas.estado(em: data)
        // Depois da meia-noite a janela anda: o dia novo começa neutro até a app o registar.
        novo.dias = dias.map { HistoricoDias(dias: $0).ultimos(Self.diasRitmo, ate: data, calendario: calendario) }
        return novo
    }

    static func diasSemMexer(desde ultimaAcao: Date, agora: Date, calendario: Calendar) -> Int {
        calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: ultimaAcao),
            to: calendario.startOfDay(for: agora)
        ).day ?? 0
    }

    /// Uma linha curta: o que torna o ponto importante agora.
    static func razao(limite: Date, ultimaAcao: Date, total: Int, falta: Int, agora: Date, calendario: Calendar) -> String {
        let prazo = Prazo(limite: limite, ultimaAcao: ultimaAcao, agora: agora)
        if prazo.ultimoDia {
            let dia = calendario.isDate(limite, inSameDayAs: agora) ? "hoje" : "amanhã"
            return "Expira \(dia) às \(Formatos.hora(limite, calendario: calendario))"
        }
        if total > 0 && falta == 1 { return "Falta 1 subtópico" }
        let parado = diasSemMexer(desde: ultimaAcao, agora: agora, calendario: calendario)
        if parado >= 2 { return "Sem mexer há \(parado) dias" }
        if total > 0 { return "Faltam \(falta) de \(total) subtópicos" }
        return prazo.rotuloLongo
    }

    /// Sem modelo do iPhone: "2 pontos expiram hoje", "Nada urgente hoje" ou "Tudo em dia".
    public static func fraseBase(totalAtivos: Int, expiramHoje: Int) -> String {
        switch (totalAtivos, expiramHoje) {
        case (0, _): return "Tudo em dia"
        case (_, 0): return "Nada urgente hoje"
        case (_, 1): return "1 ponto expira hoje"
        case (_, let n): return "\(n) pontos expiram hoje"
        }
    }

    // MARK: - Ficheiro no App Group

    public func gravar(em pasta: URL) throws {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        try codificador.encode(self).write(to: pasta.appendingPathComponent(Self.nomeFicheiro), options: .atomic)
    }

    public static func ler(de pasta: URL) -> ResumoWidget? {
        guard let dados = try? Data(contentsOf: pasta.appendingPathComponent(nomeFicheiro)) else { return nil }
        let descodificador = JSONDecoder()
        descodificador.dateDecodingStrategy = .iso8601
        return try? descodificador.decode(ResumoWidget.self, from: dados)
    }

    /// Para o modo de demonstração e as pré-visualizações do widget.
    public static func exemplo(agora: Date = .now) -> ResumoWidget {
        func ponto(_ titulo: String, _ lista: String, _ cor: CorLista, _ razao: String, horas: Double, desde: Double) -> Ponto {
            Ponto(
                id: UUID(),
                titulo: titulo,
                lista: lista,
                cor: cor.rawValue,
                razao: razao,
                expiraEm: agora.addingTimeInterval(horas * 3600),
                ultimaAcaoEm: agora.addingTimeInterval(-desde * 3600)
            )
        }
        return ResumoWidget(
            frase: "Dia calmo: só a demo de sexta precisa de ti hoje.",
            pontos: [
                ponto("Preparar demo de sexta", "Trabalho", .azul, "Expira hoje às 18:30", horas: 6, desde: 66),
                ponto("Rever proposta do roadmap", "Trabalho", .azul, "Faltam 2 de 4 subtópicos", horas: 30, desde: 42),
                ponto("Ideia: métrica de abandono", "Ideias", .amarelo, "Sem mexer há 2 dias", horas: 40, desde: 32),
            ],
            totalAtivos: 12,
            expiramHoje: 1,
            geradoEm: agora,
            dias: zip(HistoricoDias().ultimos(diasRitmo, ate: agora, calendario: .current), Array("vvnvrvvnvvrvvnv")).map { dia, letra in
                DiaHistorico(dia: dia.dia, concluiu: letra == Character("v"), expirou: letra == Character("r"))
            }
        )
    }
}

extension Tarefas {
    /// Os pontos que importam agora, por ordem, com a razão de cada um (DESIGN.md 7.14). Entram
    /// só itens principais ativos com prazo, fora das listas de compras. Pesa:
    /// - o prazo a acabar (o último dia vale muito mais);
    /// - um item quase feito (falta 1 subtópico);
    /// - os dias sem mexer.
    public func prioridades(limite: Int = ResumoWidget.maxPontos) throws -> [(item: Item, razao: String)] {
        let agora = relogio.agora
        let candidatos: [(item: Item, peso: Double)] = try itens(.ativo).compactMap { item in
            guard !item.ehSubtopico, item.apagadoEm == nil, item.lista?.ehCompras != true,
                  let prazo = Prazo(item: item, agora: agora)
            else { return nil }
            var peso = 1 - prazo.fracao
            if prazo.ultimoDia { peso += 2 }
            let total = item.subtopicosOrdenados.count
            if total > 0 && total - item.subtopicosFeitos == 1 { peso += 0.8 }
            peso += min(1, Double(ResumoWidget.diasSemMexer(desde: item.ultimaAcaoEm, agora: agora, calendario: calendario)) * 0.15)
            return (item, peso)
        }
        return candidatos
            .sorted { $0.peso != $1.peso ? $0.peso > $1.peso : ($0.item.expiraEm ?? .distantFuture) < ($1.item.expiraEm ?? .distantFuture) }
            .prefix(limite)
            .map { ($0.item, razao($0.item, agora: agora)) }
    }

    /// O resumo para o widget, com a frase de base (a app pode trocá-la pela do modelo). Com o
    /// histórico gravado, leva também os dias de "O teu ritmo", com o de hoje tirado dos pontos.
    public func resumoWidget(historicoGuardado: HistoricoDias? = nil, fechoFeitoEm: Date? = nil) throws -> ResumoWidget {
        let agora = relogio.agora
        let ativos = try itens(.ativo).filter { !$0.ehSubtopico && $0.apagadoEm == nil && $0.lista?.ehCompras != true }
        let hoje = ativos.filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }.count
        let pontos = try prioridades(limite: ResumoWidget.maxPontos + ResumoWidget.maxReserva).map { item, razao in
            ResumoWidget.Ponto(
                id: item.id,
                titulo: item.titulo,
                lista: item.lista?.nome ?? "",
                cor: item.lista?.corRaw ?? CorLista.azul.rawValue,
                razao: razao,
                expiraEm: item.expiraEm,
                ultimaAcaoEm: item.ultimaAcaoEm,
                subtopicos: item.subtopicosOrdenados.count,
                subtopicosPorFazer: item.subtopicosOrdenados.count - item.subtopicosFeitos
            )
        }
        let datas = try datasGlassy()
        return ResumoWidget(
            frase: ResumoWidget.fraseBase(totalAtivos: ativos.count, expiramHoje: hoje),
            pontos: Array(pontos.prefix(ResumoWidget.maxPontos)),
            totalAtivos: ativos.count,
            expiramHoje: hoje,
            geradoEm: agora,
            tema: try temaMascote(),
            glassy: datas.estado(em: agora),
            datas: datas,
            seguintes: Array(pontos.dropFirst(ResumoWidget.maxPontos)),
            dias: try historicoGuardado.map {
                try historico(juntandoA: $0).ultimos(ResumoWidget.diasRitmo, ate: agora, calendario: calendario)
            },
            minutosFecho: definicoes.avisosAtivos && definicoes.fechoDiaAtivo
                ? min(21, max(8, definicoes.horaFechoDia)) * 60 + definicoes.minutoFechoDia
                : nil,
            fechoFeitoEm: fechoFeitoEm
        )
    }

    private func razao(_ item: Item, agora: Date) -> String {
        guard let limite = item.expiraEm else { return "" }
        let total = item.subtopicosOrdenados.count
        return ResumoWidget.razao(
            limite: limite,
            ultimaAcao: item.ultimaAcaoEm,
            total: total,
            falta: total - item.subtopicosFeitos,
            agora: agora,
            calendario: calendario
        )
    }
}
