import XCTest
import SwiftData
@testable import ToDoCore

final class NotasTests: BaseTestes {
    /// Critério 13: descrição curta no item; fica guardada e o item ganha mais 3 dias.
    /// Os subtópicos não têm descrição.
    func testCriterio13DescricaoDoItem() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarItem(titulo: "Rever proposta", em: lista)
        let sub = try tarefas.adicionarSubtopico(titulo: "Comparar com o OKR", a: item)
        avancar(dias: 2)

        tarefas.definirNota(item, "  Focar nas dependências.\nO Pedro quer resposta até sexta.  ")
        XCTAssertEqual(item.nota, "Focar nas dependências.\nO Pedro quer resposta até sexta.")
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
        XCTAssertEqual(item.resumo, "0/1 subtópicos · descrição")

        tarefas.definirNota(sub, "Ignorada")
        XCTAssertNil(sub.nota)
        try contexto.save()

        let guardado = try XCTUnwrap(contexto.fetch(FetchDescriptor<Item>()).first { $0.titulo == "Rever proposta" })
        XCTAssertEqual(guardado.nota, "Focar nas dependências.\nO Pedro quer resposta até sexta.")
    }

    func testDescricaoCortadaAoLimite() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarItem(titulo: "Longo", em: lista)

        tarefas.definirNota(item, String(repeating: "a", count: Tarefas.maxDescricao + 50))

        XCTAssertEqual(item.nota?.count, Tarefas.maxDescricao)
    }

    func testNotaVaziaApagaENaoMudarNaoEAcao() throws {
        let lista = try tarefas.criarLista(nome: "Pessoal", cor: .roxo)
        let item = try tarefas.criarItem(titulo: "Seguro", em: lista)
        tarefas.definirNota(item, "Apólice 123")
        let prazo = item.expiraEm
        avancar(dias: 1)

        tarefas.definirNota(item, "Apólice 123")
        XCTAssertEqual(item.expiraEm, prazo, "Sem mudança, não conta como ação")

        tarefas.definirNota(item, "   ")
        XCTAssertNil(item.nota)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
    }

    func testAvisosDesligados() throws {
        let lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        try tarefas.criarItem(titulo: "A", em: lista)
        var definicoes = Definicoes()
        definicoes.avisosAtivos = false
        tarefas.definicoes = definicoes

        XCTAssertTrue(try tarefas.planoAvisos().isEmpty)
    }

    /// Definições gravadas antes de existir `avisosAtivos` não se perdem.
    func testDefinicoesAntigasMantemValores() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "testes-\(UUID().uuidString)"))
        defaults.set(Data(#"{"diasExpiracao":4,"diasManterCurto":6}"#.utf8), forKey: "definicoes")

        let definicoes = Definicoes.carregar(de: defaults)

        XCTAssertEqual(definicoes.diasExpiracao, 4)
        XCTAssertEqual(definicoes.diasManterCurto, 6)
        XCTAssertEqual(definicoes.diasManterLongo, 15)
        XCTAssertTrue(definicoes.avisosAtivos)
    }
}

final class MigracaoV2Tests: XCTestCase {
    func testMigracaoV2ParaV3MantemDadosEFotos() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("migracao-v2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let url = pasta.appendingPathComponent("ToDo.store")
        let criado = Date(timeIntervalSince1970: 1_792_573_200)

        do {
            let esquema = Schema(versionedSchema: EsquemaV2.self)
            let contentor = try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url))
            let contexto = ModelContext(contentor)
            let lista = EsquemaV2.Lista(nome: "Pessoal", corRaw: "roxo", ordem: 0)
            lista.icone = "person.fill"
            contexto.insert(lista)
            let item = EsquemaV2.Item(titulo: "Seguro", criadoEm: criado, ordem: 0)
            contexto.insert(item)
            item.lista = lista
            let foto = EsquemaV2.Foto(dados: Data([1, 2, 3]), ordem: 0, criadaEm: criado)
            contexto.insert(foto)
            foto.item = item
            try contexto.save()
        }

        let contexto = ModelContext(try BaseDados.contentor(url: url))
        let lista = try XCTUnwrap(contexto.fetch(FetchDescriptor<Lista>()).first)
        XCTAssertEqual(lista.cor, .roxo)
        XCTAssertEqual(lista.icone, "person.fill")
        let item = try XCTUnwrap(lista.itens.first)
        XCTAssertEqual(item.titulo, "Seguro")
        XCTAssertNil(item.nota)
        XCTAssertEqual(item.fotos.first?.dados, Data([1, 2, 3]))
    }
}
