import XCTest
@testable import ToDoCore

/// O tema da Ampulheta reflete onde a pessoa tem andado a mexer (DESIGN.md 7.14).
final class TemaMascoteTests: BaseTestes {
    func testTemaDaListaPeloIconeEPeloNome() throws {
        XCTAssertEqual(try tarefas.criarLista(nome: "Coisas", cor: .azul, icone: "briefcase.fill").tema, .trabalho)
        XCTAssertEqual(try tarefas.criarLista(nome: "Férias em Lisboa", cor: .ceu).tema, .viagem)
        XCTAssertEqual(try tarefas.criarLista(nome: "Ginásio", cor: .vermelho).tema, .desporto)
        XCTAssertEqual(try tarefas.criarLista(nome: "Livros", cor: .roxo, emoji: "📚").tema, .pessoal)
        XCTAssertNil(try tarefas.criarLista(nome: "Ideias", cor: .amarelo, icone: "lightbulb.fill").tema)
    }

    func testGanhaOTemaComMaisAtividadeNaSemana() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul, icone: "briefcase.fill")
        let pessoal = try tarefas.criarLista(nome: "Pessoal", cor: .roxo, icone: "person.fill")
        try tarefas.criarItem(titulo: "Relatório", em: trabalho)
        for titulo in ["Ler", "Correr", "Jantar"] {
            try tarefas.criarItem(titulo: titulo, em: pessoal)
        }

        XCTAssertEqual(try tarefas.temaMascote(), .pessoal)
    }

    func testAtividadeAntigaNaoConta() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul, icone: "briefcase.fill")
        let pessoal = try tarefas.criarLista(nome: "Pessoal", cor: .roxo, icone: "person.fill")
        for titulo in ["A", "B", "C"] {
            let item = try tarefas.criarItem(titulo: titulo, em: pessoal)
            tarefas.definirFixado(item, true)
        }
        avancar(dias: 10)
        try tarefas.criarItem(titulo: "Relatório", em: trabalho)

        XCTAssertEqual(try tarefas.temaMascote(), .trabalho)
    }

    func testViagemComPontosAbertosGanhaSempre() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul, icone: "briefcase.fill")
        for titulo in ["A", "B", "C"] {
            try tarefas.criarItem(titulo: titulo, em: trabalho)
        }
        let viagem = try tarefas.criarLista(nome: "Viagem", cor: .ceu, icone: "airplane")
        try tarefas.criarItem(titulo: "Passaporte", em: viagem)

        XCTAssertEqual(try tarefas.temaMascote(), .viagem)
    }

    func testSemAtividadeOuSemTemaFicaGeral() throws {
        XCTAssertEqual(try tarefas.temaMascote(), .geral)
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo, icone: "lightbulb.fill")
        try tarefas.criarItem(titulo: "App", em: ideias)
        XCTAssertEqual(try tarefas.temaMascote(), .geral)
    }

    func testOResumoLevaOTema() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul, icone: "briefcase.fill")
        try tarefas.criarItem(titulo: "Relatório", em: trabalho)
        XCTAssertEqual(try tarefas.resumoWidget().tema, .trabalho)
    }
}
