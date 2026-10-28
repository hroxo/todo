import AuthenticationServices
import SwiftUI

/// Primeira abertura (DESIGN.md 7.20): a Ampulheta a acenar e o convite, opcional, para
/// iniciar sessão com a Apple. "Agora não" fecha e não volta a aparecer; a sessão também se
/// inicia em Definições › Conta.
struct BoasVindasView: View {
    @Environment(ContaApple.self) private var conta
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        VStack(spacing: Espaco.margem) {
            Spacer(minLength: 0)
            Ampulheta(pose: .acenar)
                .frame(width: 110, height: 132)
            VStack(spacing: Espaco.curto) {
                Text("Bem-vindo à ToDo")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("A lista que se limpa sozinha: o que fica 3 dias sem ação sai da frente, e nada se perde.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            VStack(spacing: Espaco.grelha) {
                SignInWithAppleButton(.signIn, onRequest: conta.configurar) { resultado in
                    conta.concluir(resultado)
                    if conta.ligada { dismiss() }
                }
                .signInWithAppleButtonStyle(esquema == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(.capsule)

                if let erro = conta.erro {
                    Text(erro)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Agora não") { dismiss() }
                    .font(.headline)
                    .frame(minHeight: 44)

                Text("Opcional. A conta guarda o teu perfil e prepara a ToDo para outros aparelhos; os teus dados ficam no teu iCloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Espaco.margem)
        .interactiveDismissDisabled(false)
    }
}

/// Definições › Conta: quem tem a sessão iniciada, ou o botão para a iniciar.
struct SecaoConta: View {
    @Environment(ContaApple.self) private var conta
    @Environment(\.colorScheme) private var esquema
    @State private var confirmarSaida = false

    var body: some View {
        Section {
            if case .ligada(let nome, let email) = conta.estado {
                HStack(spacing: Espaco.grelha) {
                    Text(String((nome ?? "?").prefix(1)).uppercased())
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.accentColor.gradient))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nome ?? "Conta Apple")
                            .font(.headline)
                        Text(email ?? "Sessão iniciada com a Apple")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Terminar sessão", role: .destructive) { confirmarSaida = true }
            } else {
                SignInWithAppleButton(.signIn, onRequest: conta.configurar, onCompletion: conta.concluir)
                    .signInWithAppleButtonStyle(esquema == .dark ? .white : .black)
                    .frame(height: 46)
                    .clipShape(.capsule)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                if let erro = conta.erro {
                    Text(erro)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Conta")
        } footer: {
            Text(conta.ligada
                 ? "Os teus dados ficam no teu iCloud. Terminar sessão não apaga nada."
                 : "Opcional. Inicia sessão com a Apple para guardares o teu perfil e preparares a ToDo para outros aparelhos.")
        }
        .confirmationDialog("Terminar sessão?", isPresented: $confirmarSaida, titleVisibility: .visible) {
            Button("Terminar sessão", role: .destructive) { conta.terminar() }
        } message: {
            Text("Os teus pontos ficam neste iPhone e no iCloud.")
        }
    }
}
