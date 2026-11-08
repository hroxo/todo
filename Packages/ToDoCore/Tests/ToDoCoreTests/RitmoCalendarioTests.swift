import XCTest
@testable import ToDoCore

/// O mês do Streak (Melhoria 35): sempre de segunda a domingo, no
/// calendário gregoriano, com os dias por vir à parte dos dias sem atividade.
final class RitmoCalendarioTests: BaseTestes {
    private let historico = HistoricoDias(dias: [
        DiaHistorico(dia: "2026-10-19", concluiu: true, expirou: false),
        DiaHistorico(dia: "2026-10-20", concluiu: false, expirou: true),
        DiaHistorico(dia: "2026-09-30", concluiu: true, expirou: false),
    ])

    func testRotulosDoVoiceOver() {
        let mes = historico.mes(de: inicio, agora: inicio, calendario: calendario)

        XCTAssertEqual(mes.dias[20].rotulo, "Hoje, Quarta, 21 out: sem atividade")
        XCTAssertEqual(mes.dias[22].rotulo, "Sexta, 23 out: por vir")
        XCTAssertEqual(mes.dias[18].rotulo, "Segunda, 19 out: concluíste pontos")
    }

    func testMesComCalendarioBudistaNoAparelho() {
        var budista = Calendar(identifier: .buddhist)
        budista.timeZone = calendario.timeZone
        let mes = historico.mes(de: inicio, agora: inicio, calendario: budista)

        XCTAssertEqual(mes.titulo, "Outubro de 2026")
        XCTAssertEqual(mes.vazios, 3)
    }

    func testMesComDomingoComoPrimeiroDiaNosAjustes() {
        var americano = calendario!
        americano.firstWeekday = 1

        XCTAssertEqual(historico.mes(de: inicio, agora: inicio, calendario: americano).vazios, 3)
    }

    // MARK: - Mês

    func testMesAlinhaOPrimeiroDiaNaSegunda() {
        // 1/10/2026 é quinta: três casas vazias (segunda, terça, quarta).
        let mes = historico.mes(de: inicio, agora: inicio, calendario: calendario)

        XCTAssertEqual(mes.titulo, "Outubro de 2026")
        XCTAssertEqual(mes.vazios, 3)
        XCTAssertEqual(mes.dias.count, 31)
        XCTAssertEqual(mes.dias.first?.dia.dia, "2026-10-01")
        XCTAssertEqual(mes.dias.first?.numero, 1)
        XCTAssertEqual(mes.dias.last?.dia.dia, "2026-10-31")
    }

    func testMesContaOsDiasVerdesEMarcaOFuturo() {
        let mes = historico.mes(de: inicio, agora: inicio, calendario: calendario)

        XCTAssertEqual(mes.verdes, 1)
        XCTAssertEqual(mes.dias.filter(\.futuro).count, 10)
        XCTAssertEqual(mes.dias.first { $0.hoje }?.numero, 21)
    }

    func testFevereiroDeAnoBissexto() {
        let fevereiro = data(2028, 2, 10, 12)
        let mes = historico.mes(de: fevereiro, agora: fevereiro, calendario: calendario)

        XCTAssertEqual(mes.dias.count, 29)
        // 1/2/2028 é terça.
        XCTAssertEqual(mes.vazios, 1)
    }

    func testNavegaAteAoPrimeiroMesComRegistoESemFuturo() throws {
        let outubro = historico.mes(de: inicio, agora: inicio, calendario: calendario)
        XCTAssertNil(outubro.seguinte, "o mês atual não deixa ir para o futuro")
        let setembroData = try XCTUnwrap(outubro.anterior)

        let setembro = historico.mes(de: setembroData, agora: inicio, calendario: calendario)
        XCTAssertEqual(setembro.titulo, "Setembro de 2026")
        XCTAssertEqual(setembro.verdes, 1)
        XCTAssertNil(setembro.anterior, "antes do primeiro registo não há nada para ver")
        XCTAssertNotNil(setembro.seguinte)
        XCTAssertFalse(setembro.dias.contains { $0.futuro || $0.hoje })
    }

    func testSemRegistosOMesAtualNaoTemAnterior() {
        let mes = HistoricoDias().mes(de: inicio, agora: inicio, calendario: calendario)

        XCTAssertNil(mes.anterior)
        XCTAssertNil(mes.seguinte)
        XCTAssertEqual(mes.verdes, 0)
        XCTAssertTrue(mes.dias.allSatisfy { $0.dia.estado == .neutro })
    }

    func testMudarDeMesPertoDaMeiaNoite() {
        let ultimo = data(2026, 10, 31, 23, 59)
        XCTAssertEqual(historico.mes(de: ultimo, agora: ultimo, calendario: calendario).titulo, "Outubro de 2026")
        let primeiro = data(2026, 11, 1, 0, 0)
        let novembro = historico.mes(de: primeiro, agora: primeiro, calendario: calendario)
        XCTAssertEqual(novembro.titulo, "Novembro de 2026")
        // 1/11/2026 é domingo.
        XCTAssertEqual(novembro.vazios, 6)
    }
}
