import XCTest
import SwiftData
@testable import ToDoCore

final class ExpiracaoTests: BaseTestes {
    private var lista: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    /// Critério 1: um item ativo com o prazo no passado expira quando a app abre.
    func testCriterio1ExpiraAoAbrir() throws {
        let item = try tarefas.criarItem(titulo: "Preparar demo", em: lista)
        let limite = item.expiraEm!
        avancar(dias: 3)
        avancar(horas: 1)

        let resultado = try tarefas.avaliar()

        XCTAssertEqual(resultado.expirados, 1)
        XCTAssertEqual(item.estado, .expirado)
        XCTAssertEqual(item.expiradoEm, limite)
        XCTAssertNil(item.expiraEm)
        XCTAssertTrue(lista.itensAtivos.isEmpty)
        XCTAssertEqual(try tarefas.itens(.expirado).map(\.titulo), ["Preparar demo"])
    }

    func testAntesDoPrazoNaoExpira() throws {
        let item = try tarefas.criarItem(titulo: "Preparar demo", em: lista)
        avancar(dias: 2)
        avancar(horas: 23)

        XCTAssertEqual(try tarefas.avaliar().expirados, 0)
        XCTAssertEqual(item.estado, .ativo)
    }

    /// Critério 2: Manter por toque dá mais 5 dias a contar de agora e muda o aviso.
    func testCriterio2ManterCurto() throws {
        let item = try tarefas.criarItem(titulo: "Responder ao fornecedor", em: lista)
        avancar(dias: 2)
        let avisoAntes = try tarefas.planoAvisos().first?.data

        tarefas.manter(item, longo: false)

        XCTAssertEqual(item.expiraEm, dias(5, desde: relogio.agora))
        XCTAssertEqual(item.ultimaAcaoEm, relogio.agora)
        let avisoDepois = try tarefas.planoAvisos().first?.data
        XCTAssertNotNil(avisoDepois)
        XCTAssertNotEqual(avisoAntes, avisoDepois)
    }

    /// Critério 3: arrastar para a direita dá 15 dias; para a esquerda, 5 (o gesto está na
    /// interface; aqui testa-se a regra de cada lado).
    func testCriterio3ManterLongo() throws {
        let item = try tarefas.criarItem(titulo: "Responder ao fornecedor", em: lista)
        avancar(dias: 1)

        tarefas.manter(item, longo: true)
        XCTAssertEqual(item.expiraEm, dias(15, desde: relogio.agora))

        tarefas.manter(item, longo: false)
        XCTAssertEqual(item.expiraEm, dias(5, desde: relogio.agora))
    }

    func testManterUsaAsDefinicoes() throws {
        var definicoes = Definicoes()
        definicoes.diasManterCurto = 2
        tarefas.definicoes = definicoes
        let item = try tarefas.criarItem(titulo: "Ligar", em: lista)

        tarefas.manter(item, longo: false)

        XCTAssertEqual(item.expiraEm, dias(2, desde: relogio.agora))
    }

    /// Critério 4: um item fixado nunca expira e não tem aviso.
    func testCriterio4FixadoNuncaExpira() throws {
        let item = try tarefas.criarItem(titulo: "Revisão semanal", em: lista)
        tarefas.definirFixado(item, true)
        tarefas.manter(item, longo: true)
        XCTAssertNil(item.expiraEm, "Manter não se aplica a fixados")

        avancar(dias: 60)
        XCTAssertEqual(try tarefas.avaliar().expirados, 0)
        XCTAssertEqual(item.estado, .ativo)
        XCTAssertTrue(try tarefas.planoAvisos().isEmpty)
    }

    /// Critério 7: recuperar devolve o item à lista original, ativo, com 3 dias de vida.
    func testCriterio7Recuperar() throws {
        let item = try tarefas.criarItem(titulo: "Atualizar slides", em: lista)
        let sub = try tarefas.adicionarSubtopico(titulo: "Capa", a: item)
        avancar(dias: 5)
        try tarefas.avaliar()
        XCTAssertEqual(item.estado, .expirado)

        tarefas.recuperar(item)

        XCTAssertEqual(item.estado, .ativo)
        XCTAssertNil(item.expiradoEm)
        XCTAssertEqual(item.lista, lista)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
        XCTAssertEqual(item.subtopicos, [sub], "Os subtópicos voltam com o pai")
        XCTAssertEqual(lista.itensAtivos.map(\.titulo), ["Atualizar slides"])
    }

