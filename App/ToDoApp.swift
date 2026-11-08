import SwiftData
import SwiftUI
import ToDoCore

@main
struct ToDoApp: App {
    /// A razão por que a base de dados real não abriu, por exemplo por causa do iCloud. A app
    /// mostra-a em vez de se fechar, e nada corre até a base real voltar a abrir.
    private(set) static var erroBaseDados: String?

    static let contentor: ModelContainer = {
        do {
            #if DEBUG
            if Demo.ativo {
                if Demo.ecra == "erro-base" { throw CocoaError(.fileReadUnknown) }
                let contentor = try BaseDados.contentor(emMemoria: true)
                Demo.povoar(ModelContext(contentor))
                return contentor
            }
            #endif
            return try BaseDados.contentor()
        } catch {
            erroBaseDados = String(reflecting: error)
            // Uma base vazia, só para o resto da app poder arrancar: nunca toca no ficheiro real.
            guard let vazia = try? BaseDados.contentor(emMemoria: true) else {
                fatalError("Não foi possível abrir a base de dados: \(error)")
            }
            return vazia
        }
    }()

    static let notificacoes = Notificacoes(contentor: contentor)

    @State private var estado = EstadoApp(notificacoes: ToDoApp.notificacoes)
    @State private var calendario = Calendario(contentor: ToDoApp.contentor)
    @State private var conta = ContaApple()
    @Environment(\.scenePhase) private var fase
    @AppStorage(Aparencia.chave) private var aparencia = Aparencia.sistema
    /// Verdadeiro ao arrancar e depois de ir para segundo plano.
    @State private var vemDoFundo = true

