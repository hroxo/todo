import XCTest
@testable import ToDoCore

final class CalendarioTests: BaseTestes {
    /// Critério 15: o "+" de um evento cria um ponto ativo com o título do evento e 3 dias de vida.
    func testCriterio15PontoAPartirDeEvento() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)

        let item = try tarefas.criarPontoDeEvento(
            titulo: "Revisão do roadmap Q1",
            inicio: data(2026, 10, 21, 14, 30),
            fim: data(2026, 10, 21, 15, 30),
            diaInteiro: false,
            detalhe: "Sala 3 · Trabalho",
            em: lista
        )

        XCTAssertEqual(item.titulo, "Revisão do roadmap Q1")
        XCTAssertEqual(item.estado, .ativo)
        XCTAssertEqual(item.lista, lista)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
        XCTAssertEqual(item.nota, "Calendário: 14:30–15:30 · Sala 3 · Trabalho")
    }

    func testPontoDeEventoDeDiaInteiro() throws {
        let lista = try tarefas.criarLista(nome: "Pessoal", cor: .roxo)

        let item = try tarefas.criarPontoDeEvento(
            titulo: "Aniversário da Ana",
            inicio: data(2026, 10, 21, 0, 0),
            fim: data(2026, 10, 22, 0, 0),
            diaInteiro: true,
            detalhe: nil,
            em: lista
        )

        XCTAssertEqual(item.nota, "Calendário: todo o dia")
    }

    func testHoras() {
        XCTAssertEqual(Formatos.hora(data(2026, 10, 21, 9, 5), calendario: calendario), "09:05")
        XCTAssertEqual(
            Formatos.intervalo(data(2026, 10, 21, 19, 0), data(2026, 10, 21, 20, 0), calendario: calendario),
            "19:00–20:00"
        )
    }
}
