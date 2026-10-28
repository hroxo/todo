import SwiftUI
import ToDoCore

/// Personalizar lista (mock "Editar lista", DESIGN.md 7.8): pré-visualização, nome, cor e
/// ícone (símbolo ou emoji). OK grava; Cancelar descarta.
struct PersonalizarListaView: View {
    enum Modo: Identifiable {
        case nova
        case editar(Lista)

        var id: String {
            switch self {
            case .nova: "nova"
            case .editar(let lista): lista.id.uuidString
            }
        }
    }

    let modo: Modo

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @State private var nome = ""
    @State private var cor: CorLista = .azul
    @State private var icone = IconesLista.padrao
    @State private var emoji: String?
    @State private var separadorEmoji = false
    @State private var tipo: TipoLista = .normal

    private var podeGuardar: Bool {
        !nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Espaco.margem) {
                    // O tipo só se escolhe ao criar: uma lista de compras não expira (DESIGN.md 7.15).
                    if case .nova = modo {
                        Picker("Tipo de lista", selection: $tipo) {
                            Label("Lista", systemImage: "checklist").tag(TipoLista.normal)
                            Label("Vista partilhada", systemImage: "person.2").tag(TipoLista.compras)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: tipo) { _, novo in
                            if emoji == nil {
                                icone = novo == .compras ? "person.2.fill" : IconesLista.padrao
                            }
                        }
                    }

                    IconeListaView(cor: cor, icone: icone, emoji: emoji, tamanho: 92)
                        .shadow(color: cor.base.opacity(0.35), radius: 14, y: 8)
                        .animation(.snappy, value: cor)

                    TextField("Nome da lista", text: $nome)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.vertical, Espaco.grelha)
                        .padding(.horizontal, Espaco.bloco)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))

                    SeletorCor(selecao: $cor)
                        .padding(Espaco.grelha)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))

                    Picker("Tipo de ícone", selection: $separadorEmoji) {
                        Text("Símbolos").tag(false)
                        Text("Emoji").tag(true)
                    }
                    .pickerStyle(.segmented)

                    SeletorIcone(cor: cor, emojis: separadorEmoji, icone: $icone, emoji: $emoji)
                        .padding(Espaco.grelha)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
                }
                .padding(Espaco.margem)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .tint(cor.tinta)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: guardar)
                        .disabled(!podeGuardar)
                }
            }
            .onAppear {
                if case .editar(let lista) = modo {
                    nome = lista.nome
                    cor = lista.cor
                    icone = lista.icone
                    emoji = lista.emoji
                    separadorEmoji = lista.emoji != nil
                }
            }
        }
    }

    private var titulo: String {
        if case .editar = modo { return "Lista" }
        return "Nova lista"
    }

    private func guardar() {
        let tarefas = Tarefas(contexto: contexto)
        switch modo {
        case .nova:
            _ = try? tarefas.criarLista(nome: nome, cor: cor, icone: icone, emoji: emoji, tipo: tipo)
        case .editar(let lista):
            try? tarefas.editar(lista, nome: nome, cor: cor, icone: icone, emoji: emoji)
        }
        dismiss()
    }
}
