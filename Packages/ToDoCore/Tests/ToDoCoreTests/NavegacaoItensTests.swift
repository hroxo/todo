import XCTest
import SwiftData
@testable import ToDoCore

/// Melhoria 5: navegar entre itens no Detalhe.
final class NavegacaoItensTests: BaseTestes {
    private var lista: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    private func titulos(_ itens: [Item]) -> [String] { itens.map(\.titulo) }

    func testFixadosPrimeiroDepoisAtivos() throws {
        _ = try tarefas.criarItem(titulo: "A", em: lista)
        let b = try tarefas.criarItem(titulo: "B", em: lista)
        _ = try tarefas.criarItem(titulo: "C", em: lista)
        let d = try tarefas.criarItem(titulo: "D", em: lista)
        tarefas.definirFixado(d, true)
        tarefas.definirFixado(b, true)

        XCTAssertEqual(titulos(NavegacaoItens.ordem(lista)), ["B", "D", "A", "C"])
    }

    func testPercorrerTodosPelaOrdem() throws {
        for titulo in ["A", "B", "C"] {
            _ = try tarefas.criarItem(titulo: titulo, em: lista)
        }
        let fixo = try tarefas.criarItem(titulo: "Fixo", em: lista)
        tarefas.definirFixado(fixo, true)
        let ordem = NavegacaoItens.ordem(lista)

        var visitados = [ordem[0]]
        while let proximo = NavegacaoItens.seguinte(de: visitados.last!, em: ordem) {
            visitados.append(proximo)
        }
        XCTAssertEqual(titulos(visitados), ["Fixo", "A", "B", "C"])

        var recuados = [ordem[3]]
        while let antes = NavegacaoItens.anterior(de: recuados.last!, em: ordem) {
            recuados.append(antes)
        }
        XCTAssertEqual(titulos(recuados), ["C", "B", "A", "Fixo"])
    }

    func testPrimeiroEUltimo() throws {
        let a = try tarefas.criarItem(titulo: "A", em: lista)
        let b = try tarefas.criarItem(titulo: "B", em: lista)
        let ordem = NavegacaoItens.ordem(lista)

        XCTAssertNil(NavegacaoItens.anterior(de: a, em: ordem))
        XCTAssertEqual(NavegacaoItens.seguinte(de: a, em: ordem)?.titulo, "B")
        XCTAssertNil(NavegacaoItens.seguinte(de: b, em: ordem))
    }

    func testSoOsAtivosEntram() throws {
        let a = try tarefas.criarItem(titulo: "A", em: lista)
        let b = try tarefas.criarItem(titulo: "B", em: lista)
        let c = try tarefas.criarItem(titulo: "C", em: lista)
        tarefas.concluir(b)
        let ordem = NavegacaoItens.ordem(lista)

        XCTAssertEqual(NavegacaoItens.seguinte(de: a, em: ordem)?.titulo, "C")
        XCTAssertEqual(NavegacaoItens.anterior(de: c, em: ordem)?.titulo, "A")
        // Um item fora da ordem (já concluído) não tem vizinhos.
        XCTAssertNil(NavegacaoItens.seguinte(de: b, em: ordem))
        XCTAssertNil(NavegacaoItens.anterior(de: b, em: ordem))
    }

    func testUmSoItem() throws {
        let a = try tarefas.criarItem(titulo: "A", em: lista)
        let ordem = NavegacaoItens.ordem(lista)
        XCTAssertNil(NavegacaoItens.seguinte(de: a, em: ordem))
        XCTAssertNil(NavegacaoItens.anterior(de: a, em: ordem))
    }
}
