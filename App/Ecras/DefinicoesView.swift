import SwiftData
import SwiftUI
import ToDoCore

/// Definições (especificação 4.8, mock 9): listas primeiro; depois notificações, aparência e,
/// em Avançado, os prazos. O calendário entra no M5; importar e backup no M6.
struct DefinicoesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @AppStorage("aparencia") private var aparencia = Aparencia.sistema.rawValue
    @State private var definicoes = Definicoes.carregar()
    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(listas) { lista in
                        Button {
                            formulario = .editar(lista)
                        } label: {
                            HStack(spacing: 12) {
                                IconeListaView(lista: lista, tamanho: 30)
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
                        .accessibilityHint("Personalizar a lista. Mantém premido e arrasta para ordenar.")
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
                } header: {
                    Text("Listas")
                } footer: {
                    Text("Toca numa lista para a personalizar. Mantém premido e arrasta para mudar a ordem.")
                }

                Section {
                    Toggle(isOn: $definicoes.avisosAtivos) {
                        Label {
                            Text("Avisar antes de expirar")
                        } icon: {
                            IconeDefinicao(simbolo: "bell.fill", cor: .orange)
                        }
                    }
                    if definicoes.avisosAtivos {
                        DatePicker("Hora dos avisos", selection: horaAvisos, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "pt_PT"))
                    }
                } header: {
                    Text("Notificações")
                } footer: {
                    Text("Avisa 24 horas antes de um item expirar. À noite, o aviso passa para esta hora.")
                }

                Section("Aparência") {
                    Picker("Aparência", selection: $aparencia) {
                        ForEach(Aparencia.allCases) { opcao in
                            Text(opcao.nome).tag(opcao.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Avançado") {
                    NavigationLink {
                        PrazosView(definicoes: $definicoes)
                    } label: {
                        LabeledContent {
                            Text("\(definicoes.diasExpiracao) · \(definicoes.diasManterCurto) · \(definicoes.diasManterLongo) dias")
                        } label: {
                            Label {
                                Text("Prazos")
                            } icon: {
                                IconeDefinicao(simbolo: "clock.fill", cor: .gray)
                            }
                        }
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

/// As cinco durações (especificação 9), fora do caminho principal das Definições.
struct PrazosView: View {
    @Binding var definicoes: Definicoes

    var body: some View {
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
            } footer: {
                Text("Um item sem ações expira ao fim deste tempo. Manter dá-lhe mais dias a contar de agora.")
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
                Button("Repor predefinições") {
                    let avisos = definicoes.avisosAtivos
                    let hora = definicoes.horaNotificacao
                    let minuto = definicoes.minutoNotificacao
                    definicoes = Definicoes()
                    definicoes.avisosAtivos = avisos
                    definicoes.horaNotificacao = hora
                    definicoes.minutoNotificacao = minuto
                }
            }
        }
        .navigationTitle("Prazos")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rotulo(_ texto: String, dias: Int) -> some View {
        LabeledContent(texto) {
            Text(dias == 1 ? "1 dia" : "\(dias) dias")
                .monospacedDigit()
        }
    }
}

/// Ícone branco num quadrado colorido, como nos Ajustes do iOS.
struct IconeDefinicao: View {
    let simbolo: String
    let cor: Color

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(cor, in: .rect(cornerRadius: 7, style: .continuous))
    }
}