    /// Critério 8: 10 dias sem abrir a app; tudo o que expirou está em Expirados e nada é
    /// apagado antes dos 14 dias.
    func testCriterio8SemPerdasPorAusencia() throws {
        let a = try tarefas.criarItem(titulo: "A", em: lista)
        let b = try tarefas.criarItem(titulo: "B", em: lista)
        try tarefas.adicionarSubtopico(titulo: "B1", a: b)
        let fixado = try tarefas.criarItem(titulo: "Fixado", em: lista)
        tarefas.definirFixado(fixado, true)

        avancar(dias: 10)
        let resultado = try tarefas.avaliar()
        try contexto.save()

        XCTAssertEqual(resultado.expirados, 2)
        XCTAssertEqual(resultado.apagados, 0)
        XCTAssertEqual([a.estado, b.estado], [.expirado, .expirado])
        XCTAssertEqual(try contarItens(), 4)
        // Expiraram ao fim de 3 dias; faltam 7 dos 14.
        XCTAssertEqual(tarefas.diasAteApagar(a), 7)

        // Um dia antes dos 14: ainda lá estão.
        avancar(dias: 6)
        XCTAssertEqual(try tarefas.avaliar().apagados, 0)

        // 14 dias depois de expirarem: apagados, com os subtópicos.
        avancar(dias: 1)
        XCTAssertEqual(try tarefas.avaliar().apagados, 2)
        try contexto.save()
        XCTAssertEqual(try contarItens(), 1)
    }

    func testConcluidosApagadosAoFimDe7Dias() throws {
        let item = try tarefas.criarItem(titulo: "Enviar email", em: lista)
        tarefas.concluir(item)
        XCTAssertEqual(try tarefas.itens(.concluido).map(\.titulo), ["Enviar email"])

        avancar(dias: 6)
        XCTAssertEqual(try tarefas.avaliar().apagados, 0)
        XCTAssertEqual(tarefas.diasAteApagar(item), 1)

        avancar(dias: 1)
        XCTAssertEqual(try tarefas.avaliar().apagados, 1)
    }

    func testSubtopicoConcluidoNaoEApagado() throws {
        let item = try tarefas.criarItem(titulo: "Reunião", em: lista)
        let sub = try tarefas.adicionarSubtopico(titulo: "Agenda", a: item)
        tarefas.alternarSubtopico(sub)
        tarefas.definirFixado(item, true)

        avancar(dias: 30)
        try tarefas.avaliar()

        XCTAssertEqual(item.subtopicos, [sub])
    }

    // MARK: - Notificações

    /// Critério 9 (parte do núcleo): aviso 24 horas antes de expirar.
    func testCriterio9AvisoVinteEQuatroHorasAntes() throws {
        relogio.agora = data(2026, 10, 21, 15, 30)
        let item = try tarefas.criarItem(titulo: "Preparar demo", em: lista)

        let avisos = try tarefas.planoAvisos()

        XCTAssertEqual(avisos, [Aviso(itemId: item.id, titulo: "Preparar demo", data: data(2026, 10, 23, 15, 30))])
    }

