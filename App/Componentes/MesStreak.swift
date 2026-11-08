import SwiftUI
import ToDoCore

/// O mês do Streak (DESIGN.md 7.26): a grelha com os dias do histórico, de segunda a domingo.
/// Muda de mês com as setas ou a deslizar, entre o primeiro registo e o mês atual.
struct MesStreak: View {
    let historico: HistoricoDias

    @State private var mostrado = Date.now

    private let colunas = Array(repeating: GridItem(.flexible(), spacing: Espaco.curto), count: 7)
    private static let letras = ["S", "T", "Q", "Q", "S", "S", "D"]

    var body: some View {
        let mes = historico.mes(de: mostrado, agora: .now, calendario: .current)
        VStack(spacing: Espaco.bloco) {
            HStack {
                seta("chevron.left", rotulo: "Mês anterior", para: mes.anterior)
                Spacer()
                VStack(spacing: Espaco.minimo) {
                    Text(mes.titulo)
                        .font(.title3.weight(.bold))
                    Text(mes.verdes == 1 ? "1 dia verde" : "\(mes.verdes) dias verdes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                seta("chevron.right", rotulo: "Mês seguinte", para: mes.seguinte)
            }

            LazyVGrid(columns: colunas, spacing: Espaco.curto) {
                ForEach(Self.letras.indices, id: \.self) { i in
                    Text(Self.letras[i])
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(0..<mes.vazios, id: \.self) { _ in
                    Color.clear.frame(height: 1).accessibilityHidden(true)
                }
                ForEach(mes.dias) { dia in
                    VStack(spacing: Espaco.minimo) {
                        BolaDia(dia: dia.dia, hoje: dia.hoje, tamanho: 26, futuro: dia.futuro, rotulo: dia.rotulo)
                        Text("\(dia.numero)")
                            .font(.caption2.weight(dia.hoje ? .heavy : .regular))
                            .foregroundStyle(dia.futuro ? .tertiary : .secondary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { valor in
                    // ← mês seguinte, → mês anterior; as setas fazem o mesmo.
                    if valor.translation.width < -60, let seguinte = mes.seguinte { mudar(para: seguinte) }
                    if valor.translation.width > 60, let anterior = mes.anterior { mudar(para: anterior) }
                }
            )

            legenda
        }
        .padding(Espaco.bloco)
        .background(Ceu.cartao, in: .rect(cornerRadius: 18, style: .continuous))
        .sensoryFeedback(.selection, trigger: mes.titulo)
    }

    private func mudar(para data: Date) {
        withAnimation(.snappy) { mostrado = data }
    }

    private func seta(_ simbolo: String, rotulo: String, para destino: Date?) -> some View {
        Button {
            if let destino { mudar(para: destino) }
        } label: {
            Image(systemName: simbolo)
                .font(.headline)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(destino == nil)
        .accessibilityLabel(rotulo)
    }

    /// A cor nunca é o único sinal: a legenda repete as marcas (DESIGN.md 9).
    private var legenda: some View {
        HStack(spacing: Espaco.bloco) {
            item(DiaHistorico(dia: "", concluiu: true, expirou: false), "Concluíste")
            item(DiaHistorico(dia: "", concluiu: false, expirou: true), "Expirou")
            item(DiaHistorico(dia: "", concluiu: false, expirou: false), "Sem nada")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private func item(_ dia: DiaHistorico, _ texto: String) -> some View {
        HStack(spacing: Espaco.fino) {
            BolaDia(dia: dia, tamanho: 14)
            Text(texto)
        }
    }
}

extension Tarefas {
    /// O histórico para a semana e o Streak: o ficheiro do App Group junto ao que os pontos
    /// mostram, e o grão do dia logo que fica verde (sem esperar pela manutenção seguinte). Sem
    /// App Group (testes, `.ipa` sem assinatura) só conta o que os pontos mostram. Devolve nil se
    /// a leitura falhar: o ecrã fica como estava, porque o ficheiro não é dado do utilizador.
    @MainActor
    func historicoParaEcra() -> HistoricoDias? {
        guard let lido = try? historico(juntandoA: BaseDados.pastaPartilhada.map(HistoricoDias.ler(de:)) ?? HistoricoDias())
        else { return nil }
        do {
            try registarGraos(de: lido)
            if contexto.hasChanges { try contexto.save() }
        } catch {
            // O grão volta a tentar-se na abertura seguinte (`ToDoApp.manutencao`): nada se perde.
        }
        return lido
    }
}
