import SwiftData
import SwiftUI
import ToDoCore

/// Arquivo (Melhoria 35, DESIGN.md 7.9 e 7.11): Concluídos e Expirados numa só página, com um
/// segmento por baixo do título. Junta os dois separadores para dar lugar aos Cenários.
struct ArquivoView: View {
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        NavigationStack {
            switch estado.secaoArquivo {
            case .concluidos: ConcluidosView()
            case .expirados: ExpiradosView()
            }
        }
    }
}

/// Concluídos | Expirados, no topo dos dois lados do Arquivo. Os Expirados mostram quantos há,
/// como o contador da barra.
struct SegmentoArquivo: View {
    @Environment(EstadoApp.self) private var estado
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]

    var body: some View {
        @Bindable var estado = estado
        let n = expirados.filter { !$0.foiApagado }.count
        Picker("Mostrar", selection: $estado.secaoArquivo.animation(.snappy)) {
            Text("Concluídos").tag(EstadoApp.SecaoArquivo.concluidos)
            Text(n > 0 ? "Expirados · \(n)" : "Expirados").tag(EstadoApp.SecaoArquivo.expirados)
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
    }
}