    init() {
        // Antes de tudo, para o iOS poder entregar as ações das notificações.
        Self.notificacoes.configurar()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let erro = Self.erroBaseDados {
                    ErroBaseDadosView(erro: erro)
                        .modifier(CeuDoModo(agora: .now))
                        .preferredColorScheme(aparencia.esquema(agora: .now))
                } else {
                    // De minuto a minuto, para a saudação e o calendário; o céu segue o modo do iPhone (DESIGN.md 7.23).
                    TimelineView(.periodic(from: .now, by: 60)) { linha in
                        RaizView()
                            .environment(estado)
                            .environment(calendario)
                            .environment(conta)
                            .environment(\.agora, linha.date)
                            .modifier(CeuDoModo(agora: linha.date))
                            // Por fora do céu, para ele seguir o modo; o Reativo muda sozinho ao minuto.
                            .preferredColorScheme(aparencia.esquema(agora: linha.date))
                            // Um ponto que chega ao fim do prazo com a app aberta expira logo.
                            .onChange(of: linha.date) {
                                if fase == .active { manutencao(soSeMudou: true) }
                            }
                    }
                }
            }
                .task {
                    // Corre antes do primeiro desenho acabar: se ele bloquear, a abertura seguinte salta os eventos.
                    calendario.marcarAbertura()
                    if !Demo.ativo { Self.notificacoes.pedirPermissao() }
                }
                .onOpenURL { abrirFicheiro($0) }
        }
        .modelContainer(Self.contentor)
        .onChange(of: fase) { anterior, nova in
            // Sobre a base vazia, reagendar apagava os avisos e o widget ficava sem pontos.
            guard Self.erroBaseDados == nil else { return }
            switch nova {
            // Só ao abrir e ao voltar do segundo plano: o Centro de Controlo e os alertas também
            // passam por inativa, e não precisam de refazer os avisos todos.
            case .active where vemDoFundo:
                vemDoFundo = false
                manutencao()
                calendario.atualizar()
            case .background:
                vemDoFundo = true
                guard !Demo.ativo else { return }
                calendario.aoSairParaSegundoPlano()
                Self.notificacoes.reagendar()
            default: break
            }
        }
    }

    /// Um `.todolista` recebido por AirDrop: cria a lista ou junta-a à cópia que já existe e
    /// abre-a (DESIGN.md 7.15).
    @MainActor
    private func abrirFicheiro(_ url: URL) {
        // todo://captura: o "+" dos widgets e o controlo Nova nota (DESIGN.md 7.14).
        // todo://fecho: o Fecho do dia, do widget e da notificação (DESIGN.md 7.25).
        if url.scheme == "todo" {
            switch url.host() {
            case "captura":
                estado.separador = .listas
                estado.mostrarCaptura = true
            case "fecho":
                estado.separador = .listas
                estado.mostrarFecho = true
            default: break
            }
            return
        }
        guard url.pathExtension == ListaPartilhada.extensao else { return }
        do {
            let resultado = try PartilhaCompras.abrir(url, contexto: Self.contentor.mainContext)
            estado.separador = .listas
            estado.caminho = NavigationPath([resultado.lista])
            if !resultado.nova {
                estado.avisoPartilha = resultado.alterados == 0
                    ? "«\(resultado.lista.nome)» já estava igual."
                    : "«\(resultado.lista.nome)» atualizada com \(resultado.alterados == 1 ? "1 alteração" : "\(resultado.alterados) alterações")."
            }
        } catch ErroPartilha.versaoDesconhecida {
            estado.avisoPartilha = "Esta lista vem de uma versão mais recente da app. Atualiza a ToDo para a abrir."
        } catch ErroTarefas.limiteListas {
            estado.avisoPartilha = "Já tens \(Tarefas.maxListas) listas. Apaga uma para receber esta."
        } catch {
            estado.avisoPartilha = "Não foi possível abrir esta lista."
        }
    }

    private static let chaveListasCriadasEm = "listasIniciaisCriadasEm"
    private static let chaveListasVigiadas = "listasIniciaisVigiadas"

    /// Os primeiros espaços criam-se uma só vez por aparelho (Trabalho e Pessoal, ou os escolhidos
    /// no questionário), e os deste aparelho ficam vigiados uns dias, para o caso de o iCloud
    /// trazer os antigos (Tarefas.juntarListasIniciaisRepetidas).
    @MainActor
    static func criarListasIniciais(_ espacos: [EspacoInicial] = EspacoInicial.predefinidos) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: chaveListasCriadasEm) == nil else { return }
        let contexto = contentor.mainContext
        // Falhar aqui só deixa o Início sem listas; a abertura seguinte tenta outra vez.
        guard let novas = try? Tarefas(contexto: contexto).criarListasIniciaisSeVazio(espacos), !novas.isEmpty else { return }
        defaults.set(Date.now, forKey: chaveListasCriadasEm)
        defaults.set(novas.map(\.id.uuidString), forKey: chaveListasVigiadas)
        try? contexto.save()
    }

    /// Sempre que a app abre ou volta ao primeiro plano (especificação 4.2) e, com
    /// `soSeMudou`, de minuto a minuto: aí só refaz os avisos e o widget se algo expirou.
    @MainActor
    private func manutencao(soSeMudou: Bool = false) {
        let contexto = Self.contentor.mainContext
        let tarefas = Tarefas(contexto: contexto)
        // Numa instalação nova espera pelo questionário, que cria os espaços escolhidos.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "boasVindasVistas") { Self.criarListasIniciais() }
        var vigiadas = Set((defaults.stringArray(forKey: Self.chaveListasVigiadas) ?? []).compactMap(UUID.init(uuidString:)))
        if !vigiadas.isEmpty, let criadasEm = defaults.object(forKey: Self.chaveListasCriadasEm) as? Date,
           let tratadas = try? tarefas.juntarListasIniciaisRepetidas(criadasAqui: vigiadas, criadasEm: criadasEm),
           !tratadas.isEmpty {
            vigiadas.subtract(tratadas)
            defaults.set(vigiadas.map(\.uuidString), forKey: Self.chaveListasVigiadas)
        }
        // O histórico de dias regista-se antes de avaliar (que apaga os concluídos no fim da
        // retenção) e depois (os que acabaram de expirar). try?: o histórico não é dado do
        // utilizador e uma falha não pode travar a manutenção.
        let pasta = BaseDados.pastaPartilhada
        if let pasta { _ = try? tarefas.registarHistorico(em: pasta) }
        let mudou = (try? tarefas.avaliar()).map { $0.expirados + $0.apagados > 0 } ?? false
        if let pasta { _ = try? tarefas.registarHistorico(em: pasta) }
        try? contexto.save()
        guard mudou || !soSeMudou else { return }
        // Na demonstração não há avisos, mas o widget mostra os dados de exemplo.
        if Demo.ativo {
            Self.notificacoes.atualizarWidget()
        } else {
            Self.notificacoes.reagendar()
        }
    }
}
