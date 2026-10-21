import XCTest
@testable import ToDoCore

final class SaudacaoTests: XCTestCase {
    func testTexto() {
        XCTAssertEqual(Saudacao.texto, "Olá")
    }
}
