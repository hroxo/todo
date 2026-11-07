import AuthenticationServices
import SwiftUI

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
