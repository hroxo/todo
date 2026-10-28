import XCTest
import SwiftData
@testable import ToDoCore

/// O que o widget mostra e a base de dados partilhada com ele (DESIGN.md 7.14).
final class WidgetTests: BaseTestes {
    private var trabalho: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    func testOQueExpiraHojeVemPrimeiro() throws {
        relogio.agora = data(2026, 10, 21, 10, 0)
        try tarefas.criarItem(titulo: "Novo", em: trabalho)
        avancar(horas: -60)
        let antigo = try tarefas.criarItem(titulo: "Demo de sexta", em: trabalho)
        avancar(horas: 60)

        let ordem = try tarefas.prioridades()

        XCTAssertEqual(ordem.map(\.item.titulo), ["Demo de sexta", "Novo"])
        XCTAssertEqual(ordem.first?.item, antigo)
        XCTAssertEqual(ordem.first?.razao, "Expira hoje às 22:00")
    }

    func testRazoesDeSubtopicosEDeDiasParado() throws {
        let quase = try tarefas.criarItem(titulo: "Quase", em: trabalho)
        let a = try tarefas.adicionarSubtopico(titulo: "A", a: quase)
        try tarefas.adicionarSubtopico(titulo: "B", a: quase)
        tarefas.alternarSubtopico(a)
        let parado = try tarefas.criarItem(titulo: "Parado", em: trabalho)
        tarefas.manter(parado, longo: true)
        avancar(dias: 2)

        let razoes = Dictionary(uniqueKeysWithValues: try tarefas.prioridades().map { ($0.item.titulo, $0.razao) })

        // A 24 h certas ainda não é o último dia: pesa o subtópico que falta.
        XCTAssertEqual(razoes["Quase"], "Falta 1 subtópico")
        XCTAssertEqual(razoes["Parado"], "Sem mexer há 2 dias")
    }

    func testFicamDeForaFixadosComprasESubtopicos() throws {
        let fixo = try tarefas.criarItem(titulo: "Fixo", em: trabalho)
        tarefas.definirFixado(fixo, true)
        let compras = try tarefas.criarLista(nome: "Compras", cor: .verde, tipo: .compras)
        try tarefas.criarItem(titulo: "Continente", em: compras)
        let pai = try tarefas.criarItem(titulo: "Pai", em: trabalho)
        try tarefas.adicionarSubtopico(titulo: "Filho", a: pai)

        XCTAssertEqual(try tarefas.prioridades().map(\.item.titulo), ["Pai"])
    }

    func testResumoTemAFraseDeBaseENoMaximoTresPontos() throws {
        for titulo in ["A", "B", "C", "D"] {
            try tarefas.criarItem(titulo: titulo, em: trabalho)
        }
        avancar(horas: 50)

        let resumo = try tarefas.resumoWidget()

        XCTAssertEqual(resumo.pontos.count, 3)
        XCTAssertEqual(resumo.totalAtivos, 4)
        XCTAssertEqual(resumo.expiramHoje, 4)
        XCTAssertEqual(resumo.frase, "4 pontos expiram hoje")
        XCTAssertEqual(resumo.pontos.first?.lista, "Trabalho")
    }

    func testFrasesDeBase() {
        XCTAssertEqual(ResumoWidget.fraseBase(totalAtivos: 0, expiramHoje: 0), "Tudo em dia")
        XCTAssertEqual(ResumoWidget.fraseBase(totalAtivos: 5, expiramHoje: 0), "Nada urgente hoje")
        XCTAssertEqual(ResumoWidget.fraseBase(totalAtivos: 5, expiramHoje: 1), "1 ponto expira hoje")
    }

    /// O anel do widget é calculado na hora de cada entrada da timeline.
    func testAnelDoPontoEsvaziaComOTempo() throws {
        let item = try tarefas.criarItem(titulo: "A", em: trabalho)
        let ponto = try XCTUnwrap(tarefas.resumoWidget().pontos.first)

        XCTAssertEqual(ponto.id, item.id)
        XCTAssertEqual(ponto.fracao(em: relogio.agora), 1, accuracy: 0.001)
        XCTAssertEqual(ponto.fracao(em: dias(1, desde: relogio.agora)), 2.0 / 3, accuracy: 0.01)
        XCTAssertFalse(ponto.ultimoDia(em: relogio.agora))
        XCTAssertTrue(ponto.ultimoDia(em: dias(2, desde: relogio.agora).addingTimeInterval(60)))
    }

    func testResumoGravaELeNaPasta() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("resumo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        try tarefas.criarItem(titulo: "A", em: trabalho)
        let resumo = try tarefas.resumoWidget()

        try resumo.gravar(em: pasta)

        XCTAssertEqual(ResumoWidget.ler(de: pasta), resumo)
    }
}

final class BaseDadosPartilhadaTests: XCTestCase {
    /// A base de dados muda para o App Group com tudo lá dentro, e só uma vez.
    func testMudarParaOGrupoMantemOsDados() throws {
        let raiz = FileManager.default.temporaryDirectory.appendingPathComponent("mudar-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: raiz) }
        let antigo = raiz.appendingPathComponent("app/default.store")
        let novo = raiz.appendingPathComponent("grupo/ToDo.store")
        try FileManager.default.createDirectory(at: antigo.deletingLastPathComponent(), withIntermediateDirectories: true)

        do {
            let contexto = ModelContext(try BaseDados.contentor(url: antigo))
            let tarefas = Tarefas(contexto: contexto)
            let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
            try tarefas.criarItem(titulo: "Reunião", em: lista)
            try contexto.save()
        }

        XCTAssertTrue(BaseDados.mudar(de: antigo, para: novo))
        XCTAssertFalse(FileManager.default.fileExists(atPath: antigo.path))
        XCTAssertFalse(BaseDados.mudar(de: antigo, para: novo))

        let contexto = ModelContext(try BaseDados.contentor(url: novo))
        let lista = try XCTUnwrap(contexto.fetch(FetchDescriptor<Lista>()).first)
        XCTAssertEqual(lista.itens.map(\.titulo), ["Reunião"])
    }

    func testSemFicheiroAntigoNaoFazNada() {
        let raiz = FileManager.default.temporaryDirectory.appendingPathComponent("mudar-\(UUID().uuidString)")
        XCTAssertFalse(BaseDados.mudar(de: raiz.appendingPathComponent("a.store"), para: raiz.appendingPathComponent("b.store")))
    }
}
