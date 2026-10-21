import XCTest
import SwiftData
@testable import ToDoCore

final class TarefasTests: BaseTestes {
    // MARK: - Listas

    func testListasIniciaisCriadasUmaSoVez() throws {
        XCTAssertTrue(try tarefas.criarListasIniciaisSeVazio())
        XCTAssertFalse(try tarefas.criarListasIniciaisSeVazio())

        let listas = try tarefas.listas()
        XCTAssertEqual(listas.map(\.nome), ["Trabalho", "Pessoal"])
        XCTAssertEqual(listas.map(\.ordem), [0, 1])
        XCTAssertEqual(listas.map(\.cor), [.azul, .roxo])
        XCTAssertEqual(listas.map(\.icone), ["briefcase.fill", "person.fill"])
    }

    func testEditarListaComEmoji() throws {
        let lista = try tarefas.criarLista(nome: "Casa", cor: .verde)
        XCTAssertEqual(lista.icone, IconesLista.padrao)
        XCTAssertNil(lista.emoji)

        try tarefas.editar(lista, nome: "Casa", cor: .castanho, icone: "house.fill", emoji: " 🏠 ")
        XCTAssertEqual(lista.cor, .castanho)
        XCTAssertEqual(lista.emoji, "🏠")

        try tarefas.editar(lista, nome: "Casa", cor: .castanho, icone: "house.fill", emoji: "")
        XCTAssertNil(lista.emoji)
    }

    func testCorAntigaDoM1() {
        XCTAssertEqual(CorLista.deChave("ciano"), .turquesa)
        XCTAssertEqual(CorLista.deChave("indigo"), .indigo)
        XCTAssertEqual(CorLista.deChave("inexistente"), .azul)
    }

    func testCriarListaFicaNoFim() throws {
        try tarefas.criarListasIniciaisSeVazio()
        let compras = try tarefas.criarLista(nome: "  Compras ", cor: .laranja)
        XCTAssertEqual(compras.nome, "Compras")
        XCTAssertEqual(compras.cor, .laranja)
        XCTAssertEqual(compras.ordem, 2)
    }

    func testListaSemNomeDaErro() {
        XCTAssertThrowsError(try tarefas.criarLista(nome: "   ", cor: .azul)) { erro in
            XCTAssertEqual(erro as? ErroTarefas, .textoVazio)
        }
    }

    func testReordenarListas() throws {
        try tarefas.criarListasIniciaisSeVazio()
        try tarefas.criarLista(nome: "Compras", cor: .rosa)
        var listas = try tarefas.listas()
        listas.insert(listas.remove(at: 2), at: 0)
        tarefas.reordenar(listas)
        XCTAssertEqual(try tarefas.listas().map(\.nome), ["Compras", "Trabalho", "Pessoal"])
    }

    func testApagarListaApagaItensESubtopicos() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pessoal = try tarefas.criarLista(nome: "Pessoal", cor: .verde)
        let reuniao = try tarefas.criarItem(titulo: "Reunião", em: trabalho)
        try tarefas.adicionarSubtopico(titulo: "Agenda", a: reuniao)
        try tarefas.criarItem(titulo: "Relatório", em: trabalho)
        try tarefas.criarItem(titulo: "Ginásio", em: pessoal)

        XCTAssertEqual(tarefas.contarItens(de: trabalho), 2)

        tarefas.apagar(trabalho)
        try contexto.save()

