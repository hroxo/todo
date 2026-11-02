import XCTest
@testable import ToDoCore

/// Iniciar sessão com a Apple (DESIGN.md 7.20): o nome e o email só vêm na primeira vez.
final class PerfilAppleTests: XCTestCase {
    private let hugo = PerfilApple(utilizador: "001", nome: "Hugo", email: "hugo@privaterelay.appleid.com")

    func testPrimeiraAutorizacaoGuardaOQueAAppleDeu() {
        let perfil = PerfilApple.depoisDeAutorizar(anterior: nil, utilizador: "001", nome: "Hugo", email: "hugo@privaterelay.appleid.com")
        XCTAssertEqual(perfil, hugo)
    }

    func testVoltarAEntrarNaMesmaContaMantemONomeEOEmail() {
        let perfil = PerfilApple.depoisDeAutorizar(anterior: hugo, utilizador: "001", nome: nil, email: nil)
        XCTAssertEqual(perfil, hugo)
    }

    func testOutraContaNaoHerdaOPerfilAnterior() {
        let perfil = PerfilApple.depoisDeAutorizar(anterior: hugo, utilizador: "002", nome: nil, email: nil)
        XCTAssertEqual(perfil, PerfilApple(utilizador: "002"))
    }

    func testDadosNovosSubstituemOsAntigos() {
        let perfil = PerfilApple.depoisDeAutorizar(anterior: hugo, utilizador: "001", nome: "Maria", email: nil)
        XCTAssertEqual(perfil.nome, "Maria")
        XCTAssertEqual(perfil.email, hugo.email)
    }

    func testTextoVazioContaComoNaoDado() {
        let perfil = PerfilApple.depoisDeAutorizar(anterior: hugo, utilizador: "001", nome: "  ", email: "")
        XCTAssertEqual(perfil, hugo)
    }

    func testSobreviveAGuardarELer() throws {
        let dados = try JSONEncoder().encode(hugo)
        XCTAssertEqual(try JSONDecoder().decode(PerfilApple.self, from: dados), hugo)
    }
}
