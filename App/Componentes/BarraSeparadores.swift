import SwiftUI

/// A barra de baixo (DESIGN.md 7.1): os 4 separadores numa cápsula de vidro e o "+" da captura
/// num círculo à parte, à direita. É nossa porque o iOS 27 deixou de separar o separador de
/// pesquisa e o "+" passava a ser mais um separador dentro da barra. Tocar no "+" abre a Nova
/// nota; mantê-lo premido abre, por cima dele, o menu com Nova lista.
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
                    botao("Concluídos", simbolo: "checkmark.circle", .concluidos)
                    botao("Expirados", simbolo: "hourglass", .expirados, contagem: expirados)
                    botao("Definições", simbolo: "gearshape", .definicoes)
                }
                .padding(.horizontal, Espaco.fino)
                .frame(height: Self.altura)
                .glassEffect(.regular.interactive(), in: .capsule)

                Menu {
                    Button("Nova lista", systemImage: "square.grid.2x2", action: novaLista)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .frame(width: Self.altura, height: Self.altura)
                        .contentShape(.circle)
                } primaryAction: {
                    novaNota()
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Nova nota")
                .accessibilityHint("Mantém premido para criar uma lista.")
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

/// Ecrãs que escondem a barra de baixo: o Detalhe tem o Manter no fundo (DESIGN.md 7.5).
struct BarraEscondida: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
