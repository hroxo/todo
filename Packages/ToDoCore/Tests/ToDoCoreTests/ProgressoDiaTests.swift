import XCTest
@testable import ToDoCore

/// O dia contado pela Ampulheta no Início (DESIGN.md 7.22).
final class ProgressoDiaTests: BaseTestes {
    func testPorFazerSoContaPontosNoUltimoDia() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let urgente = try tarefas.criarItem(titulo: "Urgente", em: lista)
        let fixado = try tarefas.criarItem(titulo: "Fixado", em: lista)
        tarefas.definirFixado(fixado, true)
        avancar(horas: 50)
        let comTempo = try tarefas.criarItem(titulo: "Com tempo", em: lista)

        let progresso = ProgressoDia(ativos: [urgente, fixado, comTempo], concluidos: [], agora: relogio.agora, calendario: calendario)

        XCTAssertEqual(progresso.porFazer, 1)
        XCTAssertEqual(progresso.concluidos, 0)
    }

    func testConcluidoHojeContaEOntemNao() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let ontem = try tarefas.criarItem(titulo: "Ontem", em: lista)
        tarefas.concluir(ontem)
        avancar(dias: 1)
        let hoje = try tarefas.criarItem(titulo: "Hoje", em: lista)
        tarefas.concluir(hoje)

        let progresso = ProgressoDia(ativos: [], concluidos: [ontem, hoje], agora: relogio.agora, calendario: calendario)

        XCTAssertEqual(progresso.concluidos, 1)
        XCTAssertTrue(progresso.completo)
    }

    func testFracaoECompleto() {
        XCTAssertEqual(ProgressoDia(concluidos: 0, porFazer: 0).fracao, 0)
        XCTAssertFalse(ProgressoDia(concluidos: 0, porFazer: 0).completo)
        XCTAssertEqual(ProgressoDia(concluidos: 1, porFazer: 3).fracao, 0.25)
        XCTAssertFalse(ProgressoDia(concluidos: 1, porFazer: 3).completo)
        XCTAssertEqual(ProgressoDia(concluidos: 2, porFazer: 0).fracao, 1)
        XCTAssertTrue(ProgressoDia(concluidos: 2, porFazer: 0).completo)
    }

    func testFrases() {
        XCTAssertEqual(ProgressoDia(concluidos: 0, porFazer: 0).frase(saudacao: "Bom dia!"), "Bom dia! Nada urgente hoje.")
        XCTAssertEqual(ProgressoDia(concluidos: 0, porFazer: 1).frase(saudacao: "Boa tarde!"), "Boa tarde! Hoje é 1 ponto.")
        XCTAssertEqual(ProgressoDia(concluidos: 0, porFazer: 3).frase(saudacao: "Boa noite!"), "Boa noite! Hoje são 3 pontos.")
        XCTAssertEqual(ProgressoDia(concluidos: 1, porFazer: 1).frase(saudacao: "Bom dia!"), "Boa! Só falta 1 ponto hoje.")
        XCTAssertEqual(ProgressoDia(concluidos: 1, porFazer: 2).frase(saudacao: "Bom dia!"), "Boa! Faltam 2 pontos hoje.")
        XCTAssertEqual(ProgressoDia(concluidos: 2, porFazer: 0).frase(saudacao: "Bom dia!"), "Dia ganho! Bom trabalho.")
    }
}
