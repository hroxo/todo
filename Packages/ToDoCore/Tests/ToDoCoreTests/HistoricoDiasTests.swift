import XCTest
import SwiftData
@testable import ToDoCore

/// O histórico de dias (Melhoria 33): verde se concluíste um ponto, vermelho se algo expirou,
/// neutro sem nada. O dia é binário e sobrevive à limpeza de Concluídos e Expirados.
final class HistoricoDiasTests: BaseTestes {
    private var lista: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    private func estado(_ historico: HistoricoDias, em data: Date) -> EstadoDia {
        historico.dia(data, calendario: calendario)?.estado ?? .neutro
    }

    // MARK: - Cores

    func testConcluirDeixaODiaVerde() throws {
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))

        XCTAssertEqual(estado(try tarefas.historico(), em: relogio.agora), .verde)
    }

    func testExpirarDeixaODiaVermelho() throws {
        let item = try tarefas.criarItem(titulo: "Esquecido", em: lista)
        let limite = try XCTUnwrap(item.expiraEm)
        relogio.agora = limite
        try tarefas.avaliar()

        XCTAssertEqual(estado(try tarefas.historico(), em: limite), .vermelho)
    }

    func testComConcluidoEExpiradoOVerdeGanha() throws {
        let esquecido = try tarefas.criarItem(titulo: "Esquecido", em: lista)
        relogio.agora = try XCTUnwrap(esquecido.expiraEm)
        try tarefas.avaliar()
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))

        XCTAssertEqual(estado(try tarefas.historico(), em: relogio.agora), .verde)
    }

    func testDiaSemNadaFicaNeutro() throws {
        _ = try tarefas.criarItem(titulo: "Só criado", em: lista)

        XCTAssertEqual(estado(try tarefas.historico(), em: relogio.agora), .neutro)
    }

    // MARK: - Binário

    func testUmPontoOuMilDaoOMesmoDia() throws {
        let outra = try tarefas.criarLista(nome: "Pessoal", cor: .roxo)
        tarefas.concluir(try tarefas.criarItem(titulo: "Um", em: lista))
        let umSo = try tarefas.historico()

        for n in 0..<1000 {
            tarefas.concluir(try tarefas.criarItem(titulo: "Ponto \(n)", em: outra))
        }
        let mil = try tarefas.historico()

        XCTAssertEqual(umSo.dia(relogio.agora, calendario: calendario), mil.dia(relogio.agora, calendario: calendario))
        XCTAssertEqual(
            umSo.ultimos(7, ate: relogio.agora, calendario: calendario).filter { $0.estado == .verde }.count,
            mil.ultimos(7, ate: relogio.agora, calendario: calendario).filter { $0.estado == .verde }.count
        )
    }

    // MARK: - O que não conta

    func testSubtopicoComprasEApagadosNaoContam() throws {
        let pai = try tarefas.criarItem(titulo: "Pai", em: lista)
        tarefas.concluir(try tarefas.adicionarSubtopico(titulo: "Sub", a: pai))

        let compras = try tarefas.criarLista(nome: "Compras", cor: .verde, tipo: .compras)
        tarefas.concluir(try tarefas.criarItem(titulo: "Leite", em: compras))

        let apagado = try tarefas.criarItem(titulo: "Apagado", em: lista)
        tarefas.concluir(apagado)
        tarefas.apagar(apagado)

        XCTAssertEqual(estado(try tarefas.historico(), em: relogio.agora), .neutro)
    }

    // MARK: - Limpeza de Concluídos e Expirados

    func testConcluidoApagadoPelaRetencaoContinuaVerde() throws {
        tarefas.definicoes.diasRetencaoConcluidos = 1
        let dia0 = relogio.agora
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))
        var historico = try tarefas.historico()

        // Como em `manutencao()`: registar, avaliar (apaga o concluído), registar outra vez.
        avancar(dias: 2)
        historico = try tarefas.historico(juntandoA: historico)
        let (_, apagados) = try tarefas.avaliar()
        historico = try tarefas.historico(juntandoA: historico)

        XCTAssertEqual(apagados, 1)
        XCTAssertEqual(estado(historico, em: dia0), .verde)
    }

    func testRecuperarNaoApagaOVermelhoDeUmDiaPassado() throws {
        let item = try tarefas.criarItem(titulo: "Esquecido", em: lista)
        let limite = try XCTUnwrap(item.expiraEm)
        relogio.agora = limite
        try tarefas.avaliar()
        let historico = try tarefas.historico()

        avancar(dias: 1)
        tarefas.recuperar(item)

        XCTAssertEqual(estado(try tarefas.historico(juntandoA: historico), em: limite), .vermelho)
    }

    // MARK: - Juntar

    func testDiaPassadoNuncaPerdeInformacao() throws {
        let ontem = relogio.agora
        let item = try tarefas.criarItem(titulo: "Feito", em: lista)
        tarefas.concluir(item)
        let historico = try tarefas.historico()

        avancar(dias: 1)
        tarefas.reabrir(item)

        XCTAssertEqual(estado(try tarefas.historico(juntandoA: historico), em: ontem), .verde)
    }

    func testHojeRecalculaSe() throws {
        let item = try tarefas.criarItem(titulo: "Feito", em: lista)
        let antes = tarefas.concluir(item)
        let historico = try tarefas.historico()
        tarefas.anular(item, para: try XCTUnwrap(antes))

        XCTAssertEqual(estado(try tarefas.historico(juntandoA: historico), em: relogio.agora), .neutro)
    }

    func testJuntadoEOOuDosDoisLados() {
        let a = HistoricoDias(dias: [DiaHistorico(dia: "2026-10-20", concluiu: false, expirou: true)])
        let b = HistoricoDias(dias: [
            DiaHistorico(dia: "2026-10-20", concluiu: true, expirou: false),
            DiaHistorico(dia: "2026-10-19", concluiu: false, expirou: true),
        ])

        let junto = a.juntado(com: b)

        XCTAssertEqual(junto.dias, [
            DiaHistorico(dia: "2026-10-19", concluiu: false, expirou: true),
            DiaHistorico(dia: "2026-10-20", concluiu: true, expirou: true),
        ])
        XCTAssertEqual(junto.dias.last?.estado, .verde)
    }

    // MARK: - Limites

    func testMeiaNoiteMudaODia() throws {
        relogio.agora = data(2026, 10, 21, 23, 59)
        tarefas.concluir(try tarefas.criarItem(titulo: "Antes", em: lista))
        relogio.agora = data(2026, 10, 22, 0, 1)

        let historico = try tarefas.historico()

        XCTAssertEqual(estado(historico, em: data(2026, 10, 21, 12)), .verde)
        XCTAssertEqual(estado(historico, em: data(2026, 10, 22, 12)), .neutro)
    }

    func testUltimosPreencheDiasSemRegistoComNeutro() throws {
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))
        let historico = try tarefas.historico()

        let semana = historico.ultimos(7, ate: relogio.agora, calendario: calendario)
        let quinzena = historico.ultimos(15, ate: relogio.agora, calendario: calendario)

        XCTAssertEqual(semana.count, 7)
        XCTAssertEqual(quinzena.count, 15)
        XCTAssertEqual(semana.last?.estado, .verde)
        XCTAssertEqual(semana.dropLast().map(\.estado), Array(repeating: .neutro, count: 6))
        XCTAssertEqual(semana.first?.dia, "2026-10-15")
        XCTAssertEqual(quinzena.first?.dia, "2026-10-07")
    }

    func testDiaUsaOCalendarioGregoriano() throws {
        var budista = Calendar(identifier: .buddhist)
        budista.timeZone = calendario.timeZone
        tarefas = Tarefas(contexto: contexto, relogio: relogio, calendario: budista, definicoes: Definicoes())
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))

        XCTAssertEqual(try tarefas.historico().dias.map(\.dia), ["2026-10-21"])
    }

    // MARK: - Textos do widget

    func testLetraERotuloDoDia() {
        let verde = DiaHistorico(dia: "2026-10-21", concluiu: true, expirou: true)
        let vermelho = DiaHistorico(dia: "2026-10-25", concluiu: false, expirou: true)
        let neutro = DiaHistorico(dia: "2026-10-19", concluiu: false, expirou: false)

        XCTAssertEqual([verde, vermelho, neutro].map(\.letra), ["Q", "D", "S"])
        XCTAssertEqual(verde.rotulo, "Quarta, 21 out: concluíste pontos")
        XCTAssertEqual(vermelho.rotulo, "Domingo, 25 out: expiraram pontos")
        XCTAssertEqual(neutro.rotulo, "Segunda, 19 out: sem atividade")
    }

    // MARK: - Ficheiro

    func testGravarELer() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))
        let historico = try tarefas.historico()

        try historico.gravar(em: pasta)

        XCTAssertEqual(HistoricoDias.ler(de: pasta), historico)
    }

    /// A ordem de `manutencao()`: registar no ficheiro, avaliar, registar outra vez.
    func testRegistarNoFicheiroAntesEDepoisDeAvaliar() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        tarefas.definicoes.diasRetencaoConcluidos = 1
        let dia0 = relogio.agora
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: lista))
        let esquecido = try tarefas.criarItem(titulo: "Esquecido", em: lista)
        tarefas.manter(esquecido, longo: false)
        try tarefas.registarHistorico(em: pasta)

        avancar(dias: 6)
        try tarefas.registarHistorico(em: pasta)
        try tarefas.avaliar()
        try tarefas.registarHistorico(em: pasta)

        let gravado = HistoricoDias.ler(de: pasta)
        XCTAssertEqual(estado(gravado, em: dia0), .verde)
        XCTAssertEqual(estado(gravado, em: dias(5, desde: dia0)), .vermelho)
    }

    func testJuntarAoGuardadoNuncaApagaDias() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        try HistoricoDias(dias: [DiaHistorico(dia: "2026-10-02", concluiu: true, expirou: false)]).gravar(em: pasta)

        try HistoricoDias.juntarAoGuardado(HistoricoDias(dias: [DiaHistorico(dia: "2026-10-01", concluiu: false, expirou: true)]), em: pasta)

        XCTAssertEqual(HistoricoDias.ler(de: pasta).dias.map(\.dia), ["2026-10-01", "2026-10-02"])
    }

    func testFicheiroInexistenteOuEstragadoDaHistoricoVazio() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }

        XCTAssertEqual(HistoricoDias.ler(de: pasta), HistoricoDias())

        try Data("{ isto não é json".utf8).write(to: pasta.appendingPathComponent(HistoricoDias.nomeFicheiro))
        XCTAssertEqual(HistoricoDias.ler(de: pasta), HistoricoDias())
    }

    func testFicheiroDeVersaoFuturaLeSeSemPerderDias() throws {
        let json = """
        {"dias":[{"dia":"2026-10-20","concluiu":true,"expirou":false,"humor":"feliz"}],"cenario":"praia"}
        """
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        try Data(json.utf8).write(to: pasta.appendingPathComponent(HistoricoDias.nomeFicheiro))

        XCTAssertEqual(HistoricoDias.ler(de: pasta).dias, [DiaHistorico(dia: "2026-10-20", concluiu: true, expirou: false)])
    }
}
