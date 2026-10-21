import SwiftUI
import ToDoCore

@main
struct ToDoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text(Saudacao.texto)
            .font(.system(size: 48, weight: .bold, design: .rounded))
    }
}
