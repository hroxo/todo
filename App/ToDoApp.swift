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
            guard Demo.ativo else { return try BaseDados.contentor() }
            if Demo.ecra == "erro-base" { throw CocoaError(.fileReadUnknown) }
            let contentor = try BaseDados.contentor(emMemoria: true)
            Demo.povoar(ModelContext(contentor))
            return contentor
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

    init() {
        // Antes de tudo, para o iOS poder entregar as ações das notificações.
        Self.notificacoes.configurar()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let erro = Self.erroBaseDados {
                    ErroBaseDadosView(erro: erro)
                } else {
                    // O céu muda com o sol de cada dia: claro de dia, escuro só à noite (DESIGN.md 7.23).
                    TimelineView(.periodic(from: .now, by: 60)) { linha in
                        let ceu = CeuDoDia(agora: Demo.agora ?? linha.date)
                        RaizView()
                            .environment(estado)
                            .environment(calendario)
                            .environment(conta)
                            .environment(\.ceu, ceu)
                            .preferredColorScheme(ceu.fase == .noite ? .dark : .light)
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
            case .active:
                manutencao()
                calendario.atualizar()
            case .background where !Demo.ativo:
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
        if url.scheme == "todo" {
            if url.host() == "captura" {
                estado.separador = .listas
                estado.mostrarCaptura = true
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

    /// Sempre que a app abre ou volta ao primeiro plano (especificação 4.2).
    @MainActor
    private func manutencao() {
        let contexto = Self.contentor.mainContext
        let tarefas = Tarefas(contexto: contexto)
        _ = try? tarefas.criarListasIniciaisSeVazio()
        _ = try? tarefas.avaliar()
        try? contexto.save()
        // Na demonstração não há avisos, mas o widget mostra os dados de exemplo.
        if Demo.ativo {
            Self.notificacoes.atualizarWidget()
        } else {
            Self.notificacoes.reagendar()
        }
    }
}
