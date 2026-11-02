import XCTest
@testable import ToDoCore

/// O céu que segue o sol de cada dia, em Lisboa.
final class CeuDoDiaTests: XCTestCase {
    private var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }

    private func data(_ ano: Int, _ mes: Int, _ dia: Int, _ hora: Int, _ minuto: Int = 0) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    private func ceu(_ data: Date) -> CeuDoDia {
        CeuDoDia(agora: data, calendario: calendario)
    }

    func testHorasDoSolNoInverno() {
        let c = ceu(data(2026, 11, 2, 12))
        XCTAssertEqual(c.nascer.timeIntervalSince(data(2026, 11, 2, 7, 5)), 0, accuracy: 300)
        XCTAssertEqual(c.por.timeIntervalSince(data(2026, 11, 2, 17, 37)), 0, accuracy: 300)
    }

    func testHorasDoSolNoVerao() {
        let c = ceu(data(2026, 6, 21, 12))
        XCTAssertEqual(c.nascer.timeIntervalSince(data(2026, 6, 21, 6, 12)), 0, accuracy: 300)
        XCTAssertEqual(c.por.timeIntervalSince(data(2026, 6, 21, 21, 5)), 0, accuracy: 300)
    }

    func testFasesAoLongoDoDia() {
        XCTAssertEqual(ceu(data(2026, 11, 2, 5)).fase, .noite)
        XCTAssertEqual(ceu(data(2026, 11, 2, 7, 15)).fase, .amanhecer)
        XCTAssertEqual(ceu(data(2026, 11, 2, 13)).fase, .dia)
        XCTAssertEqual(ceu(data(2026, 11, 2, 17, 30)).fase, .porDoSol)
        XCTAssertEqual(ceu(data(2026, 11, 2, 20)).fase, .noite)
    }

    func testNoVeraoAindaEDiaAsSeteDaTarde() {
        XCTAssertEqual(ceu(data(2026, 6, 21, 19)).fase, .dia)
        XCTAssertEqual(ceu(data(2026, 6, 21, 21)).fase, .porDoSol)
    }

    func testSaudacoes() {
        XCTAssertEqual(ceu(data(2026, 11, 2, 5)).saudacao, "Boa noite!")
        XCTAssertEqual(ceu(data(2026, 11, 2, 9)).saudacao, "Bom dia!")
        XCTAssertEqual(ceu(data(2026, 11, 2, 15)).saudacao, "Boa tarde!")
        XCTAssertEqual(ceu(data(2026, 11, 2, 20)).saudacao, "Boa noite!")
    }

    func testSaudacaoComOCeu() {
        XCTAssertEqual(ceu(data(2026, 11, 2, 7, 15)).saudacaoDoMomento, "Bom dia! O sol está a nascer.")
        XCTAssertEqual(ceu(data(2026, 11, 2, 17, 30)).saudacaoDoMomento, "Boa tarde! Olha o pôr do sol.")
        XCTAssertEqual(ceu(data(2026, 11, 2, 20)).saudacaoDoMomento, "Boa noite!")
    }

    func testPercursoDoSol() {
        XCTAssertEqual(ceu(data(2026, 11, 2, 5)).percurso, 0)
        XCTAssertEqual(ceu(data(2026, 11, 2, 12, 21)).percurso, 0.5, accuracy: 0.05)
        XCTAssertEqual(ceu(data(2026, 11, 2, 20)).percurso, 1)
    }
}
