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

    /// Concluir promete 7 dias para reabrir: a lista não os pode levar ao fim de 5.
    func testEsperaPelosItensEmConcluidos() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        let item = try tarefas.criarItem(titulo: "Modo foco", em: ideias)
        tarefas.concluir(item)
        try tarefas.avaliar()

        avancar(dias: 5)
        try tarefas.avaliar()
        XCTAssertTrue(try existe(ideias))
        XCTAssertEqual(try tarefas.itens(.concluido).map(\.titulo), ["Modo foco"])

        tarefas.reabrir(item)
        XCTAssertEqual(item.lista, ideias)
        tarefas.concluir(item)

        // Acabada a retenção, o ponto sai; reabrir recomeçou a contagem da lista, que sai 5 dias depois.
        avancar(dias: 7)
        try tarefas.avaliar()
        try contexto.save()
        XCTAssertTrue(try tarefas.itens(.concluido).isEmpty)
        avancar(dias: 5)
        try tarefas.avaliar()
        XCTAssertFalse(try existe(ideias))
    }

    /// A limpeza apagar um ponto com subtópicos não é uma ação na lista.
    func testApagarPontoComSubtopicosNaoRecomecaAContagem() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        let item = try tarefas.criarItem(titulo: "Modo foco", em: ideias)
        try tarefas.adicionarSubtopico(titulo: "Ler", a: item)
        tarefas.concluir(item)
        try tarefas.avaliar()
        let desde = ideias.vaziaDesde
        XCTAssertNotNil(desde)

        avancar(dias: 1)
        tarefas.apagar(item)
        try contexto.save()

        XCTAssertEqual(ideias.vaziaDesde, desde)
        XCTAssertEqual(try contarItens(), 0)
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

    /// Num aparelho novo, o iCloud traz as listas iniciais depois de a app já as ter criado.
    func testListasIniciaisRepetidasJuntamSemPerderPontos() throws {
        try tarefas.criarListasIniciaisSeVazio()
        let pessoalLocal = try XCTUnwrap(try tarefas.listas().first { $0.nome == "Pessoal" })
        // As que chegam do outro aparelho: o Trabalho tem pontos, o Pessoal está vazio.
        let trabalho = Lista(nome: "Trabalho", cor: .azul, ordem: 2)
        let pessoal = Lista(nome: "Pessoal", cor: .roxo, ordem: 3)
        for lista in [trabalho, pessoal] {
            lista.permanente = true
            contexto.insert(lista)
        }
        try tarefas.criarItem(titulo: "Relatório", em: trabalho)

        try tarefas.avaliar()
        try contexto.save()

        let nomes = try tarefas.listas().map(\.nome).sorted()
        XCTAssertEqual(nomes, ["Pessoal", "Trabalho"])
        XCTAssertTrue(try existe(trabalho))
        XCTAssertEqual(try contarItens(), 1)
        // Duas vazias: fica a de menor id, a mesma em todos os aparelhos.
        let esperado = [pessoal, pessoalLocal].min { $0.id.uuidString < $1.id.uuidString }!.id
        XCTAssertEqual(try tarefas.listas().first { $0.nome == "Pessoal" }?.id, esperado)
    }

    func testListaApagadaFicaMarcada() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try contexto.save()
        XCTAssertFalse(ideias.foiApagado)

        tarefas.apagar(ideias)
        try contexto.save()
        XCTAssertTrue(ideias.foiApagado)
    }

    func testListaPermanenteNaoTemAviso() throws {
        let casa = try tarefas.criarLista(nome: "Casa", cor: .verde)
        try tarefas.definirPermanente(casa, true)
        try tarefas.avaliar()

        XCTAssertTrue(try tarefas.planoAvisosListas().isEmpty)
    }
}
