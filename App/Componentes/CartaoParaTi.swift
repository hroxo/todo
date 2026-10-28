import SwiftUI
import ToDoCore

/// O cartão "Para ti" no topo do Início (DESIGN.md 7.21), compacto: os brilhos, a frase em até
/// duas linhas (escrita pelo modelo do iPhone, quando há) e os botões por baixo. Um contorno
/// suave em gradiente marca que é uma sugestão; o "x" dispensa-o até o assunto mudar.
struct CartaoParaTi: View {
    let paraTi: ParaTi
    let frase: String
    let agir: (ParaTi.Acao) -> Void
    let dispensar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Espaco.grelha) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .symbolEffect(.pulse, options: .repeat(2))
                .padding(.top, 2)
                .accessibilityLabel("Para ti")

            VStack(alignment: .leading, spacing: Espaco.curto) {
                Text(frase)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if !paraTi.botoes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(paraTi.botoes) { botao in
                            Button {
                                agir(botao.acao)
                            } label: {
                                let destaque = botao.id == paraTi.botoes.first?.id
                                Text(botao.rotulo)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(destaque ? Color.indigo : Color.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(destaque ? Color.indigo.opacity(0.14) : Color(.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: dispensar) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.top, -4)
            .padding(.trailing, -6)
            .accessibilityLabel("Dispensar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.indigo.opacity(0.45), .pink.opacity(0.3), .orange.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        }
        .accessibilityElement(children: .contain)
    }
}
