import XCTest
import SwiftData
@testable import ToDoCore

/// Melhoria 3: filtros por lista e por data em Concluídos e Expirados.
final class FiltroItensTests: BaseTestes {
    private var trabalho: Lista!
    private var pessoal: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        pessoal = try tarefas.criarLista(nome: "Pessoal", cor: .roxo)
    }

    /// Conclui um item no instante dado.
    private func concluido(_ titulo: String, em lista: Lista, a data: Date) throws -> Item {
        let item = try tarefas.criarItem(titulo: titulo, em: lista)
        let agora = relogio.agora
        relogio.agora = data
        tarefas.concluir(item)
        relogio.agora = agora
        return item
    }

    private func titulos(_ filtro: FiltroItens, _ itens: [Item], agora: Date? = nil) -> [String] {
        filtro.aplicar(itens, agora: agora ?? relogio.agora, calendario: calendario).map(\.titulo)
    }

    // MARK: - Lista

    func testSemFiltroDevolveTudo() throws {
        let itens = [
            try concluido("A", em: trabalho, a: data(2026, 9, 1, 10)),
            try concluido("B", em: pessoal, a: inicio),
        ]
        XCTAssertFalse(FiltroItens().ativo)
        XCTAssertEqual(titulos(FiltroItens(), itens), ["A", "B"])
    }

    func testFiltrarPorLista() throws {
        let itens = [
            try concluido("A", em: trabalho, a: inicio),
            try concluido("B", em: pessoal, a: inicio),
            try concluido("C", em: trabalho, a: inicio),
        ]
        let filtro = FiltroItens(listaId: trabalho.id)
        XCTAssertTrue(filtro.ativo)
        XCTAssertEqual(titulos(filtro, itens), ["A", "C"])
    }

    func testListaEDataEmSimultaneo() throws {
        let itens = [
            try concluido("Trabalho hoje", em: trabalho, a: data(2026, 10, 21, 8)),
            try concluido("Trabalho há 10 dias", em: trabalho, a: data(2026, 10, 11, 8)),
            try concluido("Pessoal hoje", em: pessoal, a: data(2026, 10, 21, 8)),
        ]
        let filtro = FiltroItens(listaId: trabalho.id, periodo: .ultimos7)
        XCTAssertEqual(titulos(filtro, itens), ["Trabalho hoje"])
    }

    // MARK: - Datas

    /// "Hoje" começa à meia-noite: 23:59 de ontem fica de fora, 00:00 de hoje entra.
    func testHojeComecaAMeiaNoite() throws {
        let itens = [
            try concluido("Ontem 23:59", em: trabalho, a: data(2026, 10, 20, 23, 59)),
            try concluido("Hoje 00:00", em: trabalho, a: data(2026, 10, 21, 0, 0)),
            try concluido("Hoje 09:00", em: trabalho, a: data(2026, 10, 21, 9, 0)),
        ]
        XCTAssertEqual(titulos(FiltroItens(periodo: .hoje), itens), ["Hoje 00:00", "Hoje 09:00"])
    }

    /// "Últimos 7 dias" é hoje e os 6 dias antes, desde a meia-noite.
    func testUltimos7DiasLimites() throws {
        let itens = [
            try concluido("Dia 14 23:59", em: trabalho, a: data(2026, 10, 14, 23, 59)),
            try concluido("Dia 15 00:00", em: trabalho, a: data(2026, 10, 15, 0, 0)),
            try concluido("Hoje", em: trabalho, a: inicio),
        ]
        XCTAssertEqual(titulos(FiltroItens(periodo: .ultimos7), itens), ["Dia 15 00:00", "Hoje"])
    }

    func testUltimos30DiasLimites() throws {
        let itens = [
            try concluido("21/09 23:59", em: trabalho, a: data(2026, 9, 21, 23, 59)),
            try concluido("22/09 00:00", em: trabalho, a: data(2026, 9, 22, 0, 0)),
        ]
        XCTAssertEqual(titulos(FiltroItens(periodo: .ultimos30), itens), ["22/09 00:00"])
        XCTAssertEqual(titulos(FiltroItens(periodo: .tudo), itens), ["21/09 23:59", "22/09 00:00"])
    }

    /// A mudança para a hora de inverno (25/10/2026 em Lisboa) não desloca a meia-noite.
    func testMudancaDaHora() throws {
        let agora = data(2026, 10, 27, 12)
        let itens = [
            try concluido("20/10 23:30", em: trabalho, a: data(2026, 10, 20, 23, 30)),
            try concluido("21/10 00:30", em: trabalho, a: data(2026, 10, 21, 0, 30)),
        ]
        XCTAssertEqual(titulos(FiltroItens(periodo: .ultimos7), itens, agora: agora), ["21/10 00:30"])
    }

    /// Os dias contam no fuso do dispositivo: o mesmo instante é "hoje" em Lisboa e "ontem"
    /// em Nova Iorque.
    func testFusoHorario() throws {
        // 21/10 00:30 em Lisboa = 20/10 19:30 em Nova Iorque.
        let item = try concluido("Meia-noite e meia", em: trabalho, a: data(2026, 10, 21, 0, 30))
        let agora = data(2026, 10, 21, 10)
        let filtro = FiltroItens(periodo: .hoje)

        XCTAssertEqual(filtro.aplicar([item], agora: agora, calendario: calendario).count, 1)

        var novaIorque = Calendar(identifier: .gregorian)
        novaIorque.timeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(filtro.aplicar([item], agora: agora, calendario: novaIorque).count, 0)
    }

    /// Nos expirados conta a data de expiração.
    func testExpiradosPelaDataDeExpiracao() throws {
        let antigo = try tarefas.criarItem(titulo: "Antigo", em: trabalho)
        avancar(dias: 3)
        let recente = try tarefas.criarItem(titulo: "Recente", em: pessoal)
        avancar(dias: 3)
        avancar(horas: 1)
        try tarefas.avaliar()
        XCTAssertEqual(antigo.estado, .expirado)
        XCTAssertEqual(recente.estado, .expirado)

        // Antigo expirou a 24/10 10:00 e Recente a 27/10 10:00; agora são 27/10 11:00.
        XCTAssertEqual(titulos(FiltroItens(periodo: .hoje), [antigo, recente]), ["Recente"])
        XCTAssertEqual(titulos(FiltroItens(periodo: .ultimos7), [antigo, recente]), ["Antigo", "Recente"])
        XCTAssertEqual(titulos(FiltroItens(listaId: trabalho.id), [antigo, recente]), ["Antigo"])
    }

    // MARK: - Ficha

    func testRotuloDaFicha() {
        XCTAssertEqual(FiltroItens(listaId: UUID(), periodo: .ultimos7).rotulo(nomeLista: "Trabalho"), "Trabalho · Últimos 7 dias")
        XCTAssertEqual(FiltroItens(listaId: UUID()).rotulo(nomeLista: "Pessoal"), "Pessoal")
        XCTAssertEqual(FiltroItens(periodo: .hoje).rotulo(nomeLista: nil), "Hoje")
        XCTAssertEqual(FiltroItens().rotulo(nomeLista: nil), "")
    }
}
