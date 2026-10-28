import SwiftUI
import ToDoCore

/// Só para o modo de demonstração (`-ecra widget`): as vistas dos widgets lado a lado, em claro
/// e em escuro, com o tamanho real num iPhone de 402 pt, para comparar o desenho no simulador
/// sem ir à galeria de widgets.
struct DemoWidgetsView: View {
    private let resumo = ResumoWidget.exemplo()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach([ColorScheme.light, .dark], id: \.self) { esquema in
                    cartao(VistaPontos(resumo: resumo, data: .now))
                        .environment(\.colorScheme, esquema)
                }
                // Sem pontos: a Ampulheta nas quatro poses, com o cenário de cada uma.
                ForEach(PoseMascote.allCases, id: \.self) { pose in
                    VistaVazia(pose: pose)
                        .padding(16)
                        .frame(width: 364, height: 170)
                        .background(CenarioMascote(pose: pose))
                        .clipShape(.rect(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                }
                ecraBloqueado
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [.indigo, .purple, .orange], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func cartao(_ vista: some View) -> some View {
        vista
            .padding(16)
            .frame(width: 364, height: 170)
            .background(FundoPontos(resumo: resumo))
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    private var ecraBloqueado: some View {
        HStack(spacing: 16) {
            VistaMaisCircular()
                .frame(width: 72, height: 72)
            VistaMaisRetangular(resumo: resumo)
                .frame(width: 170, height: 72)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}
