import SwiftUI
import ToDoCore

/// No menu "…" de uma lista: tornar permanente ou deixar de ser (DESIGN.md 7.17). Com as 4
/// permanentes ocupadas, a opção aparece desativada e diz porquê.
struct BotaoPermanente: View {
    let lista: Lista

    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        let tarefas = Tarefas(contexto: contexto)
        if lista.permanente {
            Button {
                try? tarefas.definirPermanente(lista, false)
                estado.reagendarAvisos()
            } label: {
                Label("Deixar de ser permanente", systemImage: "infinity")
            }
        } else {
            let pode = (try? tarefas.podeSerPermanente()) ?? false
            Button {
                try? tarefas.definirPermanente(lista, true)
                estado.reagendarAvisos()
            } label: {
                Label("Tornar permanente", systemImage: "infinity")
                Text(pode
                     ? "Não desaparece quando fica vazia"
                     : "Já tens \(Tarefas.maxPermanentes) listas permanentes")
            }
            .disabled(!pode)
        }
    }
}

/// "Sai hoje", "Sai amanhã" ou "Sai em 3 dias", para uma lista vazia que vai desaparecer.
enum SaidaLista {
    static func texto(_ fim: Date, agora: Date = .now, calendario: Calendar = .current) -> String {
        let dias = calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: agora),
            to: calendario.startOfDay(for: fim)
        ).day ?? 0
        switch dias {
        case ...0: return "Sai hoje"
        case 1: return "Sai amanhã"
        default: return "Sai em \(dias) dias"
        }
    }
}
