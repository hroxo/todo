import XCTest
import SwiftData
@testable import ToDoCore

/// O que o questionário da primeira abertura muda: quando chega o aviso e os primeiros espaços.
final class QuestionarioTests: BaseTestes {
    private var lista: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    private func modo(_ modo: ModoAviso, hora: Int? = nil) {
        var definicoes = tarefas.definicoes
        definicoes.escolher(modo)
        if let hora { definicoes.horaNotificacao = hora }
        tarefas.definicoes = definicoes
    }

    // MARK: - Quando chega o aviso

    func testDeManhaAvisaNaVesperaAHoraEscolhida() throws {
        modo(.manha)
        relogio.agora = data(2026, 10, 21, 15, 30)
        try tarefas.criarItem(titulo: "Preparar demo", em: lista)

        // Expira a 24/10 às 15:30: o aviso é a 23/10 às 09:00.
        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 9, 0))
    }

    func testANoiteAvisaNaVesperaAsVinteEUma() throws {
        modo(.noite)
        relogio.agora = data(2026, 10, 21, 15, 30)
        try tarefas.criarItem(titulo: "Preparar demo", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 21, 0))
    }

    func testExpiraLogoDepoisDaMeiaNoiteAvisaNaVespera() throws {
        modo(.manha)
        relogio.agora = data(2026, 10, 21, 0, 30)
        try tarefas.criarItem(titulo: "Tarde", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 9, 0))
    }

    func testVesperaJaPassadaAvisaNoProprioDia() throws {
        modo(.manha)
        var definicoes = tarefas.definicoes
        definicoes.diasExpiracao = 1
        tarefas.definicoes = definicoes
        relogio.agora = data(2026, 10, 21, 10, 0)
        try tarefas.criarItem(titulo: "Curto", em: lista)

        // A véspera (21/10 às 09:00) já passou: fica para 22/10 às 09:00, antes de expirar às 10:00.
        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 22, 9, 0))
    }

    func testSemTempoParaAvisarNaoHaAviso() throws {
        modo(.manha)
        var definicoes = tarefas.definicoes
        definicoes.diasExpiracao = 1
        tarefas.definicoes = definicoes
        relogio.agora = data(2026, 10, 21, 8, 0)
        try tarefas.criarItem(titulo: "Curtíssimo", em: lista)
        relogio.agora = data(2026, 10, 22, 8, 30)

        // O prazo era 22/10 às 08:00: a véspera já passou e o próprio dia às 09:00 é depois dele.
        XCTAssertTrue(try tarefas.planoAvisos().isEmpty)
    }

    func testHoraForaDaJanelaFicaDentroDasOitoAsVinteEDuas() throws {
        modo(.noite, hora: 23)
        relogio.agora = data(2026, 10, 21, 15, 30)
        try tarefas.criarItem(titulo: "Preparar demo", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 21, 0))

        modo(.manha, hora: 6)
        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 8, 0))
    }

    func testVinteEQuatroHorasContinuaComoAntes() throws {
        modo(.vinteQuatroHoras)
        relogio.agora = data(2026, 10, 21, 15, 30)
        try tarefas.criarItem(titulo: "Preparar demo", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 15, 30))
    }

    func testListaVaziaTambemSegueOModo() throws {
        modo(.manha)
        relogio.agora = data(2026, 10, 21, 15, 30)
        let vazia = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()

        // Sai a 26/10 às 15:30 (5 dias): o aviso é na véspera às 09:00.
        let aviso = try XCTUnwrap(tarefas.planoAvisosListas().first { $0.listaId == vazia.id })
        XCTAssertEqual(aviso.data, data(2026, 10, 25, 9, 0))
    }

    func testDiaDeSaidaComOArtigoCerto() {
        XCTAssertEqual(Formatos.noDia(data(2026, 11, 12, 10), calendario: calendario), "na quinta, 12 nov")
        XCTAssertEqual(Formatos.noDia(data(2026, 11, 14, 10), calendario: calendario), "no sábado, 14 nov")
        XCTAssertEqual(Formatos.noDia(data(2026, 11, 15, 10), calendario: calendario), "no domingo, 15 nov")
    }

    // MARK: - Definições

    func testEscolherOModoPoeAHoraDele() {
        var definicoes = Definicoes()
        definicoes.horaNotificacao = 7
        definicoes.minutoNotificacao = 45

        definicoes.escolher(.noite)
        XCTAssertEqual(definicoes.modoAviso, .noite)
        XCTAssertEqual(definicoes.horaNotificacao, 21)
        XCTAssertEqual(definicoes.minutoNotificacao, 0)

        definicoes.escolher(.vinteQuatroHoras)
        XCTAssertEqual(definicoes.horaNotificacao, 9)
    }

    func testHoraDeManhaOuANoiteFicaNaJanela() {
        var definicoes = Definicoes()
        definicoes.escolher(.noite)
        definicoes.definirHora(23, 15)
        XCTAssertEqual(definicoes.resumoAvisos, "À noite, às 21:15")
        definicoes.escolher(.manha)
        definicoes.definirHora(6, 30)
        XCTAssertEqual(definicoes.resumoAvisos, "De manhã, às 08:30")
        // Nas 24 horas é a hora para onde vão os avisos de madrugada: fica como escolhida.
        definicoes.escolher(.vinteQuatroHoras)
        definicoes.definirHora(7, 0)
        XCTAssertEqual(definicoes.horaNotificacao, 7)
    }

    func testDefinicoesAntigasFicamComVinteEQuatroHoras() throws {
        let antigas = Data(#"{"diasExpiracao": 4, "horaNotificacao": 10}"#.utf8)
        let lidas = try JSONDecoder().decode(Definicoes.self, from: antigas)
        XCTAssertEqual(lidas.modoAviso, .vinteQuatroHoras)
        XCTAssertEqual(lidas.diasExpiracao, 4)

        // Um modo que esta versão não conhece (backup de uma versão futura) não estraga o resto.
        let futuras = Data(#"{"diasExpiracao": 4, "modoAviso": "almoco"}"#.utf8)
        let lidasFuturas = try JSONDecoder().decode(Definicoes.self, from: futuras)
        XCTAssertEqual(lidasFuturas.modoAviso, .vinteQuatroHoras)
        XCTAssertEqual(lidasFuturas.diasExpiracao, 4)
    }

    func testModoSobreviveAGravarELer() throws {
        var definicoes = Definicoes()
        definicoes.escolher(.manha)
        let lidas = try JSONDecoder().decode(Definicoes.self, from: JSONEncoder().encode(definicoes))
        XCTAssertEqual(lidas.modoAviso, .manha)
    }

    func testResumoDosAvisos() {
        var definicoes = Definicoes()
        XCTAssertEqual(definicoes.resumoAvisos, "24 horas antes")
        definicoes.escolher(.manha)
        XCTAssertEqual(definicoes.resumoAvisos, "De manhã, às 09:00")
        definicoes.escolher(.noite)
        definicoes.minutoNotificacao = 30
        XCTAssertEqual(definicoes.resumoAvisos, "À noite, às 21:30")
        definicoes.avisosAtivos = false
        XCTAssertEqual(definicoes.resumoAvisos, "Desligados")
    }

    // MARK: - Espaços pelo uso

    private func base() throws -> Tarefas {
        // Base vazia: o `setUp` já criou uma lista.
        let contexto = ModelContext(try BaseDados.contentor(emMemoria: true))
        return Tarefas(contexto: contexto, relogio: relogio, calendario: calendario, definicoes: Definicoes())
    }

    func testSemEscolhaFicamTrabalhoEPessoal() throws {
        let t = try base()
        let criadas = try t.criarListasIniciaisSeVazio()
        XCTAssertEqual(criadas.map(\.nome), ["Trabalho", "Pessoal"])
        XCTAssertTrue(criadas.allSatisfy(\.permanente))
    }

    func testEscolhasCriamOsEspacosComPessoalSempre() throws {
        let t = try base()
        let criadas = try t.criarListasIniciaisSeVazio([.estudos, .trabalho])
        XCTAssertEqual(try t.listas().map(\.nome), ["Trabalho", "Pessoal", "Estudos"])
        XCTAssertEqual(criadas.map(\.ordem), [0, 1, 2])
        XCTAssertTrue(criadas.allSatisfy(\.permanente))
    }

    func testSoPessoalQuandoNadaEscolhido() throws {
        let t = try base()
        XCTAssertEqual(try t.criarListasIniciaisSeVazio([]).map(\.nome), ["Pessoal"])
    }

    func testComprasEUmaVistaPartilhada() throws {
        let t = try base()
        let compras = try XCTUnwrap(t.criarListasIniciaisSeVazio([.compras]).first { $0.nome == "Compras" })
        XCTAssertTrue(compras.ehCompras)
    }

    func testComTodosSoOsQuatroPrimeirosSaoPermanentes() throws {
        let t = try base()
        let criadas = try t.criarListasIniciaisSeVazio(EspacoInicial.allCases)
        XCTAssertEqual(criadas.map(\.nome), ["Trabalho", "Pessoal", "Estudos", "Casa", "Compras"])
        XCTAssertEqual(criadas.filter(\.permanente).count, Tarefas.maxPermanentes)
        XCTAssertFalse(try XCTUnwrap(criadas.last).permanente)
    }

    func testBaseComListasNaoCriaNada() throws {
        XCTAssertTrue(try tarefas.criarListasIniciaisSeVazio([.casa]).isEmpty)
        XCTAssertEqual(try tarefas.listas().map(\.nome), ["Trabalho"])
    }

    /// Aparelho novo: o questionário cria Estudos e o iCloud traz o Estudos de outro aparelho.
    func testEstudosRepetidoPeloICloudDeixaDeSerPermanente() throws {
        let t = try base()
        let minhas = try t.criarListasIniciaisSeVazio([.estudos])
        let meuEstudos = try XCTUnwrap(minhas.first { $0.nome == "Estudos" })
        let antigo = Lista(nome: "Estudos", cor: .indigo, ordem: 9)
        antigo.permanente = true
        t.contexto.insert(antigo)

        let tratadas = try t.juntarListasIniciaisRepetidas(criadasAqui: Set(minhas.map(\.id)), criadasEm: relogio.agora)

        XCTAssertTrue(tratadas.contains(meuEstudos.id))
        XCTAssertFalse(meuEstudos.permanente)
        XCTAssertTrue(antigo.permanente)
        XCTAssertEqual(try t.listas().count, 3)
    }
}
