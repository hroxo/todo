import XCTest
@testable import ToDoCore

/// O cartão "Para ti" do Início (DESIGN.md 7.21).
final class ParaTiTests: BaseTestes {
    private var trabalho: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        try tarefas.definirPermanente(trabalho, true)
    }

    func testSemNadaRelevanteNaoHaCartao() throws {
        try tarefas.criarItem(titulo: "Com tempo", em: trabalho)
        XCTAssertNil(try tarefas.paraTi())
    }

    func testPrazosNoUltimoDia() throws {
        relogio.agora = data(2026, 10, 21, 10, 0)
        let demo = try tarefas.criarItem(titulo: "Demo de sexta", em: trabalho)
        // Um minuto depois: expira a seguir à demo, para a ordem não depender do acaso.
        relogio.agora = data(2026, 10, 21, 10, 1)
        try tarefas.criarItem(titulo: "Relatório", em: trabalho)
        avancar(horas: 50)

        let cartao = try XCTUnwrap(tarefas.paraTi())

        XCTAssertEqual(cartao.motivo, .prazos)
        XCTAssertEqual(cartao.fraseBase, "2 pontos expiram em breve, o primeiro amanhã às 10:00: «Demo de sexta».")
        XCTAssertEqual(cartao.botoes.map(\.acao), [.abrirItem(demo.id), .manter(demo.id)])
        XCTAssertEqual(cartao.botoes.last?.rotulo, "Manter +5")
    }

    func testListaQueSaiAmanha() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()
        avancar(dias: 4)

        let cartao = try XCTUnwrap(tarefas.paraTi())

        XCTAssertEqual(cartao.motivo, .listaASair)
        XCTAssertEqual(cartao.fraseBase, "A lista «Ideias» está sem pontos e sai do Início amanhã. Queres guardá-la?")
        XCTAssertEqual(cartao.botoes.map(\.acao), [.tornarPermanente(ideias.id), .manterLista(ideias.id)])
    }

    func testEventoComSubtopicosPorFazerNoMesmoEspaco() throws {
        let roadmap = try tarefas.criarItem(titulo: "Rever roadmap", em: trabalho)
        try tarefas.adicionarSubtopico(titulo: "Dependências", a: roadmap)
        try tarefas.adicionarSubtopico(titulo: "Comentários", a: roadmap)
        let evento = EventoProximo(titulo: "Alinhamento", inicio: relogio.agora.addingTimeInterval(3600), listaId: trabalho.id)

        let cartao = try XCTUnwrap(tarefas.paraTi(eventos: [evento]))

        XCTAssertEqual(cartao.motivo, .evento)
        XCTAssertEqual(cartao.fraseBase, "Às 11:00 tens «Alinhamento». «Rever roadmap» ainda tem 2 subtópicos por fazer.")
        XCTAssertEqual(cartao.botoes.first?.acao, .abrirItem(roadmap.id))
    }

    func testEventoLongeNaoConta() throws {
        let roadmap = try tarefas.criarItem(titulo: "Rever roadmap", em: trabalho)
        try tarefas.adicionarSubtopico(titulo: "Dependências", a: roadmap)
        let evento = EventoProximo(titulo: "Jantar", inicio: relogio.agora.addingTimeInterval(5 * 3600), listaId: trabalho.id)
        XCTAssertNil(try tarefas.paraTi(eventos: [evento]))
    }

    func testVistaPartilhadaAMeio() throws {
        let compras = try tarefas.criarLista(nome: "Compras", cor: .verde, tipo: .compras)
        try tarefas.definirPermanente(compras, true)
        let continente = try tarefas.criarItem(titulo: "Continente", em: compras)
        for titulo in ["Leite", "Pão", "Fruta"] {
            try tarefas.adicionarSubtopico(titulo: titulo, a: continente)
        }
        let ikea = try tarefas.criarItem(titulo: "IKEA", em: compras)
        let candeeiro = try tarefas.adicionarSubtopico(titulo: "Candeeiro", a: ikea)
        tarefas.alternarSubtopico(candeeiro)

        let cartao = try XCTUnwrap(tarefas.paraTi())

        XCTAssertEqual(cartao.motivo, .vistaPartilhada)
        XCTAssertEqual(cartao.fraseBase, "Faltam 3 pontos em «Continente» e «IKEA» já está feita.")
        XCTAssertEqual(cartao.botoes.first?.acao, .abrirLista(compras.id))
    }

    /// Os prazos ganham às outras razões.
    func testPrazosTemPrioridade() throws {
        try tarefas.criarItem(titulo: "Urgente", em: trabalho)
        try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()
        avancar(dias: 2)
        avancar(horas: 2)
        XCTAssertEqual(try tarefas.paraTi()?.motivo, .prazos)
    }
}
