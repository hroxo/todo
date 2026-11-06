import SwiftData
import SwiftUI
import ToDoCore

/// Barra de separadores com liquid glass (DESIGN.md 7.1). O "+" da captura é um separador
/// com o papel de pesquisa, que o iOS desenha como um círculo de vidro à direita da barra;
/// ao tocá-lo abre-se a captura e volta-se ao separador anterior.
struct RaizView: View {
    @Environment(EstadoApp.self) private var estado
    @Environment(\.modelContext) private var contexto
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "expirado" }) private var expirados: [Item]
    /// As boas-vindas (com o login opcional) só aparecem na primeira abertura.
    @AppStorage("boasVindasVistas") private var boasVindasVistas = false
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Query private var listas: [Lista]
    @State private var tamanho = CGSize.zero
    /// Pressão longa no "+" (ver `seguirPressaoLonga`): o toque que a acaba não abre a captura.
    @State private var temporizador: Task<Void, Never>?
    @State private var pressaoLonga = false
    @State private var vibrar = 0

    /// Onde o iOS desenha o "+" (círculo de vidro no canto de baixo à direita).
    private func naZonaDoMais(_ ponto: CGPoint) -> Bool {
        ponto.x > tamanho.width - 100 && ponto.y > tamanho.height - 110
    }

    /// Mantém premido o "+" durante meio segundo: nova lista. É um gesto em simultâneo com o
    /// toque normal (que o separador do sistema continua a tratar).
    private var seguirPressaoLonga: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { toque in
                if temporizador != nil {
                    // Arrastar cancela a pressão.
                    if hypot(toque.translation.width, toque.translation.height) > 12 {
                        temporizador?.cancel()
                    }
                    return
                }
                pressaoLonga = false
                guard naZonaDoMais(toque.startLocation) else { return }
                temporizador = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    pressaoLonga = true
                    vibrar += 1
                    abrirNovaLista()
                }
            }
            .onEnded { _ in
                temporizador?.cancel()
                temporizador = nil
            }
    }

    private func abrirNovaLista() {
        if listas.count < Tarefas.maxListas {
            estado.mostrarNovaLista = true
        } else {
            estado.avisoPartilha = Tarefas.avisoLimiteListas
        }
    }

    var body: some View {
        @Bindable var estado = estado

        TabView(selection: $estado.separador) {
            Tab("Listas", systemImage: "list.bullet", value: EstadoApp.Separador.listas) {
                InicioView()
            }
            Tab("Concluídos", systemImage: "checkmark.circle", value: EstadoApp.Separador.concluidos) {
                ConcluidosView()
            }
            Tab("Expirados", systemImage: "hourglass", value: EstadoApp.Separador.expirados) {
                ExpiradosView()
            }
            .badge(expirados.count)
            Tab("Definições", systemImage: "gearshape", value: EstadoApp.Separador.definicoes) {
                DefinicoesView()
            }
            Tab("Nova nota", systemImage: "plus", value: EstadoApp.Separador.captura, role: .search) {
                Color.clear
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onGeometryChange(for: CGSize.self, of: \.size) { tamanho = $0 }
        .simultaneousGesture(seguirPressaoLonga)
        .sensoryFeedback(.impact, trigger: vibrar)
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
        .sheet(isPresented: Binding(
            get: { !boasVindasVistas && !Demo.ativo },
            set: { if !$0 { boasVindasVistas = true } }
        )) {
            BoasVindasView()
                .presentationDetents([.large])
                .presentationBackground(Ceu.folha)
        }
        .onChange(of: estado.separador) { anterior, novo in
            if novo == .captura {
                estado.separador = anterior == .captura ? .listas : anterior
                // O toque que acaba uma pressão longa já abriu a nova lista.
                if pressaoLonga {
                    pressaoLonga = false
                } else {
                    estado.mostrarCaptura = true
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
    }
}