    func testAvisoNaNoitePassaParaAsNoveDoDiaSeguinte() throws {
        relogio.agora = data(2026, 10, 21, 23, 15)
        try tarefas.criarItem(titulo: "Tarde", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 24, 9, 0))
    }

    func testAvisoDeMadrugadaPassaParaAsNoveDoMesmoDia() throws {
        relogio.agora = data(2026, 10, 21, 6, 0)
        try tarefas.criarItem(titulo: "Cedo", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 9, 0))
    }

    func testAvisoUsaAHoraDasDefinicoes() throws {
        var definicoes = Definicoes()
        definicoes.horaNotificacao = 10
        definicoes.minutoNotificacao = 30
        tarefas.definicoes = definicoes
        relogio.agora = data(2026, 10, 21, 2, 0)
        try tarefas.criarItem(titulo: "Cedo", em: lista)

        XCTAssertEqual(try tarefas.planoAvisos().first?.data, data(2026, 10, 23, 10, 30))
    }

    func testAvisoJaPassadoNaoEAgendado() throws {
        try tarefas.criarItem(titulo: "Quase", em: lista)
        avancar(dias: 2)
        avancar(horas: 12)

        XCTAssertTrue(try tarefas.planoAvisos().isEmpty)
    }

    func testAvisosOrdenadosELimitados() throws {
        for n in 0..<(Tarefas.maxAvisos + 5) {
            try tarefas.criarItem(titulo: "Item \(n)", em: lista)
            avancar(horas: 1)
        }
        relogio.agora = inicio

        let avisos = try tarefas.planoAvisos()

        XCTAssertEqual(avisos.count, Tarefas.maxAvisos)
        XCTAssertEqual(avisos.map(\.data), avisos.map(\.data).sorted())
    }

    func testConcluidosEExpiradosSemAviso() throws {
        let concluido = try tarefas.criarItem(titulo: "Feito", em: lista)
        tarefas.concluir(concluido)

        XCTAssertTrue(try tarefas.planoAvisos().isEmpty)
    }

    // MARK: - Prazo (anel)

    func testPrazoDoAnel() throws {
        let item = try tarefas.criarItem(titulo: "Rever proposta", em: lista)

        var prazo = Prazo(item: item, agora: relogio.agora)!
        XCTAssertEqual(prazo.fracao, 1, accuracy: 0.001)
        XCTAssertEqual(prazo.rotuloCurto, "3 d")
        XCTAssertEqual(prazo.rotuloLongo, "Expira em 3 dias")

        avancar(dias: 1)
        prazo = Prazo(item: item, agora: relogio.agora)!
        XCTAssertEqual(prazo.fracao, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(prazo.rotuloCurto, "2 d")
        XCTAssertFalse(prazo.ultimoDia)

        avancar(horas: 30)
        prazo = Prazo(item: item, agora: relogio.agora)!
        XCTAssertTrue(prazo.ultimoDia)
        XCTAssertEqual(prazo.rotuloCurto, "Hoje")
        XCTAssertEqual(prazo.rotuloLongo, "Expira hoje")

        tarefas.manter(item, longo: true)
        prazo = Prazo(item: item, agora: relogio.agora)!
        XCTAssertEqual(prazo.fracao, 1, accuracy: 0.001)
        XCTAssertEqual(prazo.rotuloLongo, "Expira em 15 dias")
    }

    func testPrazoNuloParaFixados() throws {
        let item = try tarefas.criarItem(titulo: "Fixo", em: lista)
        tarefas.definirFixado(item, true)
        XCTAssertNil(Prazo(item: item, agora: relogio.agora))
    }

    func testFrescuraEExpiramHoje() throws {
        try tarefas.criarItem(titulo: "Velho", em: lista)
        avancar(dias: 2)
        avancar(horas: 12)
        try tarefas.criarItem(titulo: "Novo", em: lista)

        XCTAssertEqual(lista.expiramHoje(agora: relogio.agora).map(\.titulo), ["Velho"])
        XCTAssertEqual(lista.frescura(agora: relogio.agora), 0.5, accuracy: 0.001)
    }

    // MARK: - Fotos

    func testFotosContamComoAcaoEComLimite() throws {
        let item = try tarefas.criarItem(titulo: "Quadro da retro", em: lista)
        avancar(dias: 1)

        let foto = try tarefas.adicionarFoto(Data([1, 2, 3]), a: item)
        XCTAssertEqual(item.expiraEm, dias(3, desde: relogio.agora))
        XCTAssertEqual(item.resumo, "Tarefa · 1 foto")

        for _ in 1..<Tarefas.maxFotos {
            try tarefas.adicionarFoto(Data([4]), a: item)
        }
        XCTAssertThrowsError(try tarefas.adicionarFoto(Data([5]), a: item)) { erro in
            XCTAssertEqual(erro as? ErroTarefas, .limiteFotos)
        }

        tarefas.remover(foto)
        try contexto.save()
        XCTAssertEqual(item.fotos.count, Tarefas.maxFotos - 1)
    }

    func testApagarItemApagaFotos() throws {
        let item = try tarefas.criarItem(titulo: "Com foto", em: lista)
        try tarefas.adicionarFoto(Data([1]), a: item)
        try contexto.save()

        tarefas.apagar(item)
        try contexto.save()

        XCTAssertEqual(try contexto.fetchCount(FetchDescriptor<Foto>()), 0)
    }

    func testResumo() throws {
        let item = try tarefas.criarItem(titulo: "Ideia", em: lista, tipo: .notaRapida)
        XCTAssertEqual(item.resumo, "Nota rápida")
        let sub = try tarefas.adicionarSubtopico(titulo: "A", a: item)
        try tarefas.adicionarSubtopico(titulo: "B", a: item)
        tarefas.alternarSubtopico(sub)
        XCTAssertEqual(item.resumo, "1/2 subtópicos")
    }

    // MARK: - Formatos

    func testFormatos() {
        let agora = data(2026, 10, 21, 10, 0)
        XCTAssertEqual(Formatos.cabecalho(agora, calendario: calendario), "Quarta, 21 out")
        XCTAssertEqual(Formatos.momento(data(2026, 10, 20, 18, 40), agora: agora, calendario: calendario), "ontem, 18:40")
        XCTAssertEqual(Formatos.momento(data(2026, 10, 21, 8, 5), agora: agora, calendario: calendario), "hoje, 08:05")
        XCTAssertEqual(Formatos.dia(data(2026, 10, 2, 9, 0), agora: agora, calendario: calendario), "02/10")
    }

    // MARK: - Definições

    func testDefinicoesGuardadas() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "testes-\(UUID().uuidString)"))
        XCTAssertEqual(Definicoes.carregar(de: defaults), Definicoes())

        var definicoes = Definicoes()
        definicoes.diasExpiracao = 4
        definicoes.guardar(em: defaults)

        XCTAssertEqual(Definicoes.carregar(de: defaults).diasExpiracao, 4)
    }
}

