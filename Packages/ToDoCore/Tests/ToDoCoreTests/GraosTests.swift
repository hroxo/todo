import XCTest
import SwiftData
@testable import ToDoCore

/// Os grãos (Melhoria 35): 1 por dia verde, gastam-se a desbloquear cenários, e nunca se perdem
/// nem se contam duas vezes, mesmo com o iCloud a trazer cópias de outro aparelho.
final class GraosTests: BaseTestes {
    private var lista: Lista!

    override func setUpWithError() throws {
        try super.setUpWithError()
        lista = try tarefas.criarLista(nome: "Trabalho", cor: .azul)
    }

    private func verdes(_ dias: String...) -> HistoricoDias {
        HistoricoDias(dias: dias.map { DiaHistorico(dia: $0, concluiu: true, expirou: false) })
    }

    // MARK: - Ganhar

    func testCadaDiaVerdeDaUmGrao() throws {
        try tarefas.registarGraos(de: verdes("2026-10-19", "2026-10-20"))

        XCTAssertEqual(try tarefas.saldoGraos(), 2)
    }

    func testDiasVermelhosENeutrosNaoDaoGraos() throws {
        try tarefas.registarGraos(de: HistoricoDias(dias: [
            DiaHistorico(dia: "2026-10-19", concluiu: false, expirou: true),
            DiaHistorico(dia: "2026-10-20", concluiu: false, expirou: false),
        ]))

        XCTAssertEqual(try tarefas.saldoGraos(), 0)
    }

    func testUmPontoOuMilDaoOMesmoGrao() throws {
        for n in 0..<1000 {
            tarefas.concluir(try tarefas.criarItem(titulo: "Ponto \(n)", em: lista))
        }
        try tarefas.registarGraos(de: try tarefas.historico())

        XCTAssertEqual(try tarefas.saldoGraos(), 1)
    }

    func testRegistarDuasVezesNaoDuplica() throws {
        let historico = verdes("2026-10-19", "2026-10-20")
        try tarefas.registarGraos(de: historico)
        try tarefas.registarGraos(de: historico)

        XCTAssertEqual(try tarefas.saldoGraos(), 2)
        XCTAssertEqual(try contexto.fetchCount(FetchDescriptor<DiaGanho>()), 2)
    }

    func testOGraoDeHojeFicaDepoisDeAnular() throws {
        let item = try tarefas.criarItem(titulo: "Feito", em: lista)
        tarefas.concluir(item)
        try tarefas.registarGraos(de: try tarefas.historico())
        tarefas.reabrir(item)
        try tarefas.registarGraos(de: try tarefas.historico())

        XCTAssertEqual(try tarefas.saldoGraos(), 1, "um grão ganho nunca se tira: o saldo não pode ficar negativo")
    }

    func testCopiasDoICloudNaoContamDuasVezes() throws {
        // Dois aparelhos registaram o mesmo dia antes de sincronizar.
        contexto.insert(DiaGanho(id: "2026-10-19", ganhoEm: relogio.agora))
        contexto.insert(DiaGanho(id: "2026-10-19", ganhoEm: relogio.agora))
        try tarefas.registarGraos(de: verdes("2026-10-19"))

        XCTAssertEqual(try tarefas.saldoGraos(), 1)
    }

    // MARK: - Gastar

    func testDesbloquearGastaOCusto() throws {
        try tarefas.registarGraos(de: verdes("2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18"))
        let parque = try XCTUnwrap(Cenario.catalogo.first { $0.id == .parque })

        try tarefas.desbloquear(.parque)

        XCTAssertEqual(try tarefas.saldoGraos(), 4 - parque.custo)
        XCTAssertTrue(try tarefas.cenariosDesbloqueados().contains(.parque))
    }

    func testSemGraosNaoDesbloqueia() throws {
        try tarefas.registarGraos(de: verdes("2026-10-19"))

        XCTAssertThrowsError(try tarefas.desbloquear(.montanha)) { erro in
            XCTAssertEqual(erro as? ErroTarefas, .graosInsuficientes)
        }
        XCTAssertEqual(try tarefas.saldoGraos(), 1)
        XCTAssertFalse(try tarefas.cenariosDesbloqueados().contains(.montanha))
    }

    func testDesbloquearDuasVezesSoGastaUma() throws {
        try tarefas.registarGraos(de: verdes("2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18"))
        try tarefas.desbloquear(.parque)
        let depois = try tarefas.saldoGraos()

        try tarefas.desbloquear(.parque)

        XCTAssertEqual(try tarefas.saldoGraos(), depois)
    }

    func testCompraRepetidaNoutroAparelhoSoContaUmaVez() throws {
        try tarefas.registarGraos(de: verdes("2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18"))
        contexto.insert(CenarioDesbloqueado(id: CenarioId.parque.rawValue, custo: 3, desbloqueadoEm: relogio.agora))
        contexto.insert(CenarioDesbloqueado(id: CenarioId.parque.rawValue, custo: 3, desbloqueadoEm: relogio.agora))

        XCTAssertEqual(try tarefas.saldoGraos(), 3)
    }

    func testOCustoPagoFicaMesmoQueOPrecoMude() throws {
        try tarefas.registarGraos(de: verdes("2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20"))
        // Uma compra antiga, a um preço que já não é o do catálogo.
        contexto.insert(CenarioDesbloqueado(id: CenarioId.parque.rawValue, custo: 1, desbloqueadoEm: relogio.agora))

        XCTAssertEqual(try tarefas.saldoGraos(), 3)
    }