        XCTAssertEqual(try tarefas.listas().map(\.nome), ["Pessoal"])
        XCTAssertEqual(try contarItens(), 1)
    }

    // MARK: - Itens

    func testItemNasceAtivoComTresDias() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarItem(titulo: "Preparar reunião", em: lista)

        XCTAssertEqual(item.estado, .ativo)
        XCTAssertEqual(item.tipo, .tarefa)
        XCTAssertFalse(item.fixado)
        XCTAssertEqual(item.criadoEm, inicio)
        XCTAssertEqual(item.expiraEm, dias(3, desde: inicio))
        XCTAssertEqual(lista.itensAtivos.map(\.titulo), ["Preparar reunião"])
    }

    func testEditarReiniciaExpiracao() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarItem(titulo: "Rascunho", em: lista)
        avancar(dias: 2)

        try tarefas.editarTitulo(item, para: "Versão final")

        XCTAssertEqual(item.titulo, "Versão final")
        XCTAssertEqual(item.ultimaAcaoEm, relogio.agora)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
    }

    func testConcluirEReabrir() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarItem(titulo: "Enviar email", em: lista)

        tarefas.concluir(item)
        XCTAssertEqual(item.estado, .concluido)
        XCTAssertEqual(item.concluidoEm, inicio)
        XCTAssertNil(item.expiraEm)
        XCTAssertTrue(lista.itensAtivos.isEmpty)

        avancar(dias: 1)
        tarefas.reabrir(item)
        XCTAssertEqual(item.estado, .ativo)
        XCTAssertNil(item.concluidoEm)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
    }

    func testFixarEDesafixar() throws {
        let lista = try tarefas.criarLista(nome: "Pessoal", cor: .verde)
        let item = try tarefas.criarItem(titulo: "Renovar seguro", em: lista)

        tarefas.definirFixado(item, true)
        XCTAssertTrue(item.fixado)
        XCTAssertNil(item.expiraEm)

        avancar(dias: 10)
        try tarefas.editarTitulo(item, para: "Renovar seguro do carro")
        XCTAssertNil(item.expiraEm, "Uma ação não dá prazo a um item fixado")

        tarefas.definirFixado(item, false)
        XCTAssertFalse(item.fixado)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
    }

    func testMoverParaOutraLista() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pessoal = try tarefas.criarLista(nome: "Pessoal", cor: .verde)
        try tarefas.criarItem(titulo: "Ginásio", em: pessoal)
        let item = try tarefas.criarItem(titulo: "Marcar médico", em: trabalho)
        try tarefas.adicionarSubtopico(titulo: "Ligar", a: item)
        avancar(dias: 1)

        tarefas.mover(item, para: pessoal)

        XCTAssertTrue(trabalho.itens.isEmpty)
        XCTAssertEqual(pessoal.itensAtivos.map(\.titulo), ["Ginásio", "Marcar médico"])
        XCTAssertEqual(item.subtopicos.first?.listaEfetiva, pessoal)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
    }

    func testConverterNotaETarefa() throws {
        let lista = try tarefas.criarLista(nome: "Pessoal", cor: .verde)
        let nota = try tarefas.criarItem(titulo: "Ideia", em: lista, tipo: .notaRapida)

        tarefas.converter(nota)
        XCTAssertEqual(nota.tipo, .tarefa)
        tarefas.converter(nota)
        XCTAssertEqual(nota.tipo, .notaRapida)
    }

    // MARK: - Subtópicos

    func testAcaoNoSubtopicoReiniciaExpiracaoDoPai() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pai = try tarefas.criarItem(titulo: "Reunião", em: lista)
        let sub = try tarefas.adicionarSubtopico(titulo: "Agenda", a: pai)
        avancar(dias: 2)

        tarefas.alternarSubtopico(sub)

        XCTAssertEqual(sub.estado, .concluido)
        XCTAssertNil(sub.expiraEm, "Os subtópicos acompanham o pai e não têm prazo próprio")
        XCTAssertEqual(pai.ultimaAcaoEm, relogio.agora)
        XCTAssertEqual(pai.expiraEm, dias(3, desde: relogio.agora))
    }

    func testSubtopicoNaoPodeTerSubtopicos() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pai = try tarefas.criarItem(titulo: "Reunião", em: lista)
        let sub = try tarefas.adicionarSubtopico(titulo: "Agenda", a: pai)

        XCTAssertThrowsError(try tarefas.adicionarSubtopico(titulo: "Ponto 1", a: sub)) { erro in
            XCTAssertEqual(erro as? ErroTarefas, .subtopicoDeSubtopico)
        }
    }

    func testSubtopicosNaoAparecemComoItensDaLista() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pai = try tarefas.criarItem(titulo: "Reunião", em: lista)
        try tarefas.adicionarSubtopico(titulo: "Agenda", a: pai)
        try tarefas.adicionarSubtopico(titulo: "Sala", a: pai)

        XCTAssertEqual(lista.itensAtivos.map(\.titulo), ["Reunião"])
        XCTAssertEqual(pai.subtopicosOrdenados.map(\.titulo), ["Agenda", "Sala"])
    }

    /// Critério 5: ao concluir o último subtópico, a app sugere concluir o item principal
    /// e não o conclui sozinha.
    func testCriterio5UltimoSubtopicoSugereConcluirSemConcluir() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pai = try tarefas.criarItem(titulo: "Reunião", em: lista)
        let agenda = try tarefas.adicionarSubtopico(titulo: "Agenda", a: pai)
        let sala = try tarefas.adicionarSubtopico(titulo: "Sala", a: pai)

        XCTAssertFalse(tarefas.alternarSubtopico(agenda), "Ainda falta um subtópico")
        XCTAssertTrue(tarefas.alternarSubtopico(sala), "O último subtópico sugere concluir")
        XCTAssertEqual(pai.estado, .ativo, "O item principal não é concluído sozinho")
        XCTAssertEqual(pai.subtopicosFeitos, 2)

        XCTAssertFalse(tarefas.alternarSubtopico(sala), "Reabrir não sugere nada")
        XCTAssertEqual(sala.estado, .ativo)
    }

    /// Critério 6: apagar um item pelo menu "…" apaga o item e todos os subtópicos.
    func testCriterio6ApagarItemApagaSubtopicos() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pai = try tarefas.criarItem(titulo: "Reunião", em: lista)
        try tarefas.adicionarSubtopico(titulo: "Agenda", a: pai)
        try tarefas.adicionarSubtopico(titulo: "Sala", a: pai)
        try tarefas.criarItem(titulo: "Relatório", em: lista)
        try contexto.save()
        XCTAssertEqual(try contarItens(), 4)

        tarefas.apagar(pai)
        try contexto.save()

        XCTAssertEqual(try contarItens(), 1)
        XCTAssertEqual(lista.itens.map(\.titulo), ["Relatório"])
    }

    func testApagarSubtopicoSoApagaEsse() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let pai = try tarefas.criarItem(titulo: "Reunião", em: lista)
        let agenda = try tarefas.adicionarSubtopico(titulo: "Agenda", a: pai)
        try tarefas.adicionarSubtopico(titulo: "Sala", a: pai)

        tarefas.apagar(agenda)
        try contexto.save()

        XCTAssertEqual(try contarItens(), 2)
        XCTAssertEqual(pai.subtopicos.map(\.titulo), ["Sala"])
    }
}
