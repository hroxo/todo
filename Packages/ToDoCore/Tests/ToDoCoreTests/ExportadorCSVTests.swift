import XCTest
import SwiftData
@testable import ToDoCore

/// Melhoria 4: exportar CSV.
final class ExportadorCSVTests: BaseTestes {
    private var trabalho: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        trabalho = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    private func linhas(_ listas: [Lista]) -> [String] {
        ExportadorCSV.texto(listas, calendario: calendario)
            .components(separatedBy: "\r\n")
            .filter { !$0.isEmpty }
    }

    func testCabecalhoPelaOrdemCerta() {
        XCTAssertEqual(
            linhas([trabalho]).first,
            "lista;titulo;estado;criado_em;ultima_acao;expira_em;concluido_em;fixado;subtopicos;n_fotos"
        )
    }

    func testFicheiroComBOMEmUTF8() throws {
        _ = try tarefas.criarItem(titulo: "Ação de formação", em: trabalho)
        let dados = ExportadorCSV.dados([trabalho], calendario: calendario)
        XCTAssertEqual(Array(dados.prefix(3)), [0xEF, 0xBB, 0xBF])
        let texto = String(decoding: dados, as: UTF8.self)
        XCTAssertTrue(texto.contains("Ação de formação"))
    }

    func testLinhaCompleta() throws {
        let item = try tarefas.criarItem(titulo: "Preparar reunião", em: trabalho)
        let feito = try tarefas.adicionarSubtopico(titulo: "Agenda", a: item)
        _ = try tarefas.adicionarSubtopico(titulo: "Sala", a: item)
        tarefas.alternarSubtopico(feito)
        _ = try tarefas.adicionarFoto(Data([1, 2, 3]), a: item)

        // Criado a 21/10/2026 10:00 em Lisboa (UTC+1); expira 3 dias depois.
        XCTAssertEqual(
            linhas([trabalho])[1],
            "Trabalho;Preparar reunião;ativo;2026-10-21T10:00:00+01:00;2026-10-21T10:00:00+01:00;"
                + "2026-10-24T10:00:00+01:00;;nao;\"[x] Agenda; [ ] Sala\";1"
        )
    }

    func testConcluidoEFixado() throws {
        let fixo = try tarefas.criarItem(titulo: "Revisão semanal", em: trabalho)
        tarefas.definirFixado(fixo, true)
        let feito = try tarefas.criarItem(titulo: "Enviar relatório", em: trabalho)
        avancar(horas: 2)
        tarefas.concluir(feito)

        let resultado = linhas([trabalho])
        XCTAssertEqual(resultado[1], "Trabalho;Revisão semanal;ativo;2026-10-21T10:00:00+01:00;2026-10-21T10:00:00+01:00;;;sim;;0")
        XCTAssertEqual(resultado[2], "Trabalho;Enviar relatório;concluido;2026-10-21T10:00:00+01:00;2026-10-21T10:00:00+01:00;;2026-10-21T12:00:00+01:00;nao;;0")
    }

    func testOrdemAtivosConcluidosExpirados() throws {
        let antigo = try tarefas.criarItem(titulo: "Antigo", em: trabalho)
        avancar(dias: 4)
        try tarefas.avaliar()
        XCTAssertEqual(antigo.estado, .expirado)
        let feito = try tarefas.criarItem(titulo: "Feito", em: trabalho)
        tarefas.concluir(feito)
        _ = try tarefas.criarItem(titulo: "Ativo", em: trabalho)

        let titulos = linhas([trabalho]).dropFirst().map { $0.components(separatedBy: ";")[1] }
        XCTAssertEqual(titulos, ["Ativo", "Feito", "Antigo"])
    }

    func testVariasListasPelaOrdem() throws {
        let pessoal = try tarefas.criarLista(nome: "Pessoal", cor: .roxo)
        _ = try tarefas.criarItem(titulo: "B", em: pessoal)
        _ = try tarefas.criarItem(titulo: "A", em: trabalho)

        let listas = linhas([pessoal, trabalho]).dropFirst().map { $0.components(separatedBy: ";")[0] }
        XCTAssertEqual(listas, ["Trabalho", "Pessoal"])
    }

    // MARK: - Escaping

    func testVirgulaNaoPrecisaDeAspas() {
        XCTAssertEqual(ExportadorCSV.campo("Pão, leite e ovos"), "Pão, leite e ovos")
    }

    func testPontoEVirgulaVaiEntreAspas() {
        XCTAssertEqual(ExportadorCSV.campo("Pão; leite"), "\"Pão; leite\"")
    }

    func testAspasDobram() {
        XCTAssertEqual(ExportadorCSV.campo("Ler \"O Principezinho\""), "\"Ler \"\"O Principezinho\"\"\"")
    }

    func testQuebrasDeLinha() {
        XCTAssertEqual(ExportadorCSV.campo("linha 1\nlinha 2"), "\"linha 1\nlinha 2\"")
        XCTAssertEqual(ExportadorCSV.campo("linha 1\r\nlinha 2"), "\"linha 1\r\nlinha 2\"")
    }

    func testEmoji() throws {
        let lista = try tarefas.criarLista(nome: "Casa 🏠", cor: .verde)
        _ = try tarefas.criarItem(titulo: "Regar as plantas 🌱", em: lista)
        let dados = ExportadorCSV.dados([lista], calendario: calendario)
        let texto = String(decoding: dados.dropFirst(3), as: UTF8.self)
        XCTAssertTrue(texto.contains("Casa 🏠;Regar as plantas 🌱;ativo"))
    }

    /// Um título com tudo junto continua a ocupar uma só célula.
    func testCampoComTudoNumaSoCelula() throws {
        _ = try tarefas.criarItem(titulo: "Dizer \"olá\"; depois,\nsair 👋", em: trabalho)
        let texto = ExportadorCSV.texto([trabalho], calendario: calendario)
        XCTAssertTrue(texto.contains(";\"Dizer \"\"olá\"\"; depois,\nsair 👋\";ativo;"))
    }

    // MARK: - Nome do ficheiro

    func testNomeDoFicheiro() {
        XCTAssertEqual(ExportadorCSV.nomeFicheiro(lista: "Trabalho", data: inicio, calendario: calendario), "ToDo-Trabalho-2026-10-21.csv")
        XCTAssertEqual(ExportadorCSV.nomeFicheiro(lista: nil, data: inicio, calendario: calendario), "ToDo-tudo-2026-10-21.csv")
        XCTAssertEqual(ExportadorCSV.nomeFicheiro(lista: "Casa/Jardim", data: inicio, calendario: calendario), "ToDo-Casa-Jardim-2026-10-21.csv")
    }
}
