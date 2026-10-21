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
                .preferredColorScheme(Aparencia(rawValue: aparencia)?.esquema)
                .task {
                    if !Demo.ativo { Self.notificacoes.pedirPermissao() }
                }
        }
        .modelContainer(Self.contentor)
        .onChange(of: fase) { _, nova in
            switch nova {
            case .active:
                manutencao()
                calendario.atualizar()
            case .background where !Demo.ativo: Self.notificacoes.reagendar()
            default: break
            }
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
        if !Demo.ativo { Self.notificacoes.reagendar() }
    }
}
