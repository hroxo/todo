import Foundation

/// O que o widget mostra (DESIGN.md 7.14): uma frase no topo e os pontos que importam agora,
/// cada um com a razão. A app escreve-o no App Group sempre que algo muda; o widget só o lê,
/// e calcula o anel de cada ponto na hora de cada entrada da timeline.
public struct ResumoWidget: Codable, Equatable, Sendable {
    public static let maxPontos = 3
    public static let nomeFicheiro = "resumo-widget.json"

    public var frase: String
    public var pontos: [Ponto]
    public var totalAtivos: Int
    public var expiramHoje: Int
    public var geradoEm: Date

    public struct Ponto: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var titulo: String
        public var lista: String
        /// Chave de `CorLista`.
        public var cor: String
        public var razao: String
        public var expiraEm: Date?
        public var ultimaAcaoEm: Date

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

    public init(frase: String, pontos: [Ponto], totalAtivos: Int, expiramHoje: Int, geradoEm: Date) {
        self.frase = frase
        self.pontos = pontos
        self.totalAtivos = totalAtivos
        self.expiramHoje = expiramHoje
        self.geradoEm = geradoEm
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
            geradoEm: agora
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
        let candidatos: [(item: Item, prazo: Prazo, peso: Double)] = try itens(.ativo).compactMap { item in
            guard !item.ehSubtopico, item.apagadoEm == nil, item.lista?.ehCompras != true,
                  let prazo = Prazo(item: item, agora: agora)
            else { return nil }
            var peso = 1 - prazo.fracao
            if prazo.ultimoDia { peso += 2 }
            let total = item.subtopicosOrdenados.count
            if total > 0 && total - item.subtopicosFeitos == 1 { peso += 0.8 }
            peso += min(1, Double(diasSemMexer(item, agora: agora)) * 0.15)
            return (item, prazo, peso)
        }
        return candidatos
            .sorted { $0.peso != $1.peso ? $0.peso > $1.peso : ($0.item.expiraEm ?? .distantFuture) < ($1.item.expiraEm ?? .distantFuture) }
            .prefix(limite)
            .map { ($0.item, razao($0.item, prazo: $0.prazo, agora: agora)) }
    }

    /// O resumo para o widget, com a frase de base (a app pode trocá-la pela do modelo).
    public func resumoWidget() throws -> ResumoWidget {
        let agora = relogio.agora
        let ativos = try itens(.ativo).filter { !$0.ehSubtopico && $0.apagadoEm == nil && $0.lista?.ehCompras != true }
        let hoje = ativos.filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }.count
        let pontos = try prioridades().map { item, razao in
            ResumoWidget.Ponto(
                id: item.id,
                titulo: item.titulo,
                lista: item.lista?.nome ?? "",
                cor: item.lista?.corRaw ?? CorLista.azul.rawValue,
                razao: razao,
                expiraEm: item.expiraEm,
                ultimaAcaoEm: item.ultimaAcaoEm
            )
        }
        return ResumoWidget(
            frase: ResumoWidget.fraseBase(totalAtivos: ativos.count, expiramHoje: hoje),
            pontos: pontos,
            totalAtivos: ativos.count,
            expiramHoje: hoje,
            geradoEm: agora
        )
    }

    private func diasSemMexer(_ item: Item, agora: Date) -> Int {
        calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: item.ultimaAcaoEm),
            to: calendario.startOfDay(for: agora)
        ).day ?? 0
    }

    /// Uma linha curta: o que torna o ponto importante agora.
    private func razao(_ item: Item, prazo: Prazo, agora: Date) -> String {
        if prazo.ultimoDia, let limite = item.expiraEm {
            let dia = calendario.isDate(limite, inSameDayAs: agora) ? "hoje" : "amanhã"
            return "Expira \(dia) às \(Formatos.hora(limite, calendario: calendario))"
        }
        let total = item.subtopicosOrdenados.count
        let falta = total - item.subtopicosFeitos
        if total > 0 && falta == 1 { return "Falta 1 subtópico" }
        let parado = diasSemMexer(item, agora: agora)
        if parado >= 2 { return "Sem mexer há \(parado) dias" }
        if total > 0 { return "Faltam \(falta) de \(total) subtópicos" }
        return prazo.rotuloLongo
    }
}
