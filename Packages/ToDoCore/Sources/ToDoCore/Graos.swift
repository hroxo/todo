import Foundation
import SwiftData

/// Um dia verde que já deu o seu grão (Melhoria 35). Fica no SwiftData, e não no
/// `historico-dias.json`, para ir no iCloud: o saldo não se pode perder ao mudar de aparelho.
/// Compatível com o CloudKit: sem `.unique` (as cópias de dois aparelhos juntam-se ao ler).
@Model
public final class DiaGanho {
    /// O dia, "2026-11-08" (`HistoricoDias.chave`): o mesmo em todos os aparelhos.
    public var id = ""
    public var ganhoEm = Date.distantPast

    public init(id: String, ganhoEm: Date) {
        self.id = id
        self.ganhoEm = ganhoEm
    }
}

/// Um cenário comprado com grãos. Guarda o custo pago: mudar os preços do catálogo nunca muda
/// o saldo de quem já comprou.
@Model
public final class CenarioDesbloqueado {
    /// `CenarioId.rawValue`; um id que esta versão não conhece (de uma versão futura) conta no
    /// saldo, mas não aparece.
    public var id = ""
    public var custo = 0
    public var desbloqueadoEm = Date.distantPast

    public init(id: String, custo: Int, desbloqueadoEm: Date) {
        self.id = id
        self.custo = custo
        self.desbloqueadoEm = desbloqueadoEm
    }
}

/// Os grãos: 1 por dia verde, gastos a desbloquear cenários. Só se ganham, nunca se tiram: um
/// dia que deixa de ser verde (Anular, Reabrir) fica com o grão, e o saldo nunca fica negativo.
/// Como o dia é binário, despejar pontos não compra nada.
extension Tarefas {
    /// Dá o grão aos dias verdes do histórico que ainda não o tinham. Pode correr sempre: o que
    /// já existe (também o que veio de outro aparelho) não se repete, e nada se apaga.
    public func registarGraos(de historico: HistoricoDias) throws {
        let ganhos = Set(try contexto.fetch(FetchDescriptor<DiaGanho>()).map(\.id))
        for dia in historico.dias where dia.estado == .verde && !ganhos.contains(dia.dia) {
            contexto.insert(DiaGanho(id: dia.dia, ganhoEm: relogio.agora))
        }
    }

    /// Os grãos disponíveis: dias ganhos menos o que custaram os cenários. As cópias de dois
    /// aparelhos contam uma vez (o mesmo dia, o mesmo cenário).
    public func saldoGraos() throws -> Int {
        Cenario.saldo(dias: try contexto.fetch(FetchDescriptor<DiaGanho>()), compras: try contexto.fetch(FetchDescriptor<CenarioDesbloqueado>()))
    }

    /// Os cenários que se podem escolher, pela ordem do catálogo. O Céu está sempre.
    public func cenariosDesbloqueados() throws -> [CenarioId] {
        Cenario.desbloqueados(try contexto.fetch(FetchDescriptor<CenarioDesbloqueado>()))
    }

    /// Compra um cenário. Já comprado não gasta outra vez; sem grãos que cheguem, recusa sem
    /// mudar nada.
    public func desbloquear(_ id: CenarioId) throws {
        guard try !cenariosDesbloqueados().contains(id) else { return }
        let cenario = Cenario.de(id)
        guard try saldoGraos() >= cenario.custo else { throw ErroTarefas.graosInsuficientes }
        contexto.insert(CenarioDesbloqueado(id: id.rawValue, custo: cenario.custo, desbloqueadoEm: relogio.agora))
    }

    /// O cenário a desenhar: o escolhido neste aparelho, se estiver desbloqueado; senão o Céu
    /// (num aparelho novo, a compra pode ainda não ter chegado pelo iCloud).
    public func cenarioAtivo(escolhido: String?) throws -> CenarioId {
        Cenario.ativo(escolhido: escolhido, compras: try contexto.fetch(FetchDescriptor<CenarioDesbloqueado>()))
    }
}

/// As mesmas contas sobre o que os ecrãs já leram com `@Query`, para se atualizarem sozinhos.
extension Cenario {
    public static func saldo(dias: [DiaGanho], compras: [CenarioDesbloqueado]) -> Int {
        let gasto = custos(compras).values.reduce(0, +)
        return max(0, Set(dias.map(\.id)).count - gasto)
    }

    public static func desbloqueados(_ compras: [CenarioDesbloqueado]) -> [CenarioId] {
        let comprados = custos(compras)
        return catalogo.map(\.id).filter { $0 == .ceu || comprados[$0.rawValue] != nil }
    }

    public static func ativo(escolhido: String?, compras: [CenarioDesbloqueado]) -> CenarioId {
        guard let id = escolhido.flatMap(CenarioId.init(rawValue:)), desbloqueados(compras).contains(id) else {
            return .ceu
        }
        return id
    }

    /// O custo de cada cenário comprado; com cópias repetidas, conta a mais barata.
    private static func custos(_ compras: [CenarioDesbloqueado]) -> [String: Int] {
        Dictionary(compras.map { ($0.id, $0.custo) }, uniquingKeysWith: min)
    }
}
