import AuthenticationServices
import SwiftUI
import ToDoCore

/// Questionário da primeira abertura (DESIGN.md 7.20, mock `design/mocks/Questionario.png`):
/// três perguntas com valores já escolhidos (ritmo, avisos e uso), para quem só quer carregar
/// em Continuar, e o fim com o login opcional da Apple. Quem já usa a app vê uma vez o convite
/// "Ajusta a ToDo ao teu ritmo" e só responde ao ritmo e aos avisos. Tudo se muda depois em
/// Definições.
struct QuestionarioView: View {
    enum Passo: Hashable {
        case entrada, convite, ritmo, avisos, uso, pronto
    }

    /// Por onde começa: `.entrada` (primeira abertura) ou `.convite` (quem já usa a app).
    let inicio: Passo
    /// Só no questionário completo: cria os espaços (os escolhidos, ou Trabalho e Pessoal ao saltar).
    var criarEspacos: ([EspacoInicial]) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ceu) private var ceu
    @Environment(\.agora) private var agora
    @Environment(\.colorScheme) private var esquema
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(ContaApple.self) private var conta
    @State private var passo: Passo
    @State private var definicoes = Definicoes.carregar()
    @State private var usos: Set<EspacoInicial> = [.trabalho]

    /// Quem já usa a app (convite, ou "Responder outra vez" nas Definições) só responde a duas
    /// perguntas e não chega ao Uso nem ao fim.
    private let soAjustar: Bool

    /// `completo` por defeito só quando começa na entrada; a demonstração pode abrir uma
    /// pergunta do questionário completo.
    init(inicio: Passo, completo: Bool? = nil, criarEspacos: @escaping ([EspacoInicial]) -> Void = { _ in }) {
        self.inicio = inicio
        self.criarEspacos = criarEspacos
        soAjustar = !(completo ?? (inicio == .entrada))
        _passo = State(initialValue: inicio)
    }
    private var tinta: Color { Ceu.paleta(ceu.fase).tinta }

    var body: some View {
        Group {
            switch passo {
            case .entrada: entrada
            case .convite: convite
            case .ritmo: ritmo
            case .avisos: avisos
            case .uso: uso
            case .pronto: pronto
            }
        }
        .padding(.horizontal, Espaco.margem)
        .padding(.bottom, Espaco.curto)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { FundoCeu(cena: passo == .entrada || passo == .convite || passo == .pronto) }
        .foregroundStyle(tinta)
        .animation(reduzirMovimento ? nil : .smooth, value: passo)
    }

    // MARK: - Passos

    private var entrada: some View {
        boasVindas(
            pose: .acenar,
            novidade: false,
            titulo: "Bem-vindo à ToDo",
            texto: "A lista que se limpa sozinha. Três perguntas para a ajustar ao teu ritmo.",
            botao: "Começar",
            secundario: "Saltar"
        ) {
            criarEspacos(EspacoInicial.predefinidos)
            dismiss()
        }
    }

    private var convite: some View {
        boasVindas(
            pose: .acenar,
            novidade: true,
            titulo: "Ajusta a ToDo ao teu ritmo",
            texto: "Duas perguntas: quanto tempo fica um ponto e quando queres o aviso. Começa com o que tens agora.",
            botao: "Ajustar",
            secundario: "Agora não"
        ) {
            dismiss()
        }
    }

    private var ritmo: some View {
        let dias = Binding(
            get: { Double(min(Definicoes.intervaloQuestionario.upperBound, max(Definicoes.intervaloQuestionario.lowerBound, definicoes.diasExpiracao))) },
            set: { definicoes.diasExpiracao = Int($0) }
        )
        let saida = Calendar.current.date(byAdding: .day, value: definicoes.diasExpiracao, to: agora) ?? agora
        return pergunta(
            numero: 1,
            titulo: "Quanto tempo fica um ponto sem ações?",
            texto: "Se não lhe tocares nesse tempo, sai da lista e fica em Expirados.",
            nota: "Muda-se em Definições › Avançado."
        ) {
            VStack(alignment: .leading, spacing: Espaco.grelha) {
                HStack(alignment: .firstTextBaseline, spacing: Espaco.fino) {
                    Text("\(definicoes.diasExpiracao)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text(definicoes.diasExpiracao == 1 ? "dia" : "dias")
                        .font(.title3.bold())
                }
                Slider(
                    value: dias,
                    in: Double(Definicoes.intervaloQuestionario.lowerBound)...Double(Definicoes.intervaloQuestionario.upperBound),
                    step: 1
                )
                .accessibilityLabel("Dias sem ações")
                .accessibilityValue(Formatos.dias(definicoes.diasExpiracao))
                .sensoryFeedback(.selection, trigger: definicoes.diasExpiracao)
                HStack {
                    Text(Formatos.dias(Definicoes.intervaloQuestionario.lowerBound))
                    Spacer()
                    Text("\(Definicoes().diasExpiracao) é o sugerido")
                        .foregroundStyle(Color.accentColor)
                        .bold()
                    Spacer()
                    Text(Formatos.dias(Definicoes.intervaloQuestionario.upperBound))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Um ponto criado hoje sai \(Text(Formatos.noDia(saida)).bold()).")
                    .font(.subheadline)
                Text("Mexer-lhe recomeça a contagem.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.primary)
            .padding(Espaco.bloco)
            .background(Ceu.cartao, in: .rect(cornerRadius: 22, style: .continuous))
        } continuar: {
            definicoes.guardar()
            passo = .avisos
        }
    }

    private var avisos: some View {
        pergunta(
            numero: 2,
            titulo: "Quando queres o aviso?",
            texto: "Um aviso antes de um ponto sair, para o manteres ou concluíres."
        ) {
            VStack(spacing: Espaco.curto) {
                opcaoAviso(.vinteQuatroHoras, "À hora exata. De madrugada passa para a manhã.")
                opcaoAviso(.manha, "Na véspera de o ponto sair.")
                opcaoAviso(.noite, "Na véspera, depois do dia acabar.")
            }
        } continuar: {
            definicoes.guardar()
            if soAjustar { dismiss() } else { passo = .uso }
        }
    }

    private var uso: some View {
        let escolhidos = EspacoInicial.allCases.filter { usos.contains($0) && $0 != .pessoal }
        let nomes = escolhidos.map(\.nome) + [EspacoInicial.pessoal.nome]
        let lista = nomes.count == 1 ? nomes[0] : nomes.dropLast().joined(separator: ", ") + " e " + nomes.last!
        return pergunta(
            numero: 3,
            titulo: "Para que vais usar a ToDo?",
            texto: "Escolhe as que quiseres: criamos os teus primeiros espaços.",
            nota: "Pessoal fica sempre. Vais começar com \(lista)."
        ) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Espaco.grelha), GridItem(.flexible())], spacing: Espaco.grelha) {
                ForEach(EspacoInicial.allCases.filter { $0 != .pessoal }, id: \.self) { espaco in
                    cartaoUso(espaco)
                }
            }
            .sensoryFeedback(.selection, trigger: usos)
        } continuar: {
            criarEspacos(Array(usos))
            passo = .pronto
        }
    }

    private var pronto: some View {
        VStack(spacing: Espaco.bloco) {
            Spacer(minLength: Espaco.bloco)
            Ampulheta(pose: .celebrar, vivo: true)
                .frame(width: 110, height: 132)
            Text("Está pronto")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text("Bom trabalho. O teu ritmo e os avisos ficam em Definições, para mudares quando quiseres.")
                .font(.body)
                .multilineTextAlignment(.center)
            Spacer(minLength: Espaco.bloco)
            VStack(spacing: Espaco.grelha) {
                botaoPrincipal("Começar a usar") { dismiss() }
                if !conta.ligada {
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
                            .multilineTextAlignment(.center)
                    }
                    Text("Opcional. Guarda o teu perfil para outros aparelhos; os teus dados ficam no teu iCloud.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Peças

    /// Entrada e convite: o Glassy sobre as colinas e dois botões em baixo.
    private func boasVindas(
        pose: PoseMascote,
        novidade: Bool,
        titulo: String,
        texto: String,
        botao: String,
        secundario: String,
        aoSair: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Espaco.bloco) {
            Spacer(minLength: Espaco.bloco)
            Ampulheta(pose: pose, vivo: true)
                .frame(width: 110, height: 132)
            if novidade {
                Text("Novo")
                    .font(.caption.bold())
                    .padding(.horizontal, Espaco.grelha)
                    .padding(.vertical, Espaco.fino)
                    .background(Ceu.cartao.opacity(0.75), in: .capsule)
            }
            Text(titulo)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
            Text(texto)
                .font(.body)
                .multilineTextAlignment(.center)
            Spacer(minLength: Espaco.bloco)
            botaoPrincipal(botao) { passo = .ritmo }
            Button(secundario, action: aoSair)
                .font(.headline)
                .frame(minHeight: 44)
        }
    }

    /// Uma pergunta: o passo em traços, o título, o conteúdo e Continuar em baixo.
    private func pergunta<Conteudo: View>(
        numero: Int,
        titulo: String,
        texto: String,
        nota: String? = nil,
        @ViewBuilder conteudo: () -> Conteudo,
        continuar: @escaping () -> Void
    ) -> some View {
        let total = soAjustar ? 2 : 3
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Espaco.fino + Espaco.minimo) {
                ForEach(1...total, id: \.self) { i in
                    Capsule()
                        .fill(i <= numero ? tinta : tinta.opacity(0.2))
                        .frame(width: 26, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Espaco.curto)
            .accessibilityElement()
            .accessibilityLabel("Pergunta \(numero) de \(total)")
            ScrollView {
                VStack(alignment: .leading, spacing: Espaco.bloco) {
                    VStack(alignment: .leading, spacing: Espaco.curto) {
                        Text(titulo)
                            .font(.system(.title, design: .rounded).weight(.heavy))
                        Text(texto)
                            .font(.subheadline)
                            .opacity(0.75)
                    }
                    conteudo()
                    if let nota {
                        Text(nota)
                            .font(.footnote)
                            .opacity(0.75)
                    }
                }
                .padding(.top, Espaco.bloco + Espaco.curto)
            }
            .scrollBounceBehavior(.basedOnSize)
            botaoPrincipal(soAjustar && numero == total ? "Guardar" : "Continuar", acao: continuar)
                .padding(.top, Espaco.curto)
        }
    }

    private func botaoPrincipal(_ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private func opcaoAviso(_ modo: ModoAviso, _ explicacao: String) -> some View {
        let escolhido = definicoes.modoAviso == modo
        return VStack(alignment: .leading, spacing: Espaco.grelha) {
            Button {
                definicoes.escolher(modo)
            } label: {
                HStack(alignment: .top, spacing: Espaco.grelha) {
                    Image(systemName: escolhido ? "largecircle.fill.circle" : "circle")
                        .font(.title3)
                        .foregroundStyle(escolhido ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: Espaco.minimo) {
                        Text(modo.nome)
                            .font(.headline)
                        Text(explicacao)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(escolhido ? .isSelected : [])
            if escolhido && modo != .vinteQuatroHoras {
                Divider()
                DatePicker("Hora", selection: $definicoes.horaAvisos, displayedComponents: .hourAndMinute)
                    .environment(\.locale, Locale(identifier: "pt_PT"))
            }
        }
        .foregroundStyle(Color.primary)
        .padding(Espaco.bloco)
        .background(Ceu.cartao, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(escolhido ? Color.accentColor : .clear, lineWidth: 2)
        }
        .sensoryFeedback(.selection, trigger: definicoes.modoAviso)
    }

    private func cartaoUso(_ espaco: EspacoInicial) -> some View {
        let escolhido = usos.contains(espaco)
        return Button {
            if escolhido { usos.remove(espaco) } else { usos.insert(espaco) }
        } label: {
            VStack(alignment: .leading, spacing: Espaco.grelha) {
                HStack(alignment: .top) {
                    Image(systemName: espaco.icone)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(espaco.cor.texto)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(espaco.cor.base))
                    Spacer()
                    Image(systemName: escolhido ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(escolhido ? Color.accentColor : Color.secondary)
                }
                VStack(alignment: .leading, spacing: Espaco.minimo) {
                    Text(espaco.nome)
                        .font(.headline)
                    if espaco == .compras {
                        Text("Aqui nada expira")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .foregroundStyle(Color.primary)
            .padding(Espaco.grelha + Espaco.minimo)
            .background(Ceu.cartao, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(escolhido ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(espaco.nome)
        .accessibilityAddTraits(escolhido ? .isSelected : [])
    }
}
