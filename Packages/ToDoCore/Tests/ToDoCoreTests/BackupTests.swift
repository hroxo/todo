import XCTest
import SwiftData
@testable import ToDoCore

/// Backup e restauro em JSON (especificação 8 e critério 12).
final class BackupTests: BaseTestes {
    /// Uma instalação nova: base de dados própria, com as listas iniciais, o mesmo relógio.
    private func instalacaoNova() throws -> Tarefas {
        let contexto = ModelContext(try BaseDados.contentor(emMemoria: true))
        let nova = Tarefas(contexto: contexto, relogio: relogio, calendario: calendario, definicoes: Definicoes())
        try nova.criarListasIniciaisSeVazio()
        return nova
    }

    /// Passa pelo ficheiro, como na app.
    private func viaFicheiro(_ backup: Backup) throws -> Backup {
        try Backup.ler(backup.dados())
    }

    private func povoar() throws -> (lista: Lista, item: Item) {
        try tarefas.criarListasIniciaisSeVazio()
        let trabalho = try XCTUnwrap(tarefas.listas().first { $0.nome == "Trabalho" })
        let item = try tarefas.criarItem(titulo: "Preparar demo", em: trabalho)
        let slides = try tarefas.adicionarSubtopico(titulo: "Slides", a: item)
        tarefas.alternarSubtopico(slides)
        try tarefas.adicionarSubtopico(titulo: "Ensaio", a: item)
        try tarefas.adicionarFoto(Data([1, 2, 3]), a: item)
        tarefas.definirNota(item, "Sexta às 10h")
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo, emoji: "💡")
        try tarefas.criarItem(titulo: "App de receitas", em: ideias, tipo: .notaRapida)
        return (trabalho, item)
    }

    /// Critério 12: restaurado numa instalação nova, fica tudo igual (e sem listas duplicadas).
    func testCriterio12RestauroNumaInstalacaoNova() throws {
        let (_, item) = try povoar()
        var definicoes = Definicoes()
        definicoes.diasManterLongo = 20
        tarefas.definicoes = definicoes
        let backup = try viaFicheiro(tarefas.criarBackup())
        let nova = try instalacaoNova()

        let resumo = try nova.restaurar(backup)

        XCTAssertEqual(resumo.listasNovas, 1)
        XCTAssertEqual(resumo.listasJuntas, 2)
        XCTAssertEqual(try nova.listas().map(\.nome), ["Trabalho", "Pessoal", "Ideias"])
        let trabalho = try XCTUnwrap(nova.listas().first)
        let restaurado = try XCTUnwrap(trabalho.itens.first)
        XCTAssertEqual(restaurado.id, item.id)
        XCTAssertEqual(restaurado.titulo, "Preparar demo")
        XCTAssertEqual(restaurado.nota, "Sexta às 10h")
        XCTAssertEqual(restaurado.expiraEm, item.expiraEm)
        XCTAssertEqual(restaurado.subtopicosOrdenados.map(\.titulo), ["Slides", "Ensaio"])
        XCTAssertEqual(restaurado.subtopicosFeitos, 1)
        XCTAssertEqual(restaurado.fotos.first?.dados, Data([1, 2, 3]))
        XCTAssertEqual(try nova.listas().last?.emoji, "💡")
        XCTAssertEqual(backup.definicoes.diasManterLongo, 20)
    }

    func testRestaurarDuasVezesNaoDuplica() throws {
        try povoar()
        let backup = try tarefas.criarBackup()

        let resumo = try tarefas.restaurar(backup)

        XCTAssertTrue(resumo.nadaMuda)
        XCTAssertEqual(try tarefas.itens(.ativo).count, 2)
    }

    /// Junta por id: o que mudou depois do backup não é desfeito por ele.
    func testGanhaAVersaoMaisRecente() throws {
        let (_, item) = try povoar()
        let antigo = try tarefas.criarBackup()
        avancar(horas: 1)
        try tarefas.editarTitulo(item, para: "Preparar demo final")

        try tarefas.restaurar(antigo)
        XCTAssertEqual(item.titulo, "Preparar demo final")

        let recente = try tarefas.criarBackup()
        try tarefas.editarTitulo(item, para: "Outro")
        avancar(horas: -2)
        try tarefas.restaurar(recente)
        XCTAssertEqual(item.titulo, "Outro")
    }

    func testSimularNaoMudaNada() throws {
        try povoar()
        let backup = try tarefas.criarBackup()
        let nova = try instalacaoNova()

        let resumo = try nova.restaurar(backup, aplicar: false)

        XCTAssertEqual(resumo.listasNovas, 1)
        XCTAssertEqual(resumo.itensNovos, 4)
        XCTAssertEqual(try nova.listas().count, 2)
        XCTAssertTrue(try nova.itens(.ativo).isEmpty)
    }

    func testFicheiroInvalidoOuDeVersaoFutura() throws {
        XCTAssertThrowsError(try Backup.ler(Data("não é json".utf8))) {
            XCTAssertEqual($0 as? ErroBackup, .ficheiroInvalido)
        }
        var futuro = try tarefas.criarBackup()
        futuro.versaoFormato = Backup.versaoAtual + 1
        XCTAssertThrowsError(try Backup.ler(futuro.dados())) {
            XCTAssertEqual($0 as? ErroBackup, .versaoDesconhecida)
        }
    }

    /// Um backup com dois meses: "Nada é apagado" tem de valer também na abertura seguinte.
    func testBackupAntigoNaoApagaNadaNaAberturaSeguinte() throws {
        try tarefas.criarListasIniciaisSeVazio()
        let trabalho = try XCTUnwrap(tarefas.listas().first)
        let esquecido = try tarefas.criarItem(titulo: "Esquecido", em: trabalho)
        avancar(dias: 3)
        try tarefas.avaliar()
        XCTAssertEqual(esquecido.estado, .expirado)
        try tarefas.criarItem(titulo: "Ativo", em: trabalho)
        tarefas.concluir(try tarefas.criarItem(titulo: "Feito", em: trabalho))
        let backup = try viaFicheiro(tarefas.criarBackup())

        avancar(dias: 60)
        let nova = try instalacaoNova()
        try nova.restaurar(backup)
        try nova.contexto.save()
        let resultado = try nova.avaliar()

        XCTAssertEqual(resultado.apagados, 0)
        XCTAssertEqual(try nova.itens(.ativo).map(\.titulo), ["Ativo"])
        XCTAssertEqual(try nova.itens(.ativo).first?.expiraEm, dias(3, desde: relogio.agora))
        XCTAssertEqual(try nova.itens(.expirado).map(\.titulo), ["Esquecido"])
        XCTAssertEqual(try nova.itens(.concluido).map(\.titulo), ["Feito"])

        // A retenção recomeça: depois de ela acabar, a limpeza volta a fazer o seu trabalho.
        avancar(dias: 15)
        XCTAssertEqual(try nova.avaliar().apagados, 2)
    }

    /// Restaurar duas vezes o mesmo backup antigo não muda nada na segunda.
    func testBackupAntigoRestauradoDuasVezesNaoRecomecaOPrazo() throws {
        try povoar()
        let backup = try tarefas.criarBackup()
        avancar(dias: 60)
        let nova = try instalacaoNova()
        try nova.restaurar(backup)

        avancar(dias: 1)
        XCTAssertEqual(try nova.restaurar(backup).itensAtualizados, 0)
    }

    func testListaVaziaDeUmBackupAntigoNaoSaiLogo() throws {
        let ideias = try tarefas.criarLista(nome: "Ideias", cor: .amarelo)
        try tarefas.avaliar()
        XCTAssertNotNil(ideias.vaziaDesde)
        let backup = try tarefas.criarBackup()

        avancar(dias: 60)
        let nova = try instalacaoNova()
        try nova.restaurar(backup)
        try nova.avaliar()

        XCTAssertTrue(try nova.listas().contains { $0.nome == "Ideias" })
    }

    /// Concluir, Manter e Fixar contam como alteração: senão o backup empata e perde.
    func testRestauroReconheceConcluirManterEFixar() throws {
        let (_, item) = try povoar()
        let ideia = try XCTUnwrap(tarefas.itens(.ativo).first { $0.titulo == "App de receitas" })
        let nova = try instalacaoNova()
        try nova.restaurar(tarefas.criarBackup())

        avancar(horas: 1)
        tarefas.concluir(item)
        tarefas.manter(ideia, longo: true)
        try nova.restaurar(tarefas.criarBackup())

        XCTAssertEqual(try nova.itens(.concluido).map(\.titulo), ["Preparar demo"])
        XCTAssertEqual(try nova.itens(.ativo).first { $0.id == ideia.id }?.expiraEm, ideia.expiraEm)

        avancar(horas: 1)
        tarefas.definirFixado(ideia, true)
        try nova.restaurar(tarefas.criarBackup())
        XCTAssertEqual(try nova.itens(.ativo).first { $0.id == ideia.id }?.fixado, true)
    }

    func testListasAMaisRecusamSemMudarNada() throws {
        for i in 0..<6 {
            try tarefas.criarLista(nome: "Backup \(i)", cor: .azul)
        }
        let backup = try tarefas.criarBackup()
        let nova = try instalacaoNova()
        for i in 0..<6 {
            let lista = try nova.criarLista(nome: "Local \(i)", cor: .verde)
            try nova.criarItem(titulo: "Ponto \(i)", em: lista)
        }

        for aplicar in [false, true] {
            XCTAssertThrowsError(try nova.restaurar(backup, aplicar: aplicar)) {
                XCTAssertEqual($0 as? ErroTarefas, .limiteListas)
            }
        }
        XCTAssertEqual(try nova.listas().count, 8)
        XCTAssertFalse(try nova.listas().contains { $0.nome.hasPrefix("Backup") })
    }

    /// Mudar de iPhone: as listas iniciais, vazias, dão lugar às 8 do backup.
    func testListasVaziasDaoLugarAoBackup() throws {
        for i in 0..<8 {
            let lista = try tarefas.criarLista(nome: "Espaço \(i)", cor: .azul)
            try tarefas.criarItem(titulo: "Ponto \(i)", em: lista)
        }
        let backup = try tarefas.criarBackup()
        let nova = try instalacaoNova()

        XCTAssertEqual(try nova.restaurar(backup, aplicar: false).listasVaziasRetiradas, 2)
        XCTAssertEqual(try nova.listas().count, 2)

        try nova.restaurar(backup)
        try nova.contexto.save()

        XCTAssertEqual(try nova.listas().map(\.nome).sorted(), (0..<8).map { "Espaço \($0)" })
        XCTAssertEqual(try nova.itens(.ativo).count, 8)
    }

    /// Um ficheiro não pode trazer valores que os ecrãs não deixam escolher.
    func testDefinicoesForaDosLimitesFicamNoLimite() throws {
        let lidas = try JSONDecoder().decode(
            Definicoes.self,
            from: Data(#"{"diasExpiracao":-3,"diasManterLongo":9999,"diasRetencaoExpirados":0,"diasListaVazia":0,"horaNotificacao":99,"minutoNotificacao":-1}"#.utf8)
        )
        XCTAssertEqual(lidas.diasExpiracao, 1)
        XCTAssertEqual(lidas.diasManterLongo, 90)
        XCTAssertEqual(lidas.diasRetencaoExpirados, 1)
        XCTAssertEqual(lidas.diasListaVazia, 1)
        XCTAssertEqual(lidas.horaNotificacao, 23)
        XCTAssertEqual(lidas.minutoNotificacao, 0)
        XCTAssertEqual(lidas.diasRetencaoConcluidos, 7)
    }

    func testRestaurarNaoEncurtaARetencao() {
        var atuais = Definicoes()
        atuais.diasRetencaoExpirados = 30
        atuais.diasManterLongo = 20
        var doBackup = Definicoes()
        doBackup.diasRetencaoExpirados = 14
        doBackup.diasRetencaoConcluidos = 45
        doBackup.diasManterLongo = 40

        let novas = atuais.aoRestaurar(doBackup)

        XCTAssertEqual(novas.diasRetencaoExpirados, 30)
        XCTAssertEqual(novas.diasRetencaoConcluidos, 45)
        XCTAssertEqual(novas.diasManterLongo, 40)
    }

    func testNomeDoFicheiro() {
        XCTAssertEqual(Backup.nomeFicheiro(data(2026, 10, 28, 9), calendario: calendario), "ToDo-backup-2026-10-28.json")
    }
}

