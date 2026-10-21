import SwiftData
import SwiftUI
import ToDoCore

/// Definições (especificação 5.1, ecrã 7): prazos, hora das notificações, aparência e
/// gestão das listas. Importar CSV e backup chegam no M4.
struct DefinicoesView: View {
    @Environment(EstadoApp.self) private var estado
    @AppStorage("aparencia") private var aparencia = Aparencia.sistema.rawValue
    @State private var definicoes = Definicoes.carregar()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $definicoes.diasExpiracao, in: 1...30) {
                        rotulo("Expiram sem ações", dias: definicoes.diasExpiracao)
                    }
                    Stepper(value: $definicoes.diasManterCurto, in: 1...30) {
                        rotulo("Manter (toque)", dias: definicoes.diasManterCurto)
                    }
                    Stepper(value: $definicoes.diasManterLongo, in: 1...90) {
                        rotulo("Manter (arrastar)", dias: definicoes.diasManterLongo)
                    }
                } header: {
                    Text("Prazos")
                }

                Section {
                    Stepper(value: $definicoes.diasRetencaoExpirados, in: 1...60) {
                        rotulo("Expirados", dias: definicoes.diasRetencaoExpirados)
                    }
                    Stepper(value: $definicoes.diasRetencaoConcluidos, in: 1...60) {
                        rotulo("Concluídos", dias: definicoes.diasRetencaoConcluidos)
                    }
                } header: {
                    Text("Guardar antes de apagar")
                }

                Section {
                    DatePicker("Hora dos avisos", selection: horaAvisos, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "pt_PT"))
                } header: {
                    Text("Notificações")
                } footer: {
                    Text("Avisa 24 horas antes de um item expirar. Se o aviso calhar entre as 22:00 e as 08:00, passa para esta hora.")
                }

                Section {
                    Picker("Aparência", selection: $aparencia) {
                        ForEach(Aparencia.allCases) { opcao in
                            Text(opcao.nome).tag(opcao.rawValue)
                        }
                    }
                }

                Section {
                    NavigationLink("Gerir listas") {
                        GerirListasView()
                    }
                }

                Section {
                } footer: {
                    Text("ToDo \(versao)")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Definições")
            .onChange(of: definicoes) { _, novas in
                novas.guardar()
                estado.reagendarAvisos()
            }
        }
    }

    private func rotulo(_ texto: String, dias: Int) -> some View {
        LabeledContent(texto) {
            Text(dias == 1 ? "1 dia" : "\(dias) dias")
                .monospacedDigit()
        }
    }

    private var horaAvisos: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: definicoes.horaNotificacao,
                    minute: definicoes.minutoNotificacao,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { nova in
                let c = Calendar.current.dateComponents([.hour, .minute], from: nova)
                definicoes.horaNotificacao = c.hour ?? 9
                definicoes.minutoNotificacao = c.minute ?? 0
            }
        )
    }

    private var versao: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

/// Ordenar, personalizar e apagar listas.
struct GerirListasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?

    var body: some View {
        List {
            ForEach(listas) { lista in
                Button {
                    formulario = .editar(lista)
                } label: {
                    HStack(spacing: 12) {
                        IconeListaView(lista: lista, tamanho: 32)
                        Text(lista.nome)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text("\(lista.itensAtivos.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        aApagar = lista
                    } label: {
                        Label("Apagar", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
            .onMove { origem, destino in
                var ordenadas = listas
                ordenadas.move(fromOffsets: origem, toOffset: destino)
                Tarefas(contexto: contexto).reordenar(ordenadas)
            }

            Button {
                formulario = .nova
            } label: {
                Label("Nova lista", systemImage: "plus")
            }
        }
        .navigationTitle("Listas")
        .toolbar {
            EditButton()
        }
        .sheet(item: $formulario) { PersonalizarListaView(modo: $0) }
        .confirmationDialog(
            "Apagar a lista «\(aApagar?.nome ?? "")»?",
            isPresented: Binding(presente: $aApagar),
            titleVisibility: .visible,
            presenting: aApagar
        ) { lista in
            Button("Apagar", role: .destructive) {
                withAnimation { Tarefas(contexto: contexto).apagar(lista) }
            }
        } message: { lista in
            let n = Tarefas(contexto: contexto).contarItens(de: lista)
            Text(n == 1 ? "Apaga também 1 item." : "Apaga também \(n) itens.")
        }
    }
}
