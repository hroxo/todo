import XCTest
import SwiftData
@testable import ToDoCore

/// Listas que desaparecem ao fim de 5 dias sem pontos abertos, e as 4 permanentes
/// (DESIGN.md 7.17).
final class ListasVaziasTests: BaseTestes {
    private func existe(_ lista: Lista) throws -> Bool {
        try tarefas.listas().contains { $0.id == lista.id }
    }

    func testListaVaziaDesapareceAoFimDeCincoDias() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()
        XCTAssertEqual(ideias.vaziaDesde, relogio.agora)

        avancar(dias: 4)
        try tarefas.avaliar()
        XCTAssertTrue(try existe(ideias))

        avancar(dias: 1)
        try tarefas.avaliar()
        XCTAssertFalse(try existe(ideias))
    }

    func testListaPermanenteNuncaDesaparece() throws {
        let casa = try tarefas.criarLista(nome: "Casa", cor: .verde)
        try tarefas.definirPermanente(casa, true)

        try tarefas.avaliar()
        avancar(dias: 30)
        try tarefas.avaliar()

        XCTAssertTrue(try existe(casa))
        XCTAssertNil(tarefas.quandoDesaparece(casa))
    }

    func testUmPontoNovoParaAContagem() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()
        avancar(dias: 4)

        try tarefas.criarItem(titulo: "App de receitas", em: ideias)
        avancar(dias: 2)
        try tarefas.avaliar()

        XCTAssertTrue(try existe(ideias))
        XCTAssertNil(ideias.vaziaDesde)
    }

    /// Quando o último ponto é concluído, a contagem começa nesse dia.
    func testContagemComecaQuandoOUltimoPontoSai() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        let item = try tarefas.criarItem(titulo: "App de receitas", em: ideias)
        avancar(dias: 1)
        tarefas.concluir(item)
        try tarefas.avaliar()

        XCTAssertEqual(ideias.vaziaDesde, relogio.agora)
        XCTAssertEqual(tarefas.quandoDesaparece(ideias), dias(5, desde: relogio.agora))
    }

    /// Nada se perde por engano: com itens em Expirados, a lista espera por eles.
    func testEsperaPelosItensEmExpirados() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        let item = try tarefas.criarItem(titulo: "Modo foco", em: ideias)
        avancar(dias: 3)
        try tarefas.avaliar()
        XCTAssertEqual(item.estado, .expirado)

        avancar(dias: 6)
        try tarefas.avaliar()
        XCTAssertTrue(try existe(ideias))

        tarefas.recuperar(item)
        XCTAssertEqual(item.lista, ideias)
        XCTAssertNil(ideias.vaziaDesde)
    }

    func testManterListaRecomecaAContagem() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()
        avancar(dias: 4)

        tarefas.manterLista(ideias)
        avancar(dias: 4)
        try tarefas.avaliar()

        XCTAssertTrue(try existe(ideias))
        XCTAssertEqual(tarefas.quandoDesaparece(ideias), dias(1, desde: relogio.agora))
    }

    func testNoMaximoQuatroPermanentes() throws {
        let listas = try (0..<5).map { try tarefas.criarLista(nome: "Lista \($0)", cor: .azul) }
        for lista in listas.prefix(4) {
            try tarefas.definirPermanente(lista, true)
        }

        XCTAssertFalse(try tarefas.podeSerPermanente())
        XCTAssertThrowsError(try tarefas.definirPermanente(listas[4], true)) {
            XCTAssertEqual($0 as? ErroTarefas, .limitePermanentes)
        }
        try tarefas.definirPermanente(listas[0], false)
        XCTAssertNoThrow(try tarefas.definirPermanente(listas[4], true))
    }

    func testListasIniciaisSaoPermanentes() throws {
        try tarefas.criarListasIniciaisSeVazio()
        XCTAssertEqual(try tarefas.listas().map(\.permanente), [true, true])
    }

    func testAvisoVinteEQuatroHorasAntesDeDesaparecer() throws {
        relogio.agora = data(2026, 10, 21, 15, 30)
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()

        let aviso = try XCTUnwrap(tarefas.planoAvisosListas().first)

        XCTAssertEqual(aviso.listaId, ideias.id)
        XCTAssertEqual(aviso.data, data(2026, 10, 25, 15, 30))
        XCTAssertEqual(TextoAviso.tituloLista(aviso), "«Ideias» vai desaparecer")
        XCTAssertEqual(
            TextoAviso.corpoLista(aviso, calendario: calendario),
            "Sem pontos abertos há 4 dias. Sai amanhã às 15:30, a não ser que a mantenhas."
        )
    }

    func testListaPermanenteNaoTemAviso() throws {
        let casa = try tarefas.criarLista(nome: "Casa", cor: .verde)
        try tarefas.definirPermanente(casa, true)
        try tarefas.avaliar()

        XCTAssertTrue(try tarefas.planoAvisosListas().isEmpty)
    }
}
