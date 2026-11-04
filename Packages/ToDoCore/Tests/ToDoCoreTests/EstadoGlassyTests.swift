import XCTest
@testable import ToDoCore

/// O humor e a areia do Glassy conforme o dia.
final class EstadoGlassyTests: BaseTestes {
    func testSemNadaPorFecharEFelizComAreiaEmCima() {
        let estado = EstadoGlassy(porFazer: 0, concluidos: 0, expirados: 0, totalAtivos: 0)
        XCTAssertEqual(estado.humor, .feliz)
        XCTAssertEqual(estado.nivelAreia, 0)
    }

    func testPoucosPontosCalmoEMuitosPreocupado() {
        let calmo = EstadoGlassy(porFazer: 2, concluidos: 0, expirados: 0, totalAtivos: 2)
        XCTAssertEqual(calmo.humor, .calmo)
        let preocupado = EstadoGlassy(porFazer: 3, concluidos: 0, expirados: 0, totalAtivos: 3)
        XCTAssertEqual(preocupado.humor, .preocupado)
        XCTAssertGreaterThan(preocupado.nivelAreia, calmo.nivelAreia)
    }

    func testAreiaNaoPassaDeUm() {
        XCTAssertEqual(EstadoGlassy(porFazer: 50, concluidos: 0, expirados: 0, totalAtivos: 50).nivelAreia, 1)
    }

    func testFalharTudoEKoComAreiaEmBaixo() {
        let estado = EstadoGlassy(porFazer: 0, concluidos: 0, expirados: 3, totalAtivos: 0)
        XCTAssertEqual(estado.humor, .ko)
        XCTAssertEqual(estado.nivelAreia, 1)
    }

    func testExpirarMasTerConcluidoOuTerAtivosNaoEKo() {
        XCTAssertNotEqual(EstadoGlassy(porFazer: 0, concluidos: 1, expirados: 2, totalAtivos: 0).humor, .ko)
        XCTAssertNotEqual(EstadoGlassy(porFazer: 1, concluidos: 0, expirados: 2, totalAtivos: 1).humor, .ko)
    }

    /// O ko atravessa a meia-noite e só passa quando a janela acaba.
    func testKoDuraAJanelaMesmoDepoisDaMeiaNoite() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        _ = try tarefas.criarItem(titulo: "Vai expirar", em: lista)
        avancar(dias: 3)
        avancar(horas: 1)
        _ = try tarefas.avaliar()
        XCTAssertEqual(try tarefas.estadoGlassy().humor, .ko)

        avancar(horas: 20)
        XCTAssertEqual(try tarefas.estadoGlassy().humor, .ko)

        avancar(horas: 4)
        XCTAssertEqual(try tarefas.estadoGlassy().humor, .feliz)
    }

    func testConcluirNaJanelaEvitaOKo() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        _ = try tarefas.criarItem(titulo: "Vai expirar", em: lista)
        avancar(dias: 3)
        avancar(horas: -1)
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))
        avancar(horas: 2)
        _ = try tarefas.avaliar()

        XCTAssertEqual(try tarefas.estadoGlassy().humor, .feliz)
    }

    /// Resumos antigos, sem o Glassy, continuam a ler-se: o widget não pode ficar em branco.
    func testResumoAntigoSemGlassyLeSe() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let antigo = #"{"frase":"Olá","pontos":[],"totalAtivos":0,"expiramHoje":0,"geradoEm":"2026-10-21T10:00:00Z"}"#
        try Data(antigo.utf8).write(to: pasta.appendingPathComponent(ResumoWidget.nomeFicheiro))

        let lido = try XCTUnwrap(ResumoWidget.ler(de: pasta))
        XCTAssertNil(lido.glassy)
    }

    func testResumoLevaOEstadoDoGlassy() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        _ = try tarefas.criarItem(titulo: "Urgente", em: lista)
        avancar(horas: 60)

        let resumo = try tarefas.resumoWidget()
        XCTAssertEqual(resumo.glassy, try tarefas.estadoGlassy())
        XCTAssertEqual(resumo.glassy?.humor, .calmo)
    }
}