    func testOCeuEGratisESempreDesbloqueado() throws {
        XCTAssertEqual(Cenario.catalogo.first?.id, .ceu)
        XCTAssertEqual(Cenario.catalogo.first?.custo, 0)
        XCTAssertTrue(try tarefas.cenariosDesbloqueados().contains(.ceu))
        XCTAssertEqual(try tarefas.saldoGraos(), 0)
    }

    func testCenarioDesconhecidoDeUmaVersaoFuturaNaoPartirONucleo() throws {
        try tarefas.registarGraos(de: verdes("2026-10-19", "2026-10-20"))
        contexto.insert(CenarioDesbloqueado(id: "vulcao", custo: 1, desbloqueadoEm: relogio.agora))

        XCTAssertEqual(try tarefas.saldoGraos(), 1, "o grão gasto noutra versão conta")
        XCTAssertEqual(try tarefas.cenariosDesbloqueados(), [.ceu])
    }

    func testOsPrecosSobem() {
        let custos = Cenario.catalogo.map(\.custo)
        XCTAssertEqual(custos, custos.sorted())
        XCTAssertEqual(Set(Cenario.catalogo.map(\.id)).count, Cenario.catalogo.count)
    }

    // MARK: - Escolher

    func testEscolhidoSoValeSeEstiverDesbloqueado() throws {
        XCTAssertEqual(try tarefas.cenarioAtivo(escolhido: CenarioId.praia.rawValue), .ceu)
        XCTAssertEqual(try tarefas.cenarioAtivo(escolhido: "lixo"), .ceu)
        XCTAssertEqual(try tarefas.cenarioAtivo(escolhido: nil), .ceu)

        try tarefas.registarGraos(de: verdes("2026-10-18", "2026-10-19", "2026-10-20"))
        try tarefas.desbloquear(.parque)
        XCTAssertEqual(try tarefas.cenarioAtivo(escolhido: CenarioId.parque.rawValue), .parque)
    }

    // MARK: - Backup

    func testBackupLevaGraosECenariosERestaurarJunta() throws {
        try tarefas.registarGraos(de: verdes("2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20"))
        try tarefas.desbloquear(.parque)
        let backup = try Backup.ler(try tarefas.criarBackup().dados())
        XCTAssertEqual(backup.graos?.count, 4)
        XCTAssertEqual(backup.cenarios?.map(\.id), ["parque"])

        // Aparelho novo, já com um dia de cá.
        let outro = Tarefas(contexto: ModelContext(try BaseDados.contentor(emMemoria: true)), relogio: relogio, calendario: calendario, definicoes: Definicoes())
        try outro.registarGraos(de: verdes("2026-10-21"))
        try outro.restaurar(backup)
        try outro.restaurar(backup)

        XCTAssertEqual(try outro.saldoGraos(), 5 - 3)
        XCTAssertEqual(try outro.cenariosDesbloqueados(), [.ceu, .parque])
    }

    func testBackupAntigoSemGraosRestauraSemApagar() throws {
        try tarefas.registarGraos(de: verdes("2026-10-19"))
        var backup = try tarefas.criarBackup()
        backup.graos = nil
        backup.cenarios = nil

        try tarefas.restaurar(try Backup.ler(try backup.dados()))

        XCTAssertEqual(try tarefas.saldoGraos(), 1)
    }
}

final class MigracaoV6Tests: XCTestCase {
    /// V6 → V7 (grãos e cenários): as listas, os pontos e as fotos ficam iguais, e as tabelas
    /// novas começam vazias.
    func testMigracaoV6ParaV7MantemTudo() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("migracao-v6-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let url = pasta.appendingPathComponent("ToDo.store")
        let criado = Date(timeIntervalSince1970: 1_792_573_200)
        let idItem = UUID()

        do {
            let esquema = Schema(versionedSchema: EsquemaV6.self)
            let contentor = try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url, cloudKitDatabase: .none))
            let contexto = ModelContext(contentor)
            let lista = Lista(nome: "Trabalho", cor: .azul, ordem: 0)
            lista.permanente = true
            contexto.insert(lista)
            let item = Item(id: idItem, titulo: "Relatório", tipo: .tarefa, criadoEm: criado, ordem: 0)
            contexto.insert(item)
            item.lista = lista
            let sub = Item(titulo: "Gráficos", tipo: .tarefa, criadoEm: criado, ordem: 0)
            contexto.insert(sub)
            sub.pai = item
            let foto = Foto(dados: Data([1, 2, 3]), ordem: 0, criadaEm: criado)
            contexto.insert(foto)
            foto.item = item
            try contexto.save()
        }

        let contexto = ModelContext(try BaseDados.contentor(url: url))
        let lista = try XCTUnwrap(contexto.fetch(FetchDescriptor<Lista>()).first)
        XCTAssertTrue(lista.permanente)
        let item = try XCTUnwrap(lista.itens.first)
        XCTAssertEqual(item.id, idItem)
        XCTAssertEqual(item.subtopicos.map(\.titulo), ["Gráficos"])
        XCTAssertEqual(item.fotos.first?.dados, Data([1, 2, 3]))
        XCTAssertEqual(try contexto.fetchCount(FetchDescriptor<DiaGanho>()), 0)

        contexto.insert(DiaGanho(id: "2026-11-08", ganhoEm: criado))
        try contexto.save()
        XCTAssertEqual(try contexto.fetchCount(FetchDescriptor<DiaGanho>()), 1)
    }
}
