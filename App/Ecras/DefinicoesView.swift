import EventKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ToDoCore
import UIKit

/// Definições (especificação 4.8, mock 9): listas primeiro; depois calendário, notificações,
/// aparência e, em Avançado, os prazos e exportar tudo em CSV. Em Backup, exportar e restaurar tudo em JSON (DESIGN.md 7.19).
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
    @State private var ultimoBackup = Backups.ultimoExportado
    @State private var escolherBackup = false
    @State private var porRestaurar: PorRestaurar?
    @State private var erroBackup: String?

    /// Um backup lido e o que o restauro faria, para confirmar antes.
    private struct PorRestaurar {
        let backup: Backup
        let resumo: ResumoRestauro
    }

    var body: some View {
        NavigationStack {
            EcraBaseLista(titulo: "Definições") {
                SecaoConta()

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

                Section {
                    Toggle(isOn: $definicoes.inteligenciaAtiva) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Avisos inteligentes")
                                Text(Inteligencia.estado)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            IconeDefinicao(simbolo: "sparkles", cor: .indigo)
                        }
                    }
                } header: {
                    Text("Inteligência")
                } footer: {
                    Text("O modelo da Apple escreve o texto de cada aviso a partir do que tens na app. Corre só no iPhone: nada sai do telemóvel. Sem Apple Intelligence, os avisos usam um texto simples.")
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

                secaoBackup

                #if DEBUG
                Section {
                    Button("Criar estrutura no iCloud") {
                        do {
                            try EsquemaICloud.criar()
                            erroBackup = "Estrutura criada no CloudKit (desenvolvimento). Publica-a em produção no painel do CloudKit."
                        } catch {
                            erroBackup = "Não foi possível: \(error.localizedDescription). Precisa da conta paga, do iCloud ligado e de sessão iniciada no iCloud."
                        }
                    }
                } header: {
                    Text("Programador")
                } footer: {
                    Text("Só nas compilações de desenvolvimento. Ver docs/CONTA-DEVELOPER.md.")
                }
                #endif

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
            .fileImporter(isPresented: $escolherBackup, allowedContentTypes: [.json]) { resultado in
                lerBackup(resultado)
            }
            .alert("Restaurar este backup?", isPresented: Binding(presente: $porRestaurar), presenting: porRestaurar) { escolhido in
                Button("Restaurar") { restaurar(escolhido.backup) }
                Button("Cancelar", role: .cancel) {}
            } message: { escolhido in
                Text(mensagemRestauro(escolhido))
            }
            .alert(erroBackup ?? "", isPresented: Binding(presente: $erroBackup)) {
                Button("OK", role: .cancel) {}
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


    // MARK: - Backup (DESIGN.md 7.19)

    private var secaoBackup: some View {
        Section {
            LabeledContent {
                Text(ultimoBackup.map { Formatos.momento($0, agora: .now) } ?? "Nunca")
            } label: {
                Label {
                    Text("Último backup exportado")
                } icon: {
                    IconeDefinicao(simbolo: "doc.badge.clock", cor: .teal)
                }
            }
            Button(action: exportarBackup) {
                Label {
                    Text("Exportar backup agora")
                        .foregroundStyle(Color.primary)
                } icon: {
                    IconeDefinicao(simbolo: "square.and.arrow.up", cor: .teal)
                }
            }
            Button {
                escolherBackup = true
            } label: {
                Label {
                    Text("Restaurar de um ficheiro…")
                        .foregroundStyle(Color.primary)
                } icon: {
                    IconeDefinicao(simbolo: "arrow.counterclockwise", cor: .orange)
                }
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Uma cópia de tudo num ficheiro, para guardares no iCloud Drive, em Ficheiros ou por AirDrop. Restaurar junta os dados por id, sem apagar nada. A cópia contínua vai ser a sincronização com o iCloud.")
        }
    }

    private func exportarBackup() {
        do {
            let url = try Backups.paraExportar(contexto)
            PartilhaCSV.mostrarFolha(com: url) { guardado in
                guard guardado else { return }
                Backups.marcarExportado()
                ultimoBackup = Backups.ultimoExportado
            }
        } catch {
            erroBackup = "Não foi possível criar o backup."
        }
    }

    private func lerBackup(_ resultado: Result<URL, Error>) {
        do {
            let backup = try Backups.ler(resultado.get())
            let resumo = try Tarefas(contexto: contexto).restaurar(backup, aplicar: false)
            porRestaurar = PorRestaurar(backup: backup, resumo: resumo)
        } catch ErroBackup.versaoDesconhecida {
            erroBackup = "Este backup vem de uma versão mais recente da ToDo. Atualiza a app para o restaurar."
        } catch {
            erroBackup = "Este ficheiro não é um backup da ToDo."
        }
    }

    private func mensagemRestauro(_ escolhido: PorRestaurar) -> String {
        let b = escolhido.backup
        let r = escolhido.resumo
        let origem = "Backup de \(Formatos.dia(b.criadoEm, agora: .now)), com \(b.listas.count == 1 ? "1 lista" : "\(b.listas.count) listas") e \(b.totalItens == 1 ? "1 ponto" : "\(b.totalItens) pontos")."
        guard !r.nadaMuda else { return origem + " Já tens tudo o que está nele." }
        var partes: [String] = []
        if r.listasNovas > 0 { partes.append(r.listasNovas == 1 ? "1 lista nova" : "\(r.listasNovas) listas novas") }
        if r.itensNovos > 0 { partes.append(r.itensNovos == 1 ? "1 ponto novo" : "\(r.itensNovos) pontos novos") }
        if r.itensAtualizados > 0 { partes.append(r.itensAtualizados == 1 ? "1 atualizado" : "\(r.itensAtualizados) atualizados") }
        return origem + " Entram " + partes.joined(separator: ", ") + ". Nada é apagado."
    }

    private func restaurar(_ backup: Backup) {
        do {
            try Tarefas(contexto: contexto).restaurar(backup)
            try contexto.save()
            definicoes = backup.definicoes
            estado.reagendarAvisos()
            estado.avisoPartilha = "Backup restaurado."
        } catch {
            erroBackup = "Não foi possível restaurar o backup."
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
            NavigationLink {
                ContasView()
            } label: {
                LabeledContent {
                    Text(calendario.contas.contas.keys.map(\.nome).sorted().joined(separator: ", "))
                        .lineLimit(1)
                } label: {
                    Label {
                        Text("Contas Google e Outlook")
                    } icon: {
                        IconeDefinicao(simbolo: "person.crop.circle.badge.checkmark", cor: .blue)
                    }
                }
            }
        } header: {
            Text("Calendário")
        } footer: {
            Text("Lê os calendários das contas do iPhone (iCloud, Google, Outlook). Para juntar uma conta: Ajustes › Calendário › Contas. Ou liga a conta Google ou Outlook aqui, para ver os convites com mais detalhe.")
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
        let ligadas = Dictionary(grouping: calendario.contas.calendarios, by: \.fornecedor)
        List {
            Section {
            } footer: {
                Text("Escolhe em que espaço aparece cada calendário. Os eventos sem espaço também aparecem no Início; \"Não mostrar\" esconde-os.")
            }
            ForEach(contas.keys.sorted(), id: \.self) { conta in
                Section(conta) {
                    ForEach(contas[conta] ?? [], id: \.calendarIdentifier) { item in
                        NavigationLink {
                            EscolherEspacoView(calendarioId: item.calendarIdentifier, nome: item.title)
                        } label: {
                            HStack(spacing: Espaco.curto) {
                                Circle()
                                    .fill(Color(cgColor: item.cgColor))
                                    .frame(width: 12, height: 12)
                                Text(item.title)
                                    .lineLimit(1)
                                Spacer()
                                RotuloDestino(destino: calendario.destino(de: item.calendarIdentifier), listas: listas)
                            }
                        }
                    }
                }
            }
            // Contas ligadas diretamente (Melhoria 7).
            ForEach(Fornecedor.allCases, id: \.self) { fornecedor in
                if let lista = ligadas[fornecedor], !lista.isEmpty {
                    Section(cabecalho(fornecedor)) {
                        ForEach(lista, id: \.id) { item in
                            NavigationLink {
                                EscolherEspacoView(calendarioId: item.id, nome: item.nome)
                            } label: {
                                HStack(spacing: Espaco.curto) {
                                    Circle()
                                        .fill(item.corHex.flatMap(Color.init(hex:)) ?? .accentColor)
                                        .frame(width: 12, height: 12)
                                    Text(item.nome)
                                        .lineLimit(1)
                                    Spacer()
                                    RotuloDestino(destino: calendario.destino(de: item.id), listas: listas)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendários")
        .overlay {
            if calendario.calendarios.isEmpty && calendario.contas.calendarios.isEmpty {
                ContentUnavailableView(
                    "Sem calendários",
                    systemImage: "calendar",
                    description: Text("Junta contas em Ajustes › Calendário › Contas.")
                )
            }
        }
    }
}

extension CalendariosView {
    /// "Google · hugo@gmail.com (ligada aqui)".
    fileprivate func cabecalho(_ fornecedor: Fornecedor) -> String {
        let email = calendario.contas.contas[fornecedor]?.email.map { " · \($0)" } ?? ""
        return "\(fornecedor.nome)\(email) (ligada aqui)"
    }
}

/// Contas Google e Outlook ligadas diretamente (Melhoria 7): ligar abre a página de início de
/// sessão do fornecedor; a app só lê o calendário.
struct ContasView: View {
    @Environment(Calendario.self) private var calendario
    @State private var aDesligar: Fornecedor?

    var body: some View {
        let contas = calendario.contas
        List {
            Section {
                ForEach(Fornecedor.allCases, id: \.self) { fornecedor in
                    linha(fornecedor, contas: contas)
                }
            } footer: {
                Text("A app pede só leitura do calendário. Os tokens ficam no Keychain do iPhone e não entram no backup. Ao ligar, a app passa a usar a internet para ler os eventos destas contas.")
            }

            if let erro = contas.erro {
                Section {
                    Label(erro, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(CoresEstado.expiraTinta)
                }
            }
        }
        .navigationTitle("Contas")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Desligar a conta \(aDesligar?.nome ?? "")?",
            isPresented: Binding(presente: $aDesligar),
            titleVisibility: .visible,
            presenting: aDesligar
        ) { fornecedor in
            Button("Desligar", role: .destructive) {
                withAnimation { contas.desligar(fornecedor) }
            }
        } message: { _ in
            Text("Os eventos desta conta deixam de aparecer. Os pontos já criados ficam.")
        }
    }

    @ViewBuilder
    private func linha(_ fornecedor: Fornecedor, contas: ContasCalendario) -> some View {
        HStack(spacing: Espaco.grelha) {
            IconeDefinicao(simbolo: fornecedor == .google ? "g.circle.fill" : "envelope.fill",
                           cor: fornecedor == .google ? .green : .blue)
            VStack(alignment: .leading, spacing: Espaco.minimo) {
                Text(fornecedor.nome)
                if let conta = contas.contas[fornecedor] {
                    Text(conta.email ?? "Ligada")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if ContasCalendario.configuracao(fornecedor) == nil {
                    Text("Por configurar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if contas.aLigar == fornecedor {
                ProgressView()
            } else if contas.contas[fornecedor] != nil {
                Button("Desligar", role: .destructive) { aDesligar = fornecedor }
                    .buttonStyle(.borderless)
            } else if ContasCalendario.configuracao(fornecedor) != nil {
                Button("Ligar") {
                    Task {
                        await contas.ligar(fornecedor)
                        calendario.atualizar()
                    }
                }
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
            }
        }
        .frame(minHeight: 44)
    }
}

/// "Trabalho" com o ponto da cor do espaço, "Sem espaço" ou "Não mostrar".
struct RotuloDestino: View {
    let destino: DestinoCalendario
    let listas: [Lista]

    var body: some View {
        Group {
            switch destino {
            case .espaco(let id):
                if let lista = listas.first(where: { $0.id == id }) {
                    HStack(spacing: Espaco.curto) {
                        Circle().fill(lista.cor.base).frame(width: 10, height: 10)
                        Text(lista.nome)
                    }
                }
            case .semEspaco:
                Text("Sem espaço")
            case .oculto:
                Text("Não mostrar")
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// Escolher o espaço de um calendário (mock 14): um espaço, sem espaço (os eventos aparecem
/// na mesma, com "Sem espaço") ou não mostrar.
struct EscolherEspacoView: View {
    let calendarioId: String
    let nome: String

    @Environment(Calendario.self) private var leitor
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    var body: some View {
        let atual = leitor.destino(de: calendarioId)
        List {
            Section {
                ForEach(listas) { lista in
                    linha(.espaco(lista.id), atual: atual) {
                        IconeListaView(lista: lista, tamanho: 30)
                        Text(lista.nome)
                            .foregroundStyle(Color.primary)
                    }
                }
            } header: {
                Text("Mostrar no espaço")
            }
            Section {
                linha(.semEspaco, atual: atual) {
                    Circle()
                        .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                        .frame(width: 30, height: 30)
                    Text("Sem espaço")
                        .foregroundStyle(Color.primary)
                }
                linha(.oculto, atual: atual) {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                    Text("Não mostrar no Início")
                        .foregroundStyle(Color.primary)
                }
            } footer: {
                Text("Sem espaço, os eventos aparecem no Início com \"Sem espaço\" e escolhes a lista ao criar o ponto.")
            }
        }
        .navigationTitle(nome)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: atual)
    }

    private func linha<Rotulo: View>(
        _ destino: DestinoCalendario,
        atual: DestinoCalendario,
        @ViewBuilder rotulo: () -> Rotulo
    ) -> some View {
        Button {
            leitor.definir(calendarioId, destino: destino)
            dismiss()
        } label: {
            HStack(spacing: Espaco.grelha) {
                rotulo()
                Spacer()
                if atual == destino {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityAddTraits(atual == destino ? .isSelected : [])
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
