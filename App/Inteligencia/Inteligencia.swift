import FoundationModels
import ToDoCore

/// Funções inteligentes com o modelo da Apple no próprio iPhone (Foundation Models, DESIGN.md
/// 7.16): nada sai do telemóvel. O núcleo escolhe os factos; o modelo só os redige. Sem
/// Apple Intelligence (ou no simulador num Mac Intel), devolve nil e fica o texto de base.
enum Inteligencia {
    static var disponivel: Bool {
        if case .available = SystemLanguageModel.default.availability { true } else { false }
    }

    /// Para as Definições.
    static var estado: String {
        switch SystemLanguageModel.default.availability {
        case .available: "Ativa, no iPhone"
        case .unavailable(.appleIntelligenceNotEnabled): "Liga o Apple Intelligence nos Ajustes"
        case .unavailable(.deviceNotEligible): "Este iPhone não tem Apple Intelligence"
        case .unavailable(.modelNotReady): "O modelo ainda está a descarregar"
        default: "Indisponível"
        }
    }

    @Generable
    struct FraseWidget {
        @Guide(description: "Uma frase curta e calorosa em português europeu, com no máximo 60 caracteres")
        var texto: String
    }

    /// A frase do topo do widget (DESIGN.md 7.14): o estado do dia numa frase, a partir dos
    /// pontos que importam agora.
    static func fraseWidget(_ resumo: ResumoWidget) async -> String? {
        guard disponivel else { return nil }
        let sessao = LanguageModelSession(instructions: """
            Escreves a frase do topo do widget de uma app de tarefas pessoal, em português \
            europeu (de Portugal, nunca do Brasil). Resume numa só frase curta o que importa \
            hoje, com calma e calor, como um amigo organizado. Sem emojis, sem pontos de \
            exclamação. Usa só os factos dados; não inventes nada.
            """)
        var factos = ["Pontos ativos: \(resumo.totalAtivos)", "Expiram hoje: \(resumo.expiramHoje)"]
        for ponto in resumo.pontos {
            factos.append("- \(ponto.titulo) (\(ponto.lista)): \(ponto.razao)")
        }
        do {
            let resposta = try await sessao.respond(
                to: factos.joined(separator: "\n"),
                generating: FraseWidget.self,
                options: GenerationOptions(temperature: 0.5)
            )
            let texto = resposta.content.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            return texto.isEmpty || texto.count > 80 ? nil : texto
        } catch {
            return nil
        }
    }

    @Generable
    struct FraseParaTi {
        @Guide(description: "Uma frase curta em português europeu, com no máximo 90 caracteres")
        var texto: String
    }

    /// A frase do cartão "Para ti" do Início (DESIGN.md 7.21): interpreta o que importa agora,
    /// a partir dos factos que o núcleo escolheu, e sugere o passo seguinte.
    static func fraseParaTi(_ paraTi: ParaTi) async -> String? {
        guard disponivel else { return nil }
        let sessao = LanguageModelSession(instructions: """
            Escreves o cartão "Para ti" de uma app de tarefas pessoal, em português europeu (de \
            Portugal, nunca do Brasil), tratando a pessoa por tu. Numa só frase curta (cabe em \
            duas linhas), diz o que importa agora, com a hora antes dos nomes, com calma e sem pressão. Sem \
            emojis e sem pontos de exclamação. Usa só os factos dados; não inventes nada.
            """)
        do {
            let resposta = try await sessao.respond(
                to: (["Resumo: \(paraTi.fraseBase)"] + paraTi.factos).joined(separator: "\n"),
                generating: FraseParaTi.self,
                options: GenerationOptions(temperature: 0.5)
            )
            let texto = resposta.content.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            return texto.isEmpty || texto.count > 110 ? nil : texto
        } catch {
            return nil
        }
    }

    @Generable
    struct LinhaAviso {
        @Guide(description: "Uma frase curta em português europeu, com no máximo 90 caracteres")
        var texto: String
    }

    /// O corpo de uma notificação: uma frase com quando expira e o contexto mais útil.
    static func corpoAviso(_ aviso: Aviso, base: String) async -> String? {
        guard disponivel else { return nil }
        let sessao = LanguageModelSession(instructions: """
            Escreves o corpo de uma notificação de uma app de tarefas pessoal, em português \
            europeu (de Portugal, nunca do Brasil). O item vai expirar e a pessoa pode mantê-lo. \
            Escreve uma só frase curta, concreta e calma, que diga quando expira e junte o \
            contexto mais útil. Sem emojis, sem pontos de exclamação e sem repetir o título. \
            Usa só os factos dados; não inventes nada.
            """)
        var factos = ["Item: \(aviso.titulo)", "Resumo: \(base)"]
        if let lista = aviso.lista {
            factos.append("Lista: \(lista)")
        }
        if aviso.subtopicosPorFazer > 0 {
            factos.append("Subtópicos por fazer: \(aviso.subtopicosPorFazer)")
        }
        if let parado = TextoAviso.diasParado(aviso) {
            factos.append("Dias desde a última ação: \(parado)")
        }
        do {
            let resposta = try await sessao.respond(
                to: factos.joined(separator: "\n"),
                generating: LinhaAviso.self,
                options: GenerationOptions(temperature: 0.4)
            )
            let texto = resposta.content.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            return texto.isEmpty || texto.count > 140 ? nil : texto
        } catch {
            return nil
        }
    }
}
