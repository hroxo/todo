import SwiftData
import SwiftUI
import ToDoCore

@main
struct ToDoApp: App {
    static let contentor: ModelContainer = {
        do {
            guard Demo.ativo else { return try BaseDados.contentor() }
            let contentor = try BaseDados.contentor(emMemoria: true)
            Demo.povoar(ModelContext(contentor))
            return contentor
        } catch {
            fatalError("Não foi possível abrir a base de dados: \(error)")
        }
    }()

    static let notificacoes = Notificacoes(contentor: contentor)

    @State private var estado = EstadoApp(notificacoes: ToDoApp.notificacoes)
    @State private var calendario = Calendario(contentor: ToDoApp.contentor)
    @State private var conta = ContaApple()
    @Environment(\.scenePhase) private var fase
    @AppStorage("aparencia") private var aparencia = Aparencia.sistema.rawValue

    init() {
        // Antes de tudo, para o iOS poder entregar as ações das notificações.
        Self.notificacoes.configurar()
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(estado)
                .environment(calendario)
                .environment(conta)
                .preferredColorScheme(Aparencia(rawValue: aparencia)?.esquema)
                .task {
                    if !Demo.ativo { Self.notificacoes.pedirPermissao() }
                }
                .onOpenURL { abrirFicheiro($0) }
        }
        .modelContainer(Self.contentor)
        .onChange(of: fase) { anterior, nova in
            switch nova {
            case .active:
                if anterior == .background { estado.avisosDispensados = false }
                manutencao()
                calendario.atualizar()
            case .background where !Demo.ativo: Self.notificacoes.reagendar()
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
