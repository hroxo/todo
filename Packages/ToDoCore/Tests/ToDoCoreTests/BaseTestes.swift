import XCTest
import SwiftData
@testable import ToDoCore

final class RelogioFixo: Relogio {
    var agora: Date
    init(_ agora: Date) { self.agora = agora }
}

/// Base de dados em memória, relógio fixo e calendário de Lisboa para cada teste.
class BaseTestes: XCTestCase {
    var contentor: ModelContainer!
    var contexto: ModelContext!
    var relogio: RelogioFixo!
    var calendario: Calendar!
    var tarefas: Tarefas!

    // 21/10/2026 10:00 em Lisboa.
    let inicio = Date(timeIntervalSince1970: 1_792_573_200)

    override func setUpWithError() throws {
        contentor = try BaseDados.contentor(emMemoria: true)
        contexto = ModelContext(contentor)
        relogio = RelogioFixo(inicio)
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        self.calendario = calendario
        tarefas = Tarefas(contexto: contexto, relogio: relogio, calendario: calendario, definicoes: Definicoes())
    }

    func dias(_ n: Int, desde data: Date) -> Date {
        calendario.date(byAdding: .day, value: n, to: data)!
    }

    func avancar(dias n: Int) {
        relogio.agora = dias(n, desde: relogio.agora)
    }

    func avancar(horas n: Int) {
        relogio.agora = calendario.date(byAdding: .hour, value: n, to: relogio.agora)!
    }

    func contarItens() throws -> Int {
        try contexto.fetchCount(FetchDescriptor<Item>())
    }

    /// Data em Lisboa.
    func data(_ ano: Int, _ mes: Int, _ dia: Int, _ hora: Int, _ minuto: Int = 0) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: hora, minute: minuto))!
    }
}
