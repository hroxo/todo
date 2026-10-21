import XCTest
@testable import ToDoCore

final class EspacosTests: BaseTestes {
    func testMaximoDeOitoEspacos() throws {
        for n in 1...Tarefas.maxListas {
            try tarefas.criarLista(nome: "Espaço \(n)", cor: .azul)
        }
        XCTAssertThrowsError(try tarefas.criarLista(nome: "Nono", cor: .rosa)) { erro in
            XCTAssertEqual(erro as? ErroTarefas, .limiteListas)
        }
        XCTAssertEqual(try tarefas.listas().count, Tarefas.maxListas)
    }

    func testAteQuatroEspacosUmaSoPagina() {
        let paginas = Espacos.paginas(["A", "B", "C", "D", "+"], espacos: 4)
        XCTAssertEqual(paginas, [["A", "B", "C", "D", "+"]])
    }

    func testMaisDeQuatroEspacosEmPaginasDeQuatro() {
        let paginas = Espacos.paginas(["A", "B", "C", "D", "E", "F", "+"], espacos: 6)
        XCTAssertEqual(paginas, [["A", "B", "C", "D"], ["E", "F", "+"]])
        XCTAssertEqual(Espacos.rotuloPagina(0, espacos: 6), "Espaços 1–4 de 6")
        XCTAssertEqual(Espacos.rotuloPagina(1, espacos: 6), "Espaços 5–6 de 6")
        XCTAssertEqual(Espacos.rotuloPagina(1, espacos: 5), "Espaço 5 de 5")
    }

    func testOitoEspacosSemNovaLista() {
        let paginas = Espacos.paginas(Array("ABCDEFGH").map(String.init), espacos: 8)
        XCTAssertEqual(paginas.count, 2)
        XCTAssertEqual(paginas[1], ["E", "F", "G", "H"])
    }

    func testAssociacaoPorNome() {
        let trabalho = UUID()
        let ginasio = UUID()
        let resultado = Espacos.associarPorNome(
            calendarios: [("c1", "trabalho"), ("c2", "Ginasio"), ("c3", "Feriados em Portugal")],
            espacos: [(trabalho, "Trabalho"), (ginasio, "Ginásio")]
        )
        XCTAssertEqual(resultado, ["c1": trabalho, "c2": ginasio])
    }
}
