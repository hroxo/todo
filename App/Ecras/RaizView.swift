import SwiftData
import SwiftUI
import ToDoCore

/// Os separadores (DESIGN.md 7.1). A barra do sistema fica escondida: a nossa
/// (`BarraSeparadores`) tem o "+" da captura num círculo à parte, com Nova lista ao manter premido.
struct RaizView: View {
    @Environment(EstadoApp.self) private var estado
    @Environment(\.modelContext) private var contexto
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]
    /// O questionário completo só aparece na primeira abertura; quem já usava a app antes dele
    /// vê uma vez o convite para ajustar o ritmo e os avisos.
    @AppStorage("boasVindasVistas") private var boasVindasVistas = false
    @AppStorage("questionarioVisto") private var questionarioVisto = false
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var barraEscondida = false
    /// O cenário escolhido neste aparelho (Melhoria 35); só vale se a compra já cá estiver.
    @AppStorage("cenarioEscolhido") private var cenarioEscolhido = CenarioId.ceu.rawValue
    @Query private var compras: [CenarioDesbloqueado]

    /// Onde começa o questionário, ou nil quando não há nada a perguntar.
    private var inicioQuestionario: QuestionarioView.Passo? {
        if Demo.ativo { return estado.questionarioDemo }
        if !boasVindasVistas { return .entrada }
        return questionarioVisto ? nil : .convite
    }

    private func fecharQuestionario() {
        boasVindasVistas = true
        questionarioVisto = true
        estado.questionarioDemo = nil
        estado.reagendarAvisos()
    }

    private func abrirNovaLista() {
        // Conta na base no momento (o iCloud pode ter trazido listas). Se a leitura falhar,
        // abre o formulário, que valida.
        let existentes = (try? Tarefas(contexto: contexto).listas().count) ?? 0
        if existentes < Tarefas.maxListas {
            estado.mostrarNovaLista = true
        } else {
            estado.avisoPartilha = Tarefas.avisoLimiteListas
        }
    }

    var body: some View {
        @Bindable var estado = estado

        TabView(selection: $estado.separador) {
            Tab("Listas", systemImage: "list.bullet", value: EstadoApp.Separador.listas) {
                InicioView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Arquivo", systemImage: "archivebox", value: EstadoApp.Separador.arquivo) {
                ArquivoView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Streak", systemImage: "flame", value: EstadoApp.Separador.streak) {
                StreakView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Definições", systemImage: "gearshape", value: EstadoApp.Separador.definicoes) {
                DefinicoesView().toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .environment(\.cenario, Cenario.ativo(escolhido: cenarioEscolhido, compras: compras))
        .onPreferenceChange(BarraEscondida.self) { [$barraEscondida] in $barraEscondida.wrappedValue = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !barraEscondida {
                BarraSeparadores(
                    separador: $estado.separador,
                    expirados: expirados.count,
                    novaNota: { estado.mostrarCaptura = true },
                    novaLista: abrirNovaLista
                )
            }
        }
        .overlay {
            if let festa = estado.festa, !reduzirMovimento {
                Confetes().id(festa)
            }
        }
        .sensoryFeedback(.success, trigger: estado.festa) { _, nova in nova != nil }
        .task(id: estado.festa) {
            guard estado.festa != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            estado.festa = nil
        }
        .alert(estado.avisoPartilha ?? "", isPresented: Binding(presente: $estado.avisoPartilha)) {
            Button("OK", role: .cancel) {}
        }
        #if DEBUG
        .fullScreenCover(isPresented: $estado.demoWidgets) { DemoWidgetsView() }
        #endif
        .fullScreenCover(isPresented: Binding(
            get: { inicioQuestionario != nil },
            set: { if !$0 { fecharQuestionario() } }
        )) {
            if let inicio = inicioQuestionario {
                QuestionarioView(inicio: inicio, completo: inicio != .convite) { espacos in
                    ToDoApp.criarListasIniciais(espacos)
                }
            }
        }
        #if DEBUG
        .task {
            guard Demo.ativo else { return }
            try? await Task.sleep(for: .milliseconds(600))
            Demo.abrir(estado: estado, contexto: contexto)
        }
        #endif
        .sheet(isPresented: $estado.mostrarCaptura) {
            CapturaView()
                .environment(estado)
        }
        .sheet(isPresented: $estado.mostrarNovaLista) {
            PersonalizarListaView(modo: .nova)
        }
        .sheet(isPresented: $estado.mostrarFecho) {
            FechoDiaView(modo: .fecho)
                .environment(estado)
        }
        .sheet(isPresented: $estado.mostrarRever) {
            FechoDiaView(modo: .rever)
                .environment(estado)
        }
    }
}
