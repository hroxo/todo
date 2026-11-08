import SwiftData
import SwiftUI
import ToDoCore

/// Fecho do dia (Melhoria 33, DESIGN.md 7.25; mock 1B em `design/mocks/html/Engagement.html`):
/// os pontos que chegam ao fim, um cartão de cada vez, com Concluir, Manter e Deixar ir. No fim,
/// o Glassy conta como ficou o dia. Abre pela notificação, pelo Glassy no Início e pelo widget.
struct FechoDiaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var fechar
    @Environment(EstadoApp.self) private var estado
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    /// Os pontos ficam fixos ao abrir: o que chega ao fim durante o fecho fica para o seguinte.
    @State private var pontos: [Item] = []
    @State private var proximo = 0
    @State private var concluidos = 0
    @State private var mantidos = 0
    @State private var deixados = 0
    @State private var arrasto: CGFloat = 0

    private var definicoes: Definicoes { Definicoes.carregar() }

    /// O cartão por decidir. Outro aparelho (ou o widget) pode ter apagado ou concluído um ponto
    /// entretanto: `foiApagado` vem primeiro, porque ler um modelo apagado para a app.
    private var atual: (indice: Int, item: Item)? {
        guard proximo < pontos.count else { return nil }
        return pontos.indices[proximo...]
            .first { !pontos[$0].foiApagado && pontos[$0].estado == .ativo }
            .map { ($0, pontos[$0]) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let atual {
                    decidir(atual.item, indice: atual.indice)
                        .id(atual.item.persistentModelID)
                        .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                } else {
                    fim
                }
            }
            .padding(.horizontal, Espaco.margem)
            .padding(.bottom, Espaco.fim)
            .navigationTitle("Fechar o dia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sair") { fechar() }
                }
                if !pontos.isEmpty, atual != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Text("\(min(proximo + 1, pontos.count)) de \(pontos.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            guard pontos.isEmpty else { return }
            pontos = (try? Tarefas(contexto: contexto).pontosEmRisco(em: .now)) ?? []
        }
        // Também ao deslizar a folha para baixo: o dia fica fechado e o convite sai.
        .onDisappear {
            estado.fechoFeitoEm = .now
            estado.reagendarAvisos()
        }
    }

    // MARK: - Cartão

    private func decidir(_ item: Item, indice: Int) -> some View {
        let cor = item.lista?.cor ?? .azul
        let prazo = Prazo(item: item, agora: .now)
        return VStack(spacing: Espaco.bloco) {
            Spacer(minLength: 0)
            VStack(spacing: Espaco.grelha) {
                Text(item.lista?.nome ?? "")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(cor.tinta)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(cor.fundo))
                AnelExpiracao(fracao: prazo?.fracao ?? 0, cor: CoresEstado.expira, tamanho: 110, espessura: 10)
                    .overlay {
                        Text("Hoje")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(CoresEstado.expiraTinta)
                    }
                Text(item.titulo)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                if let limite = item.expiraEm {
                    Text(TextoAviso.quando(expiraEm: limite, agora: .now))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Espaco.bloco * 1.5)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .offset(x: arrasto)
            .rotationEffect(.degrees(reduzirMovimento ? 0 : Double(arrasto / 30)))
            .gesture(
                DragGesture()
                    .onChanged { arrasto = $0.translation.width }
                    .onEnded { valor in
                        // → mantém, ← deixa ir; os botões fazem o mesmo (alternativa a cada gesto).
                        if valor.translation.width > 120 {
                            agir(item, indice: indice) { $0.manter(item, longo: false); mantidos += 1 }
                        } else if valor.translation.width < -120 {
                            agir(item, indice: indice) { _ in deixados += 1 }
                        }
                        withAnimation(.snappy) { arrasto = 0 }
                    }
            )
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            GlassEffectContainer {
                VStack(spacing: Espaco.grelha) {
                    Button {
                        agir(item, indice: indice) { $0.concluir(item); concluidos += 1 }
                    } label: {
                        Label("Concluir", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(CoresEstado.concluido)

                    HStack(spacing: Espaco.grelha) {
                        Button {
                            agir(item, indice: indice) { $0.manter(item, longo: false); mantidos += 1 }
                        } label: {
                            Text("Manter +\(definicoes.diasManterCurto)")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        Button {
                            agir(item, indice: indice) { $0.manter(item, longo: true); mantidos += 1 }
                        } label: {
                            Text("Manter +\(definicoes.diasManterLongo)")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(.glass)

                    Button {
                        agir(item, indice: indice) { _ in deixados += 1 }
                    } label: {
                        Text("Deixar ir")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Passa à frente. O ponto expira no prazo dele e fica em Expirados.")
                }
            }
            Text("Desliza o cartão: → manter, ← deixar ir")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Aplica a decisão e passa ao cartão seguinte. "Deixar ir" não muda o ponto. Um segundo
    /// toque durante a animação chega com o cartão já decidido: não conta duas vezes.
    private func agir(_ item: Item, indice: Int, _ decisao: (Tarefas) -> Void) {
        guard indice >= proximo, !item.foiApagado else { return }
        decisao(Tarefas(contexto: contexto))
        try? contexto.save()
        withAnimation(reduzirMovimento ? nil : .snappy) { proximo = indice + 1 }
    }

    // MARK: - Fim

    private var fim: some View {
        let verde = (try? Tarefas(contexto: contexto).historico().dia(.now, calendario: .current)?.estado) == .verde
        return VStack(spacing: Espaco.bloco) {
            Spacer()
            Ampulheta(pose: verde ? .celebrar : .areia, nivelAreia: nil)
                .frame(width: 110, height: 140)
            Text(pontos.isEmpty ? "Nada chega ao fim hoje." : verde ? "Dia verde! Bom trabalho." : "Dia fechado.")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            if !pontos.isEmpty {
                Text(resumo)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button { fechar() } label: {
                Text("Fechar")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity)
    }

    private var resumo: String {
        var partes: [String] = []
        if concluidos > 0 { partes.append(concluidos == 1 ? "concluíste 1" : "concluíste \(concluidos)") }
        if mantidos > 0 { partes.append(mantidos == 1 ? "mantiveste 1" : "mantiveste \(mantidos)") }
        if deixados > 0 { partes.append(deixados == 1 ? "deixaste ir 1" : "deixaste ir \(deixados)") }
        guard let primeira = partes.first else { return "" }
        let frase = ([primeira.prefix(1).uppercased() + primeira.dropFirst()] + partes.dropFirst()).joined(separator: ", ")
        return frase + "."
    }
}
