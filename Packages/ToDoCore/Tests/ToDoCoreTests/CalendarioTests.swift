import XCTest
import SwiftData
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

    func testDiasNoSingularENoPlural() {
        XCTAssertEqual(Formatos.dias(1), "1 dia")
        XCTAssertEqual(Formatos.dias(14), "14 dias")
    }

    // MARK: - Melhoria 6.4: o "+" só funciona uma vez por evento

    private func ponto(_ id: String, inicio: Date, em lista: Lista) throws -> Item {
        try tarefas.criarPontoDeEvento(
            titulo: "Daily", inicio: inicio, fim: inicio.addingTimeInterval(1800),
            diaInteiro: false, detalhe: nil, eventoId: id, em: lista
        )
    }

    func testEventoJaAdicionado() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let inicio = data(2026, 10, 21, 9, 30)
        XCTAssertNil(try tarefas.pontoDeEvento(id: "evento-1", inicio: inicio))

        let item = try ponto("evento-1", inicio: inicio, em: lista)

        XCTAssertEqual(item.eventoId, "evento-1")
        XCTAssertEqual(item.eventoInicio, inicio)
        XCTAssertEqual(try tarefas.pontoDeEvento(id: "evento-1", inicio: inicio)?.id, item.id)
        XCTAssertNil(try tarefas.pontoDeEvento(id: "evento-2", inicio: inicio))
    }

    /// Cada ocorrência de um evento recorrente conta como um evento diferente.
    func testOcorrenciasDeEventoRecorrente() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let segunda = data(2026, 10, 19, 9, 30)
        let terca = data(2026, 10, 20, 9, 30)
        _ = try ponto("daily", inicio: segunda, em: lista)

        XCTAssertNotNil(try tarefas.pontoDeEvento(id: "daily", inicio: segunda))
        XCTAssertNil(try tarefas.pontoDeEvento(id: "daily", inicio: terca))

        _ = try ponto("daily", inicio: terca, em: lista)
        XCTAssertNotNil(try tarefas.pontoDeEvento(id: "daily", inicio: terca))
    }

    func testConcluidoContinuaABloquear() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let inicio = data(2026, 10, 21, 9, 30)
        let item = try ponto("evento", inicio: inicio, em: lista)
        tarefas.concluir(item)
        XCTAssertEqual(try tarefas.pontoDeEvento(id: "evento", inicio: inicio)?.id, item.id)
    }

    func testApagadoOuExpiradoPodeVoltarASerAdicionado() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let inicio = data(2026, 10, 21, 9, 30)

        let apagado = try ponto("a", inicio: inicio, em: lista)
        tarefas.apagar(apagado)
        XCTAssertNil(try tarefas.pontoDeEvento(id: "a", inicio: inicio))

        let expira = try ponto("b", inicio: inicio, em: lista)
        avancar(dias: 4)
        try tarefas.avaliar()
        XCTAssertEqual(expira.estado, .expirado)
        XCTAssertNil(try tarefas.pontoDeEvento(id: "b", inicio: inicio))
    }

    func testPontoSemEventoNaoGuardaOrigem() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarPontoDeEvento(
            titulo: "X", inicio: inicio, fim: inicio, diaInteiro: true, detalhe: nil, em: lista
        )
        XCTAssertNil(item.eventoId)
        XCTAssertNil(item.eventoInicio)
    }

    // MARK: - Melhoria 6.2: link da reunião

    func testLinkDoEventoTemPrioridade() {
        let url = URL(string: "https://exemplo.pt/reuniao")!
        XCTAssertEqual(LigacaoReuniao.encontrar(url: url, local: nil, notas: "https://zoom.us/j/1"), url)
    }

    func testLinkDeReuniaoNasNotas() {
        let notas = """
        Olá a todos, a agenda está em https://docs.exemplo.pt/agenda
        ________________
        Reunião do Microsoft Teams
        Participar: https://teams.microsoft.com/l/meetup-join/abc
        """
        XCTAssertEqual(
            LigacaoReuniao.encontrar(url: nil, local: "Sala 3", notas: notas)?.host,
            "teams.microsoft.com"
        )
    }

    func testLinkDoMeetNoLocalEPrimeiroLinkComoAlternativa() {
        XCTAssertEqual(
            LigacaoReuniao.encontrar(url: nil, local: "https://meet.google.com/abc-defg-hij", notas: nil)?.host,
            "meet.google.com"
        )
        XCTAssertEqual(
            LigacaoReuniao.encontrar(url: nil, local: nil, notas: "Ver https://exemplo.pt/x")?.host,
            "exemplo.pt"
        )
        XCTAssertNil(LigacaoReuniao.encontrar(url: nil, local: "Sala 3", notas: "Sem links"))
        XCTAssertNil(LigacaoReuniao.encontrar(url: URL(string: "mailto:a@b.pt"), local: nil, notas: nil))
    }
}

final class MigracaoV3Tests: XCTestCase {
    func testMigracaoV3ParaV4MantemDescricaoEFotos() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("migracao-v3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let url = pasta.appendingPathComponent("ToDo.store")
        let criado = Date(timeIntervalSince1970: 1_792_573_200)

        do {
            let esquema = Schema(versionedSchema: EsquemaV3.self)
            let contentor = try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url))
            let contexto = ModelContext(contentor)
            let lista = EsquemaV3.Lista(nome: "Trabalho", corRaw: "azul", ordem: 0)
            contexto.insert(lista)
            let item = EsquemaV3.Item(titulo: "Reunião", criadoEm: criado, ordem: 0)
            item.nota = "Levar o portátil"
            contexto.insert(item)
            item.lista = lista
            let foto = EsquemaV3.Foto(dados: Data([4, 5, 6]), ordem: 0, criadaEm: criado)
            contexto.insert(foto)
            foto.item = item
            try contexto.save()
        }

        let contexto = ModelContext(try BaseDados.contentor(url: url))
        let lista = try XCTUnwrap(contexto.fetch(FetchDescriptor<Lista>()).first)
        let item = try XCTUnwrap(lista.itens.first)
        XCTAssertEqual(item.titulo, "Reunião")
        XCTAssertEqual(item.nota, "Levar o portátil")
        XCTAssertEqual(item.fotos.first?.dados, Data([4, 5, 6]))
        XCTAssertNil(item.eventoId)
        XCTAssertNil(item.eventoInicio)
    }
}