/// O esquema V1 (M1) abre na versão atual sem perder dados (especificação 11).
final class MigracaoTests: XCTestCase {
    func testMigracaoV1ParaV2MantemDados() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("migracao-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let url = pasta.appendingPathComponent("ToDo.store")
        let criado = Date(timeIntervalSince1970: 1_792_573_200)

        do {
            let esquema = Schema(versionedSchema: EsquemaV1.self)
            let contentor = try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url))
            let contexto = ModelContext(contentor)
            let lista = EsquemaV1.Lista(nome: "Trabalho", corRaw: "ciano", ordem: 0)
            contexto.insert(lista)
            let item = EsquemaV1.Item(titulo: "Reunião", criadoEm: criado, ordem: 0)
            contexto.insert(item)
            item.lista = lista
            let sub = EsquemaV1.Item(titulo: "Agenda", criadoEm: criado, ordem: 0)
            contexto.insert(sub)
            sub.pai = item
            try contexto.save()
        }

        let contentor = try BaseDados.contentor(url: url)
        let contexto = ModelContext(contentor)
        let listas = try contexto.fetch(FetchDescriptor<Lista>())

        XCTAssertEqual(listas.count, 1)
        let lista = try XCTUnwrap(listas.first)
        XCTAssertEqual(lista.nome, "Trabalho")
        XCTAssertEqual(lista.cor, .turquesa)
        XCTAssertEqual(lista.icone, IconesLista.padrao)
        XCTAssertNil(lista.emoji)
        let item = try XCTUnwrap(lista.itens.first)
        XCTAssertEqual(item.titulo, "Reunião")
        XCTAssertEqual(item.criadoEm, criado)
        XCTAssertEqual(item.subtopicos.map(\.titulo), ["Agenda"])
        XCTAssertTrue(item.fotos.isEmpty)
    }
}
