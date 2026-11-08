import XCTest
import SwiftData
@testable import ToDoCore

/// O Fecho do dia (Melhoria 33): à noite, decidir os pontos que chegam ao fim. Aparece por
/// notificação, na frase do Glassy e no widget.
final class FechoDiaTests: BaseTestes {
    private var lista: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    /// Um ponto que expira à data dada (a contar da última ação, como `manter`).
    private func ponto(_ titulo: String, expiraEm limite: Date, em lista: Lista? = nil) throws -> Item {
        let item = try tarefas.criarItem(titulo: titulo, em: lista ?? self.lista)
        item.expiraEm = limite
        return item
    }

    // MARK: - Pontos em risco

    func testEmRiscoSoOsDoUltimoDiaPelaPrioridade() throws {
        let agora = data(2026, 10, 21, 21)
        relogio.agora = data(2026, 10, 21, 10)
        let tarde = try ponto("Tarde", expiraEm: data(2026, 10, 22, 18))
        let cedo = try ponto("Cedo", expiraEm: data(2026, 10, 22, 8))
        _ = try ponto("Com tempo", expiraEm: data(2026, 10, 23, 12))
        let fixado = try ponto("Fixado", expiraEm: data(2026, 10, 22, 9))
        tarefas.definirFixado(fixado, true)
        let compras = try tarefas.criarLista(nome: "Compras", cor: .verde, tipo: .compras)
        _ = try ponto("Leite", expiraEm: data(2026, 10, 22, 9), em: compras)
        let jaExpirou = try ponto("Já foi", expiraEm: data(2026, 10, 21, 20))
        _ = jaExpirou

        XCTAssertEqual(try tarefas.pontosEmRisco(em: agora).map(\.titulo), [cedo.titulo, tarde.titulo])
    }

    // MARK: - Notificação

    func testPlanoMarcaOPrimeiroFechoComPontosEmRisco() throws {
        // Criado às 10:00 de 21/10: expira a 24/10 às 10:00. Às 21:00 de 23/10 faltam 13 h.
        _ = try tarefas.criarItem(titulo: "Proposta", em: lista)

        XCTAssertEqual(try tarefas.planoFechoDia()?.data, data(2026, 10, 23, 21))
        XCTAssertEqual(try tarefas.planoFechoDia()?.pontos, 1)
    }

    func testSemPontosEmRiscoNaoHaFecho() throws {
        let fixado = try tarefas.criarItem(titulo: "Fixado", em: lista)
        tarefas.definirFixado(fixado, true)

        XCTAssertNil(try tarefas.planoFechoDia())
    }

    func testDesligadoNaoHaFecho() throws {
        _ = try tarefas.criarItem(titulo: "Proposta", em: lista)

        tarefas.definicoes.fechoDiaAtivo = false
        XCTAssertNil(try tarefas.planoFechoDia())

        tarefas.definicoes.fechoDiaAtivo = true
        tarefas.definicoes.avisosAtivos = false
        XCTAssertNil(try tarefas.planoFechoDia())
    }

    func testHoraDeHojeJaPassadaPassaAoDiaSeguinte() throws {
        relogio.agora = data(2026, 10, 23, 21, 30)
        _ = try ponto("Amanhã de manhã", expiraEm: data(2026, 10, 24, 10))
        _ = try ponto("Depois", expiraEm: data(2026, 10, 25, 9))

        let plano = try XCTUnwrap(tarefas.planoFechoDia())

        XCTAssertEqual(plano.data, data(2026, 10, 24, 21))
        XCTAssertEqual(plano.pontos, 1)
    }

    func testFechoUsaAHoraDasDefinicoes() throws {
        tarefas.definicoes.horaFechoDia = 20
        tarefas.definicoes.minutoFechoDia = 30
        _ = try tarefas.criarItem(titulo: "Proposta", em: lista)

        XCTAssertEqual(try tarefas.planoFechoDia()?.data, data(2026, 10, 23, 20, 30))
    }

    // MARK: - Definições

