import XCTest
@testable import ToDoCore

/// Os próximos eventos do calendário: hoje e os 2 dias seguintes, agrupados por dia.
final class JanelaEventosTests: BaseTestes {
    private func grupos(_ inicios: [Date], agora: Date? = nil) -> [GrupoDeEventos<Date>] {
        JanelaEventos.agrupar(inicios, agora: agora ?? inicio, calendario: calendario, inicio: { $0 })
    }

    func testJanelaVaiDeHojeAoFimDoTerceiroDia() {
        let (de, ate) = JanelaEventos.intervalo(agora: inicio, calendario: calendario)
        XCTAssertEqual(de, data(2026, 10, 21, 0, 0))
        XCTAssertEqual(ate, data(2026, 10, 24, 0, 0))
    }

    func testTresDiasSempreComTitulos() {
        let g = grupos([])
        XCTAssertEqual(g.map(\.titulo), ["Hoje", "Amanhã", "Sexta-feira"])
        XCTAssertTrue(g.allSatisfy { $0.eventos.isEmpty })
    }

    func testAgrupaPorDiaEOrdenaPelaHora() {
        let g = grupos([
            data(2026, 10, 22, 9, 0), data(2026, 10, 21, 18, 0), data(2026, 10, 21, 8, 0), data(2026, 10, 23, 23, 59),
        ])
        XCTAssertEqual(g[0].eventos, [data(2026, 10, 21, 8, 0), data(2026, 10, 21, 18, 0)])
        XCTAssertEqual(g[1].eventos, [data(2026, 10, 22, 9, 0)])
        XCTAssertEqual(g[2].eventos, [data(2026, 10, 23, 23, 59)])
    }

    func testForaDaJanelaNaoEntra() {
        let g = grupos([data(2026, 10, 24, 0, 0), data(2026, 10, 30, 10, 0)])
        XCTAssertTrue(g.allSatisfy { $0.eventos.isEmpty })
    }

    /// Um evento de vários dias que começou antes de hoje (EventKit devolve-o) conta em hoje.
    func testEventoQueComecouAntesDeHojeFicaEmHoje() {
        let g = grupos([data(2026, 10, 19, 0, 0)])
        XCTAssertEqual(g[0].eventos.count, 1)
    }

    /// Depois da meia-noite a janela anda um dia.
    func testMudancaDeDia() {
        let g = grupos([data(2026, 10, 24, 10, 0)], agora: data(2026, 10, 22, 0, 5))
        XCTAssertEqual(g.map(\.titulo), ["Hoje", "Amanhã", "Sábado"])
        XCTAssertEqual(g[2].eventos.count, 1)
    }

    /// O nome do dia não depende do idioma do iPhone nem do calendário (budista, por exemplo).
    func testCalendarioBudistaEDiasDaSemana() {
        var budista = Calendar(identifier: .buddhist)
        budista.timeZone = calendario.timeZone
        let g = JanelaEventos.agrupar([Date](), agora: inicio, calendario: budista, inicio: { $0 })
        XCTAssertEqual(g.map(\.titulo), ["Hoje", "Amanhã", "Sexta-feira"])
    }

    /// A passagem para a hora de inverno (25/10/2026) não faz o dia 24 ou 25 desaparecer ou repetir.
    func testMudancaDeHora() {
        let g = grupos([], agora: data(2026, 10, 24, 12, 0))
        XCTAssertEqual(g.map(\.dia), [data(2026, 10, 24, 0, 0), data(2026, 10, 25, 0, 0), data(2026, 10, 26, 0, 0)])
    }

    // MARK: - Dias escolhidos nas Definições

    func testDefinicaoDeDiasDoCalendario() throws {
        XCTAssertEqual(Definicoes().diasCalendario, 3)
        let antigas = try JSONDecoder().decode(Definicoes.self, from: Data(#"{"diasExpiracao": 4}"#.utf8))
        XCTAssertEqual(antigas.diasCalendario, 3)
        // Fora dos limites fica no limite: 0 dias não leria sequer hoje.
        let zero = try JSONDecoder().decode(Definicoes.self, from: Data(#"{"diasCalendario": 0}"#.utf8))
        let muitos = try JSONDecoder().decode(Definicoes.self, from: Data(#"{"diasCalendario": 99}"#.utf8))
        XCTAssertEqual(zero.diasCalendario, 1)
        XCTAssertEqual(muitos.diasCalendario, 7)
    }

    func testSoHoje() {
        let g = JanelaEventos.agrupar([data(2026, 10, 22, 9, 0)], agora: inicio, dias: 1, calendario: calendario, inicio: { $0 })
        XCTAssertEqual(g.map(\.titulo), ["Hoje"])
        XCTAssertTrue(g[0].eventos.isEmpty)
        XCTAssertEqual(JanelaEventos.intervalo(agora: inicio, dias: 1, calendario: calendario).fim, data(2026, 10, 22, 0, 0))
    }

    func testSeteDias() {
        let g = JanelaEventos.agrupar([data(2026, 10, 27, 9, 0)], agora: inicio, dias: 7, calendario: calendario, inicio: { $0 })
        XCTAssertEqual(g.map(\.titulo), ["Hoje", "Amanhã", "Sexta-feira", "Sábado", "Domingo", "Segunda-feira", "Terça-feira"])
        XCTAssertEqual(g[6].eventos.count, 1)
    }
}
