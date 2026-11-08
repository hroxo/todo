import SwiftData
import SwiftUI
import ToDoCore

/// Streak (Melhoria 35, DESIGN.md 7.27; mock "O mundo do Glassy" em
/// `design/mocks/html/Engagement.html`): os grãos disponíveis, o teu mês (7.26) e os cenários a
/// desbloquear. Cada dia verde dá um grão; um cenário compra-se uma vez e nunca se perde, e o
/// escolhido fica no fundo do Início. É aqui que há de entrar o ranking com amigos, quando houver
/// backend (resumo.md, decisões de 7/11).
struct StreakView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.ceu) private var ceu
    @Query private var diasGanhos: [DiaGanho]
    @Query private var compras: [CenarioDesbloqueado]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "concluido" && $0.pai == nil })
    private var concluidos: [Item]
    @AppStorage("cenarioEscolhido") private var cenarioEscolhido = CenarioId.ceu.rawValue
    /// Lido fora do `body`, ao abrir e quando muda um ponto concluído.
    @State private var historico = HistoricoDias()

    @State private var aComprar: Cenario?
    @State private var comprados = 0
    @State private var erro: String?

    private let colunas = [GridItem(.flexible(), spacing: Espaco.grelha), GridItem(.flexible(), spacing: Espaco.grelha)]

    var body: some View {
        let saldo = Cenario.saldo(dias: diasGanhos, compras: compras)
        let desbloqueados = Cenario.desbloqueados(compras)
        let ativo = Cenario.ativo(escolhido: cenarioEscolhido, compras: compras)

        let tinta = Ceu.paleta(ceu.fase).tinta

        NavigationStack {
            ScrollViewReader { rolagem in
                EcraBase(titulo: "Streak") {
                    totalizador(saldo: saldo, desbloqueados: desbloqueados.count)

                    TituloSecao(texto: "O teu mês", cor: tinta)
                    MesStreak(historico: historico)

                    TituloSecao(texto: "Cenários", cor: tinta)
                        .id("cenarios")
                    LazyVGrid(columns: colunas, spacing: Espaco.grelha) {
                        ForEach(Cenario.catalogo) { cenario in
                            cartao(cenario, desbloqueado: desbloqueados.contains(cenario.id), ativo: ativo == cenario.id, saldo: saldo)
                        }
                    }
                }
                .task(id: concluidos.count) {
                    if let lido = Tarefas(contexto: contexto).historicoParaEcra() { historico = lido }
                }
                #if DEBUG
                .task {
                    // Só para as capturas do CI: `-rolarCenarios YES` desce até à coleção.
                    guard Demo.ativo, UserDefaults.standard.bool(forKey: "rolarCenarios") else { return }
                    try? await Task.sleep(for: .milliseconds(900))
                    rolagem.scrollTo("cenarios", anchor: .top)
                }
                #endif
            }
            .sensoryFeedback(.success, trigger: comprados)
            .sensoryFeedback(.selection, trigger: cenarioEscolhido)
            .confirmationDialog(
                aComprar.map { "Desbloquear \($0.nome) por \($0.custo) grãos?" } ?? "",
                isPresented: Binding(presente: $aComprar),
                titleVisibility: .visible,
                presenting: aComprar
            ) { cenario in
                Button("Desbloquear e usar") { comprar(cenario) }
                Button("Cancelar", role: .cancel) {}
            } message: { _ in
                Text("Fica teu para sempre. Ficas com \(saldo - (aComprar?.custo ?? 0)) grãos.")
            }
            .alert(erro ?? "", isPresented: Binding(presente: $erro)) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    /// O totalizador: os grãos que se podem gastar e quantos cenários já são teus.
    private func totalizador(saldo: Int, desbloqueados: Int) -> some View {
        HStack(spacing: Espaco.bloco) {
            Image(systemName: "hourglass.bottomhalf.filled")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(CoresEstado.expira))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Espaco.minimo) {
                Text("\(saldo)")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(saldo == 1 ? "grão disponível" : "grãos disponíveis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CoresEstado.expiraTinta)
                Text("Cada dia verde dá um grão. \(desbloqueados) de \(Cenario.catalogo.count) cenários são teus.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Espaco.bloco)
        .background(Ceu.cartao, in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .animation(.snappy, value: saldo)
    }

    private func cartao(_ cenario: Cenario, desbloqueado: Bool, ativo: Bool, saldo: Int) -> some View {
        let falta = cenario.custo - saldo
        let estado: String = if ativo {
            "Em uso"
        } else if desbloqueado {
            "Teu · tocar para usar"
        } else if falta > 0 {
            falta == 1 ? "Falta 1 grão" : "Faltam \(falta) grãos"
        } else {
            "Desbloquear · \(cenario.custo) grãos"
        }
        return Button {
            if desbloqueado {
                withAnimation(.snappy) { cenarioEscolhido = cenario.id.rawValue }
            } else if falta <= 0 {
                aComprar = cenario
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                CenaCenario(cenario: cenario.id, fase: ceu.fase, miniatura: true)
                    .frame(height: 120)
                    .saturation(desbloqueado ? 1 : 0.35)
                    .overlay(alignment: .topTrailing) {
                        if ativo || !desbloqueado {
                            Image(systemName: ativo ? "checkmark.circle.fill" : "lock.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(ativo ? CoresEstado.concluido : .white)
                                .shadow(radius: 2)
                                .padding(Espaco.curto)
                        }
                    }
                    .clipped()
                VStack(alignment: .leading, spacing: Espaco.minimo) {
                    Text(cenario.nome)
                        .font(.headline)
                    Text(estado)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ativo ? CoresEstado.concluido : desbloqueado || falta > 0 ? .secondary : CoresEstado.expiraTinta)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(Espaco.grelha)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            }
            .background(Ceu.cartao)
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
            .overlay {
                if ativo {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(CoresEstado.concluido, lineWidth: 3)
                }
            }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cenario.nome), \(estado)")
        .accessibilityAddTraits(ativo ? [.isButton, .isSelected] : .isButton)
    }

    /// Compra e passa logo a usar. Sem grãos que cheguem (outro aparelho gastou-os entretanto)
    /// diz porquê; nada muda.
    private func comprar(_ cenario: Cenario) {
        do {
            try Tarefas(contexto: contexto).desbloquear(cenario.id)
            try contexto.save()
            comprados += 1
            withAnimation(.snappy) { cenarioEscolhido = cenario.id.rawValue }
        } catch ErroTarefas.graosInsuficientes {
            erro = "Ainda não tens grãos que cheguem para \(cenario.nome)."
        } catch {
            contexto.rollback()
            erro = "Não foi possível desbloquear \(cenario.nome). Tenta outra vez."
        }
    }
}
