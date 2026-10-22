import EventKit
import SwiftData
import SwiftUI
import ToDoCore
import UIKit

/// Definições (especificação 4.8, mock 9): listas primeiro; depois calendário, notificações,
/// aparência e, em Avançado, os prazos e exportar tudo em CSV. Importar e backup chegam no M6.
struct DefinicoesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(EstadoApp.self) private var estado
    @Environment(Calendario.self) private var calendario
    @Environment(\.openURL) private var abrirURL
    @AppStorage("mostrarCalendario") private var mostrarCalendario = true
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @AppStorage("aparencia") private var aparencia = Aparencia.sistema.rawValue
    @State private var definicoes = Definicoes.carregar()
    @State private var formulario: PersonalizarListaView.Modo?
    @State private var aApagar: Lista?

    var body: some View {
        NavigationStack {
            EcraBaseLista(titulo: "Definições") {
                Section {
                    ForEach(listas) { lista in
                        Button {
                            formulario = .editar(lista)
                        } label: {
                            HStack(spacing: Espaco.grelha) {
                                IconeListaView(lista: lista, tamanho: 30)
                                Text(lista.nome)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(lista.itensAtivos.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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

                    if listas.count < Tarefas.maxListas {
                        Button {
                            formulario = .nova
                        } label: {
                            Label("Nova lista", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Listas")
                } footer: {
                    Text(listas.count < Tarefas.maxListas
                         ? "Toca numa lista para a personalizar. Mantém premido e arrasta para mudar a ordem."
                         : "Chegaste ao máximo de \(Tarefas.maxListas) espaços. Apaga um para criar outro.")
                }

                secaoCalendario

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
                    Button {
                        PartilhaCSV.partilhar(listas: listas)
                    } label: {
                        Label {
                            Text("Exportar tudo (CSV)")
                                .foregroundStyle(Color.primary)
                        } icon: {
                            IconeDefinicao(simbolo: "square.and.arrow.up", cor: .blue)
                        }
                    }
                }

                Section {
                } footer: {
                    Text("ToDo \(versao)")
                        .frame(maxWidth: .infinity)
                }
            }
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

    private var secaoCalendario: some View {
        Section {
            switch calendario.acesso {
            case .autorizado:
                NavigationLink {
                    CalendariosView()
                } label: {
                    LabeledContent {
                        Text(calendario.fontes)
                            .lineLimit(1)
                    } label: {
                        Label {
                            Text("Calendários")
                        } icon: {
                            IconeDefinicao(simbolo: "calendar", cor: .red)
                        }
                    }
                }
                Toggle("Mostrar eventos no Início", isOn: $mostrarCalendario)
            case .porPedir:
                Button {
                    Task {
                        await calendario.pedirAcesso()
                        mostrarCalendario = true
                    }
                } label: {
                    Label {
                        Text("Ligar calendário")
                    } icon: {
                        IconeDefinicao(simbolo: "calendar", cor: .red)
                    }
                }
            case .recusado:
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                } label: {
                    Label {
                        Text("Dar acesso em Ajustes")
                    } icon: {
                        IconeDefinicao(simbolo: "calendar", cor: .red)
                    }
                }
            }
        } header: {
            Text("Calendário")
        } footer: {
            Text("Lê os calendários das contas do iPhone (iCloud, Google, Outlook). Para juntar uma conta: Ajustes › Calendário › Contas.")
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

/// Calendários agrupados por conta, cada um com o seu espaço (mock 13).
struct CalendariosView: View {
    @Environment(Calendario.self) private var calendario
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    var body: some View {
        let contas = Dictionary(grouping: calendario.calendarios, by: { $0.source.title })
        List {
            Section {
            } footer: {
                Text("Escolhe em que espaço aparece cada calendário. \"Nenhum\" esconde-o do Início.")
            }
            ForEach(contas.keys.sorted(), id: \.self) { conta in
                Section(conta) {
                    ForEach(contas[conta] ?? [], id: \.calendarIdentifier) { item in
                        NavigationLink {
                            EscolherEspacoView(calendario: item)
                        } label: {
                            HStack(spacing: Espaco.curto) {
                                Circle()
                                    .fill(Color(cgColor: item.cgColor))
                                    .frame(width: 12, height: 12)
                                Text(item.title)
                                    .lineLimit(1)
                                Spacer()
                                rotuloEspaco(item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendários")
        .overlay {
            if calendario.calendarios.isEmpty {
                ContentUnavailableView(
                    "Sem calendários",
                    systemImage: "calendar",
                    description: Text("Junta contas em Ajustes › Calendário › Contas.")
                )
            }
        }
    }

    @ViewBuilder
    private func rotuloEspaco(_ item: EKCalendar) -> some View {
        if let id = calendario.espaco(de: item.calendarIdentifier), let lista = listas.first(where: { $0.id == id }) {
            HStack(spacing: Espaco.curto) {
                Circle().fill(lista.cor.base).frame(width: 10, height: 10)
                Text(lista.nome)
            }
            .foregroundStyle(.secondary)
        } else {
            Text("Nenhum")
                .foregroundStyle(.secondary)
        }
    }
}

/// Escolher o espaço de um calendário (mock 14).
struct EscolherEspacoView: View {
    let calendario: EKCalendar

    @Environment(Calendario.self) private var leitor
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    var body: some View {
        let atual = leitor.espaco(de: calendario.calendarIdentifier)
        List {
            Section {
                ForEach(listas) { lista in
                    Button {
                        escolher(lista.id)
                    } label: {
                        HStack(spacing: Espaco.grelha) {
                            IconeListaView(lista: lista, tamanho: 30)
                            Text(lista.nome)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if atual == lista.id {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityAddTraits(atual == lista.id ? .isSelected : [])
                }
                Button {
                    escolher(nil)
                } label: {
                    HStack(spacing: Espaco.grelha) {
                        Circle()
                            .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .frame(width: 30, height: 30)
                        Text("Nenhum")
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if atual == nil {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text("Não aparece no Início")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Mostrar no espaço")
            }
        }
        .navigationTitle(calendario.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: atual)
    }

    private func escolher(_ espaco: UUID?) {
        leitor.definir(calendario.calendarIdentifier, espaco: espaco)
        dismiss()
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
