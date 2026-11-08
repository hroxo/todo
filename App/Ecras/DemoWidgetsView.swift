#if DEBUG
import SwiftUI
import ToDoCore

/// Só para o modo de demonstração (`-ecra widget`): as vistas dos widgets lado a lado, em claro
/// e em escuro, com o tamanho real num iPhone de 402 pt, para comparar o desenho no simulador
/// sem ir à galeria de widgets.
struct DemoWidgetsView: View {
    private let resumo = ResumoWidget.exemplo()
    private var comFecho: ResumoWidget {
        var resumo = resumo
        resumo.minutosFecho = 0
        return resumo
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach([ColorScheme.light, .dark], id: \.self) { esquema in
                    cartao(VistaPontos(resumo: resumo, data: .now))
                        .environment(\.colorScheme, esquema)
                }
                // O teu ritmo: o pequeno (7 dias) e o médio (15), em claro e escuro.
                ForEach([ColorScheme.light, .dark], id: \.self) { esquema in
                    HStack(spacing: 16) {
                        ritmo(VistaRitmo(resumo: resumo, data: .now), largura: 170)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 364)
                    .environment(\.colorScheme, esquema)
                    ritmo(VistaRitmo(resumo: resumo, data: .now, quantos: ResumoWidget.diasRitmo), largura: 364)
                        .environment(\.colorScheme, esquema)
                }
                // Depois da hora do Fecho do dia: o médio convida a fechar o dia.
                ritmo(VistaRitmo(resumo: comFecho, data: .now, quantos: ResumoWidget.diasRitmo), largura: 364)
                // Sem pontos: o Glassy em todas as poses e, de dia, nos três temas.
                ForEach(PoseMascote.allCases, id: \.self) { pose in
                    vazio(pose, .geral)
                }
                ForEach([TemaMascote.trabalho, .pessoal, .viagem], id: \.self) { tema in
                    vazio(.areia, tema)
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

    private func ritmo(_ vista: some View, largura: CGFloat) -> some View {
        vista
            .padding(16)
            .frame(width: largura, height: 170)
            .background(Color(.systemBackground))
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    private func vazio(_ pose: PoseMascote, _ tema: TemaMascote) -> some View {
        VistaVazia(pose: pose, tema: tema)
            .padding(16)
            .frame(width: 364, height: 170)
            .background(CenarioMascote(pose: pose, tema: tema))
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
#endif
