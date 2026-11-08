import SwiftUI

/// A barra de baixo (DESIGN.md 7.1): os 4 separadores (Listas, Arquivo, Streak, Definições) numa cápsula de vidro e o "+" da captura
/// num círculo à parte, à direita. É nossa porque o iOS 27 deixou de separar o separador de
/// pesquisa e o "+" passava a ser mais um separador dentro da barra. Tocar no "+" abre a Nova
/// nota; mantê-lo premido mostra por cima a cápsula "Nova lista" (ver `BotaoMais`).
struct BarraSeparadores: View {
    @Binding var separador: EstadoApp.Separador
    let expirados: Int
    let novaNota: () -> Void
    let novaLista: () -> Void

    private static let altura: CGFloat = 62

    var body: some View {
        GlassEffectContainer(spacing: Espaco.grelha) {
            HStack(spacing: Espaco.grelha) {
                HStack(spacing: 0) {
                    botao("Listas", simbolo: "list.bullet", .listas)
                    botao("Arquivo", simbolo: "archivebox", .arquivo, contagem: expirados)
                    botao("Streak", simbolo: "flame", .streak)
                    botao("Definições", simbolo: "gearshape", .definicoes)
                }
                .padding(.horizontal, Espaco.fino)
                .frame(height: Self.altura)
                .glassEffect(.regular.interactive(), in: .capsule)

                BotaoMais(lado: Self.altura, novaNota: novaNota, novaLista: novaLista)
            }
        }
        .padding(.horizontal, Espaco.margem)
        .padding(.bottom, Espaco.fino)
        .sensoryFeedback(.selection, trigger: separador)
    }

    private func botao(_ titulo: String, simbolo: String, _ valor: EstadoApp.Separador, contagem: Int = 0) -> some View {
        let ativo = separador == valor
        return Button {
            separador = valor
        } label: {
            VStack(spacing: Espaco.minimo) {
                Image(systemName: simbolo)
                    .font(.title3)
                    .symbolVariant(ativo ? .fill : .none)
                    .overlay(alignment: .topTrailing) {
                        if contagem > 0 {
                            Text("\(contagem)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Capsule().fill(.red))
                                .offset(x: 10, y: -6)
                        }
                    }
                Text(titulo)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(ativo ? Color.accentColor : Color.primary)
            .background {
                if ativo { Capsule().fill(Color.primary.opacity(0.08)) }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titulo)
        .accessibilityValue(contagem > 0 ? "\(contagem)" : "")
        .accessibilityAddTraits(ativo ? [.isSelected, .isButton] : .isButton)
    }
}

/// O "+" da barra: tocar abre a Nova nota. Mantido premido, aparece por cima a cápsula de vidro
/// "Nova lista" (quadrado com visto); arrastar o dedo até ela e largar abre a Nova lista, largar
/// noutro sítio não faz nada. O VoiceOver tem a ação "Nova lista".
private struct BotaoMais: View {
    let lado: CGFloat
    let novaNota: () -> Void
    let novaLista: () -> Void

    private static let largura: CGFloat = 150
    private static let altura: CGFloat = 48
    private static let folga: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    /// Meio segundo premido sem arrastar: a cápsula aparece.
    @State private var temporizador: Task<Void, Never>?
    @State private var aberto = false
    @State private var sobre = false
    /// Arrastou antes de abrir (estava só a passar o dedo): ao largar não abre nada.
    @State private var cancelado = false

    /// Onde fica a cápsula, nas coordenadas do "+" (alinhada à direita), com margem para o dedo.
    private var alvo: CGRect {
        CGRect(x: lado - Self.largura, y: -Self.folga - Self.altura, width: Self.largura, height: Self.altura)
            .insetBy(dx: -16, dy: -16)
    }

    private var gesto: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { toque in
                if aberto {
                    sobre = alvo.contains(toque.location)
                } else if temporizador == nil, !cancelado {
                    temporizador = Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        guard !Task.isCancelled else { return }
                        aberto = true
                    }
                } else if hypot(toque.translation.width, toque.translation.height) > 12 {
                    temporizador?.cancel()
                    cancelado = true
                }
            }
            .onEnded { _ in
                temporizador?.cancel()
                temporizador = nil
                if aberto {
                    if sobre { novaLista() }
                } else if !cancelado {
                    novaNota()
                }
                aberto = false
                sobre = false
                cancelado = false
            }
    }

    var body: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.medium))
            .foregroundStyle(Color.primary)
            .frame(width: lado, height: lado)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
            .overlay(alignment: .topTrailing) {
                if aberto {
                    Label("Nova lista", systemImage: "checkmark.square.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sobre ? Color.white : Color.accentColor)
                        .frame(width: Self.largura, height: Self.altura)
                        .glassEffect(sobre ? .regular.tint(.accentColor) : .regular, in: .capsule)
                        .scaleEffect(sobre && !reduzirMovimento ? 1.08 : 1, anchor: .bottomTrailing)
                        .offset(y: -Self.folga - Self.altura)
                        .transition(reduzirMovimento ? .opacity : .scale(scale: 0.4, anchor: .bottomTrailing).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(reduzirMovimento ? nil : .spring(duration: 0.3, bounce: 0.35), value: aberto)
            .animation(reduzirMovimento ? nil : .spring(duration: 0.2), value: sobre)
            .gesture(gesto)
            .sensoryFeedback(.impact, trigger: aberto) { _, novo in novo }
            .sensoryFeedback(.selection, trigger: sobre) { _, novo in novo }
            .accessibilityElement()
            .accessibilityLabel("Nova nota")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Mantém premido e arrasta até \"Nova lista\" para criar uma lista.")
            .accessibilityAction { novaNota() }
            .accessibilityAction(named: "Nova lista") { novaLista() }
    }
}

/// Ecrãs que escondem a barra de baixo: o Detalhe tem o Manter no fundo (DESIGN.md 7.5).
struct BarraEscondida: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
