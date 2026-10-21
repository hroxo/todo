import SwiftData
import SwiftUI
import ToDoCore

@main
struct ToDoApp: App {
    let contentor: ModelContainer = {
        do {
            return try BaseDados.contentor()
        } catch {
            fatalError("Não foi possível abrir a base de dados: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            InicioView()
                // Escuro por defeito (especificação 5.4); a escolha de modo claro vem com as Definições.
                .preferredColorScheme(.dark)
        }
        .modelContainer(contentor)
    }
}