    func testDefinicoesDoFecho() throws {
        let base = Definicoes()
        XCTAssertTrue(base.fechoDiaAtivo)
        XCTAssertEqual(base.horaFechoDia, 21)
        XCTAssertEqual(base.minutoFechoDia, 0)

        let antigas = try JSONDecoder().decode(Definicoes.self, from: Data(#"{"diasExpiracao": 4}"#.utf8))
        XCTAssertTrue(antigas.fechoDiaAtivo)
        XCTAssertEqual(antigas.horaFechoDia, 21)

        // Nunca entre as 22:00 e as 08:00, como os outros avisos.
        let tarde = try JSONDecoder().decode(Definicoes.self, from: Data(#"{"horaFechoDia": 23}"#.utf8))
        let cedo = try JSONDecoder().decode(Definicoes.self, from: Data(#"{"horaFechoDia": 5, "fechoDiaAtivo": false}"#.utf8))
        XCTAssertEqual(tarde.horaFechoDia, 21)
        XCTAssertEqual(cedo.horaFechoDia, 8)
        XCTAssertFalse(cedo.fechoDiaAtivo)
    }

    func testHoraDoFechoEscolhidaFicaNaJanela() {
        var definicoes = Definicoes()
        definicoes.definirHoraFecho(23, 15)
        XCTAssertEqual([definicoes.horaFechoDia, definicoes.minutoFechoDia], [21, 15])
        definicoes.definirHoraFecho(6, 0)
        XCTAssertEqual(definicoes.horaFechoDia, 8)
        definicoes.definirHoraFecho(20, 30)
        XCTAssertEqual([definicoes.horaFechoDia, definicoes.minutoFechoDia], [20, 30])
    }

    // MARK: - Glassy e widget

    func testFechoPendenteSoDepoisDaHoraEComPontosEmRisco() throws {
        _ = try tarefas.criarItem(titulo: "Proposta", em: lista)

        relogio.agora = data(2026, 10, 23, 20, 59)
        XCTAssertEqual(try tarefas.fechoPendente(), 0)

        relogio.agora = data(2026, 10, 23, 21, 5)
        XCTAssertEqual(try tarefas.fechoPendente(), 1)

        tarefas.definicoes.fechoDiaAtivo = false
        XCTAssertEqual(try tarefas.fechoPendente(), 0)
    }

    func testWidgetMostraOFechoDepoisDaHora() throws {
        _ = try tarefas.criarItem(titulo: "Proposta", em: lista)
        relogio.agora = data(2026, 10, 23, 18)
        let resumo = try tarefas.resumoWidget()

        XCTAssertEqual(resumo.noMomento(data(2026, 10, 23, 20), calendario: calendario).fechoPendente(em: data(2026, 10, 23, 20), calendario: calendario), 0)
        XCTAssertEqual(resumo.noMomento(data(2026, 10, 23, 21, 10), calendario: calendario).fechoPendente(em: data(2026, 10, 23, 21, 10), calendario: calendario), 1)

        tarefas.definicoes.fechoDiaAtivo = false
        let desligado = try tarefas.resumoWidget()
        XCTAssertEqual(desligado.fechoPendente(em: data(2026, 10, 23, 21, 10), calendario: calendario), 0)
    }

    func testComOsAvisosDesligadosNaoHaConvite() throws {
        _ = try tarefas.criarItem(titulo: "Proposta", em: lista)
        relogio.agora = data(2026, 10, 23, 21, 5)
        tarefas.definicoes.avisosAtivos = false

        XCTAssertEqual(try tarefas.fechoPendente(), 0)
        XCTAssertNil(try tarefas.resumoWidget().minutosFecho)
    }

    /// "Deixar ir" não muda o ponto: sem isto, o convite voltava logo depois de fechares o dia.
    func testFechoFeitoHojeTiraOConviteAteAoDiaSeguinte() throws {
        _ = try ponto("Hoje", expiraEm: data(2026, 10, 24, 10))
        _ = try ponto("Amanhã", expiraEm: data(2026, 10, 25, 10))
        relogio.agora = data(2026, 10, 23, 21, 30)
        let feito = data(2026, 10, 23, 21, 10)

        XCTAssertEqual(try tarefas.fechoPendente(feitoEm: feito), 0)
        // Um fecho de ontem, ou feito antes da hora de hoje, não conta.
        XCTAssertEqual(try tarefas.fechoPendente(feitoEm: data(2026, 10, 22, 21, 10)), 1)
        XCTAssertEqual(try tarefas.fechoPendente(feitoEm: data(2026, 10, 23, 20)), 1)

        let resumo = try tarefas.resumoWidget(fechoFeitoEm: feito)
        XCTAssertEqual(resumo.noMomento(relogio.agora, calendario: calendario).fechoPendente(em: relogio.agora, calendario: calendario), 0)
        let amanha = data(2026, 10, 24, 21, 30)
        XCTAssertEqual(resumo.noMomento(amanha, calendario: calendario).fechoPendente(em: amanha, calendario: calendario), 1)
    }

    func testConcluirNoFechoPoeODiaVerde() throws {
        let item = try tarefas.criarItem(titulo: "Proposta", em: lista)
        relogio.agora = data(2026, 10, 23, 21, 5)
        let emRisco = try XCTUnwrap(tarefas.pontosEmRisco(em: relogio.agora).first)
        XCTAssertEqual(emRisco, item)

        tarefas.concluir(emRisco)

        XCTAssertEqual(try tarefas.historico().dia(relogio.agora, calendario: calendario)?.estado, .verde)
    }
}
