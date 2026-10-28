import XCTest
import SwiftData
@testable import ToDoCore

/// Listas de compras e partilha por ficheiro `.todolista` (DESIGN.md 7.15).
final class PartilhaTests: BaseTestes {
    private var compras: Lista!
    private var continente: Item!

    override func setUpWithError() throws {
        try super.setUpWithError()
        compras = try tarefas.criarLista(nome: "Compras", cor: .verde, icone: "cart.fill", tipo: .compras)
        continente = try tarefas.criarItem(titulo: "Continente", em: compras)
    }

    /// Outro iPhone: base de dados própria, o mesmo relógio.
    private func outroIPhone() throws -> Tarefas {
        let contexto = ModelContext(try BaseDados.contentor(emMemoria: true))
        return Tarefas(contexto: contexto, relogio: relogio, calendario: calendario, definicoes: Definicoes())
    }

    /// Envia por "AirDrop": passa pelo ficheiro, como na app.
    private func enviar(_ lista: Lista, de origem: Tarefas, para destino: Tarefas) throws -> ResultadoJuntar {
        let dados = try origem.paraPartilhar(lista).dados()
        return try destino.juntar(ListaPartilhada.ler(dados))
    }

    private func artigos(_ loja: Item) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: loja.subtopicosOrdenados.map { ($0.titulo, $0.estado == .concluido) })
    }

    // MARK: - Listas de compras

    func testListaDeComprasNaoExpiraNemAvisa() throws {
        let leite = try tarefas.adicionarSubtopico(titulo: "Leite", a: continente)
        tarefas.alternarSubtopico(leite)
        XCTAssertNil(continente.expiraEm)

        avancar(dias: 30)
        try tarefas.avaliar()

        XCTAssertEqual(continente.estado, .ativo)
        XCTAssertTrue(try tarefas.planoAvisos().isEmpty)
    }

    func testMoverParaListaDeComprasTiraOPrazo() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        let item = try tarefas.criarItem(titulo: "IKEA", em: trabalho)
        XCTAssertNotNil(item.expiraEm)

        tarefas.mover(item, para: compras)

        XCTAssertNil(item.expiraEm)
    }

    func testApagarNumaListaDeComprasDeixaLapide() throws {
        let peixe = try tarefas.adicionarSubtopico(titulo: "Peixe", a: continente)
        avancar(horas: 1)

        tarefas.apagar(peixe)

        XCTAssertEqual(peixe.apagadoEm, relogio.agora)
        XCTAssertTrue(continente.subtopicosOrdenados.isEmpty)
    }

    // MARK: - Partilha

    func testPartilharCriaACopiaNoOutroIPhone() throws {
        try tarefas.adicionarSubtopico(titulo: "Carne", a: continente)
        let ikea = try tarefas.criarItem(titulo: "IKEA", em: compras)
        try tarefas.adicionarSubtopico(titulo: "Candeeiro", a: ikea)
        let outro = try outroIPhone()

        let resultado = try enviar(compras, de: tarefas, para: outro)

        XCTAssertTrue(resultado.nova)
        XCTAssertEqual(resultado.lista.tipo, .compras)
        XCTAssertEqual(resultado.lista.partilhaId, compras.partilhaId)
        XCTAssertEqual(resultado.lista.itensAtivos.map(\.titulo), ["Continente", "IKEA"])
        XCTAssertEqual(resultado.lista.itensAtivos.last.map(artigos), ["Candeeiro": false])
        XCTAssertNil(resultado.lista.itensAtivos.first?.expiraEm)
    }

    /// Cada um mexe na sua cópia; depois de trocarem os ficheiros, as duas ficam iguais.
    func testJuntarCopiasComAlteracoesDosDoisLados() throws {
        let carne = try tarefas.adicionarSubtopico(titulo: "Carne", a: continente)
        try tarefas.adicionarSubtopico(titulo: "Peixe", a: continente)
        let outro = try outroIPhone()
        let copia = try enviar(compras, de: tarefas, para: outro).lista
        let continenteDela = try XCTUnwrap(copia.itensAtivos.first)

        avancar(horas: 1)
        tarefas.alternarSubtopico(carne)
        let peixeDela = try XCTUnwrap(continenteDela.subtopicos.first { $0.titulo == "Peixe" })
        outro.apagar(peixeDela)
        try outro.adicionarSubtopico(titulo: "Fruta", a: continenteDela)

        let aqui = try enviar(copia, de: outro, para: tarefas)
        try enviar(compras, de: tarefas, para: outro)

        XCTAssertFalse(aqui.nova)
        XCTAssertEqual(artigos(continente), ["Carne": true, "Fruta": false])
        XCTAssertEqual(artigos(continenteDela), ["Carne": true, "Fruta": false])
    }

    /// Uma cópia antiga não traz de volta o que foi apagado depois.
    func testCopiaAntigaNaoRessuscitaApagados() throws {
        let peixe = try tarefas.adicionarSubtopico(titulo: "Peixe", a: continente)
        let antiga = try tarefas.paraPartilhar(compras)
        avancar(horas: 1)
        tarefas.apagar(peixe)

        try tarefas.juntar(antiga)

        XCTAssertTrue(continente.subtopicosOrdenados.isEmpty)
    }

    func testSoListasDeComprasSePartilham() throws {
        let trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
        XCTAssertThrowsError(try tarefas.paraPartilhar(trabalho)) {
            XCTAssertEqual($0 as? ErroPartilha, .naoEDeCompras)
        }
    }

    func testFicheiroDeVersaoMaisRecenteERecusado() throws {
        var futura = try tarefas.paraPartilhar(compras)
        futura.versaoFormato = ListaPartilhada.versaoAtual + 1
        XCTAssertThrowsError(try ListaPartilhada.ler(futura.dados())) {
            XCTAssertEqual($0 as? ErroPartilha, .versaoDesconhecida)
        }
    }
}

final class MigracaoV4Tests: XCTestCase {
    func testMigracaoV4ParaV5MantemTudoEAsListasFicamNormais() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("migracao-v4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let url = pasta.appendingPathComponent("ToDo.store")
        let criado = Date(timeIntervalSince1970: 1_792_573_200)

        do {
            let esquema = Schema(versionedSchema: EsquemaV4.self)
            let contentor = try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url))
            let contexto = ModelContext(contentor)
            let lista = EsquemaV4.Lista(nome: "Trabalho", corRaw: "azul", ordem: 0)
            contexto.insert(lista)
            let item = EsquemaV4.Item(titulo: "Reunião", criadoEm: criado, ordem: 0)
            item.nota = "Levar o portátil"
            item.eventoId = "evento-1"
            item.expiraEm = criado.addingTimeInterval(3 * 86_400)
            contexto.insert(item)
            item.lista = lista
            try contexto.save()
        }

        let contexto = ModelContext(try BaseDados.contentor(url: url))
        let lista = try XCTUnwrap(contexto.fetch(FetchDescriptor<Lista>()).first)
        let item = try XCTUnwrap(lista.itens.first)
        XCTAssertEqual(lista.tipo, .normal)
        XCTAssertNil(lista.partilhaId)
        XCTAssertEqual(item.titulo, "Reunião")
        XCTAssertEqual(item.nota, "Levar o portátil")
        XCTAssertEqual(item.eventoId, "evento-1")
        XCTAssertEqual(item.expiraEm, criado.addingTimeInterval(3 * 86_400))
        XCTAssertNil(item.apagadoEm)
    }
}
