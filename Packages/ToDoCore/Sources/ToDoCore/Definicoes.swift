import Foundation

/// Quando chega o aviso antes de um ponto expirar (questionário e Definições › Notificações).
public enum ModoAviso: String, Codable, CaseIterable, Sendable {
    /// 24 horas antes, à hora exata; de madrugada passa para a hora das notificações.
    case vinteQuatroHoras
    /// Na véspera do dia em que expira, à hora escolhida.
    case manha, noite

    public var nome: String {
        switch self {
        case .vinteQuatroHoras: "24 horas antes"
        case .manha: "De manhã"
        case .noite: "À noite"
        }
    }

    /// A hora que o modo põe ao ser escolhido: "À noite, às 09:00" não faria sentido.
    public var horaPredefinida: Int { self == .noite ? 21 : 9 }
}

/// Valores editáveis nas Definições (especificação 9), guardados em UserDefaults.
public struct Definicoes: Codable, Equatable, Sendable {
    /// Os limites dos ecrãs de Avançado. Valem também ao ler: um backup pode vir de qualquer lado.
    public static let intervaloExpiracao = 1...30
    public static let intervaloManterCurto = 1...30
    public static let intervaloManterLongo = 1...90
    public static let intervaloRetencao = 1...60
    /// O slider do questionário; em Avançado continua até 30.
    public static let intervaloQuestionario = 2...15

    public var diasExpiracao = 3
    public var diasManterCurto = 5
    public var diasManterLongo = 15
    public var diasRetencaoExpirados = 14
    public var diasRetencaoConcluidos = 7
    public var horaNotificacao = 9
    public var minutoNotificacao = 0
    public var avisosAtivos = true
    public var modoAviso = ModoAviso.vinteQuatroHoras
    /// Dias sem pontos abertos até uma lista não permanente desaparecer (DESIGN.md 7.17).
    public var diasListaVazia = 5
    /// Textos e sugestões escritos pelo modelo da Apple no iPhone (DESIGN.md 7.16).
    public var inteligenciaAtiva = true
    /// Fecho do dia (Melhoria 33): à hora escolhida, notificação, frase do Glassy e widget.
    public var fechoDiaAtivo = true
    /// Sempre entre as 08:00 e as 21:59, como os outros avisos (regra da noite).
    public var horaFechoDia = 21
    public var minutoFechoDia = 0

    public init() {}

    /// Campos em falta (gravados por uma versão anterior) ficam com a predefinição e valores fora
    /// dos limites ficam no limite: 0 dias de retenção apagaria os Expirados na abertura seguinte.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Definicoes()
        func dias(_ chave: CodingKeys, _ predefinicao: Int, _ intervalo: ClosedRange<Int>) throws -> Int {
            let valor = try c.decodeIfPresent(Int.self, forKey: chave) ?? predefinicao
            return min(intervalo.upperBound, max(intervalo.lowerBound, valor))
        }
        diasExpiracao = try dias(.diasExpiracao, base.diasExpiracao, Self.intervaloExpiracao)
        diasManterCurto = try dias(.diasManterCurto, base.diasManterCurto, Self.intervaloManterCurto)
        diasManterLongo = try dias(.diasManterLongo, base.diasManterLongo, Self.intervaloManterLongo)
        diasRetencaoExpirados = try dias(.diasRetencaoExpirados, base.diasRetencaoExpirados, Self.intervaloRetencao)
        diasRetencaoConcluidos = try dias(.diasRetencaoConcluidos, base.diasRetencaoConcluidos, Self.intervaloRetencao)
        horaNotificacao = try dias(.horaNotificacao, base.horaNotificacao, 0...23)
        minutoNotificacao = try dias(.minutoNotificacao, base.minutoNotificacao, 0...59)
        avisosAtivos = try c.decodeIfPresent(Bool.self, forKey: .avisosAtivos) ?? base.avisosAtivos
        // Um modo desconhecido (backup de uma versão futura) fica no de sempre, sem estragar o resto.
        modoAviso = (try? c.decodeIfPresent(ModoAviso.self, forKey: .modoAviso)) ?? base.modoAviso
        diasListaVazia = try dias(.diasListaVazia, base.diasListaVazia, Self.intervaloRetencao)
        inteligenciaAtiva = try c.decodeIfPresent(Bool.self, forKey: .inteligenciaAtiva) ?? base.inteligenciaAtiva
        fechoDiaAtivo = try c.decodeIfPresent(Bool.self, forKey: .fechoDiaAtivo) ?? base.fechoDiaAtivo
        horaFechoDia = try dias(.horaFechoDia, base.horaFechoDia, 8...21)
        minutoFechoDia = try dias(.minutoFechoDia, base.minutoFechoDia, 0...59)
    }

    /// Escolhe o modo dos avisos com a hora dele.
    public mutating func escolher(_ modo: ModoAviso) {
        modoAviso = modo
        horaNotificacao = modo.horaPredefinida
        minutoNotificacao = 0
    }

    /// A hora escolhida no seletor. De manhã e à noite fica entre as 08:00 e as 21:59, como o
    /// aviso (regra da noite): o resumo nunca promete uma hora em que o aviso não chega.
    public mutating func definirHora(_ hora: Int, _ minuto: Int) {
        horaNotificacao = modoAviso == .vinteQuatroHoras ? hora : min(21, max(8, hora))
        minutoNotificacao = minuto
    }

    /// A hora do Fecho do dia, sempre entre as 08:00 e as 21:59 (regra da noite).
    public mutating func definirHoraFecho(_ hora: Int, _ minuto: Int) {
        horaFechoDia = min(21, max(8, hora))
        minutoFechoDia = minuto
    }

    /// "De manhã, às 09:00", para o questionário e as Definições.
    public var resumoAvisos: String {
        guard avisosAtivos else { return "Desligados" }
        guard modoAviso != .vinteQuatroHoras else { return modoAviso.nome }
        return "\(modoAviso.nome), às " + String(format: "%02d:%02d", horaNotificacao, minutoNotificacao)
    }

    /// As definições depois de restaurar um backup: as dele, mas sem encurtar o que protege os
    /// dados. Um backup com 14 dias de retenção apagaria hoje os Expirados que os teus 30 guardam.
    public func aoRestaurar(_ doBackup: Definicoes) -> Definicoes {
        var novas = doBackup
        novas.diasRetencaoExpirados = max(diasRetencaoExpirados, doBackup.diasRetencaoExpirados)
        novas.diasRetencaoConcluidos = max(diasRetencaoConcluidos, doBackup.diasRetencaoConcluidos)
        novas.diasListaVazia = max(diasListaVazia, doBackup.diasListaVazia)
        return novas
    }

    private static let chave = "definicoes"

    public static func carregar(de defaults: UserDefaults = .standard) -> Definicoes {
        guard let dados = defaults.data(forKey: chave),
              let definicoes = try? JSONDecoder().decode(Definicoes.self, from: dados)
        else { return Definicoes() }
        return definicoes
    }

    public func guardar(em defaults: UserDefaults = .standard) {
        if let dados = try? JSONEncoder().encode(self) {
            defaults.set(dados, forKey: Self.chave)
        }
    }
}
