import XCTest
@testable import ToDoCore

/// O céu que segue o modo do iPhone, a saudação que segue o relógio e o sol de Lisboa da
/// Aparência "Reativo".
final class CeuDoDiaTests: XCTestCase {
    private var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendario
    }

    private func data(_ hora: Int) -> Date {
        calendario.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: hora))!
    }

    func testOCeuSoDependeDoModoENaoDaHora() {
        for hora in [3, 13, 22] {
            XCTAssertEqual(CeuDoDia(agora: data(hora), escuro: false, calendario: calendario).fase, .dia)
            XCTAssertEqual(CeuDoDia(agora: data(hora), escuro: true, calendario: calendario).fase, .noite)
        }
    }

    func testSaudacoes() {
        let esperadas = [5: "Boa noite!", 6: "Bom dia!", 11: "Bom dia!", 12: "Boa tarde!", 19: "Boa tarde!", 20: "Boa noite!"]
        for (hora, saudacao) in esperadas {
            XCTAssertEqual(CeuDoDia(agora: data(hora), calendario: calendario).saudacao, saudacao)
        }
    }

    func testASaudacaoNaoMudaComOModo() {
        XCTAssertEqual(CeuDoDia(agora: data(9), escuro: true, calendario: calendario).saudacao, "Bom dia!")
    }

    private func data(_ ano: Int, _ mes: Int, _ dia: Int, _ hora: Int, _ minuto: Int = 0) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    private func noite(_ data: Date) -> Bool {
        CeuDoDia.ehNoite(agora: data, calendario: calendario)
    }

    func testReativoNoInverno() {
        // Em Lisboa, a 2 de novembro, o sol nasce por volta das 7:05 e põe-se às 17:37.
        XCTAssertTrue(noite(data(2026, 11, 2, 6, 50)))
        XCTAssertFalse(noite(data(2026, 11, 2, 7, 20)))
        XCTAssertFalse(noite(data(2026, 11, 2, 17, 20)))
        XCTAssertTrue(noite(data(2026, 11, 2, 17, 55)))
        XCTAssertTrue(noite(data(2026, 12, 21, 21)))
    }

    func testReativoNoVerao() {
        // A 21 de junho o sol só se põe por volta das 21:05.
        XCTAssertFalse(noite(data(2026, 6, 21, 20, 45)))
        XCTAssertTrue(noite(data(2026, 6, 21, 21, 25)))
        XCTAssertTrue(noite(data(2026, 6, 21, 5, 50)))
        XCTAssertFalse(noite(data(2026, 6, 21, 6, 30)))
    }

    func testReativoNaViradaDoDia() {
        XCTAssertTrue(noite(data(2026, 11, 2, 23, 59)))
        XCTAssertTrue(noite(data(2026, 11, 3, 0, 0)))
    }
}