final class MigracaoV5Tests: XCTestCase {
    /// V5 → V6 (pronto para o CloudKit): os dados e as relações ficam iguais.
    func testMigracaoV5ParaV6MantemTudo() throws {
        let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("migracao-v5-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }
        let url = pasta.appendingPathComponent("ToDo.store")
        let criado = Date(timeIntervalSince1970: 1_792_573_200)
        let idItem = UUID()

        do {
            let esquema = Schema(versionedSchema: EsquemaV5.self)
            let contentor = try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url))
            let contexto = ModelContext(contentor)
            let lista = EsquemaV5.Lista(nome: "Compras", corRaw: "verde", ordem: 0)
            lista.tipoRaw = "compras"
            lista.permanente = true
            contexto.insert(lista)
            let loja = EsquemaV5.Item(id: idItem, titulo: "Continente", criadoEm: criado, ordem: 0)
            contexto.insert(loja)
            loja.lista = lista
            let artigo = EsquemaV5.Item(titulo: "Leite", criadoEm: criado, ordem: 0)
            contexto.insert(artigo)
            artigo.pai = loja
            let foto = EsquemaV5.Foto(dados: Data([7, 8]), ordem: 0, criadaEm: criado)
            contexto.insert(foto)
            foto.item = loja
            try contexto.save()
        }

        let contexto = ModelContext(try BaseDados.contentor(url: url))
        let lista = try XCTUnwrap(contexto.fetch(FetchDescriptor<Lista>()).first)
        XCTAssertEqual(lista.tipo, .compras)
        XCTAssertTrue(lista.permanente)
        let loja = try XCTUnwrap(lista.itens.first)
        XCTAssertEqual(loja.id, idItem)
        XCTAssertEqual(loja.subtopicos.map(\.titulo), ["Leite"])
        XCTAssertEqual(loja.fotos.first?.dados, Data([7, 8]))
    }
}
