import XCTest
@testable import ToDoCore

/// O céu que segue o modo do iPhone, e a saudação que segue o relógio.
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
}
