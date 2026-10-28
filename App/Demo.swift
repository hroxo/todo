import SwiftData
import SwiftUI
import ToDoCore
import UIKit

/// Modo de demonstração para as capturas de ecrã do CI. Só se liga com o argumento de
/// arranque `-demo YES`: base de dados em memória com dados parecidos com os dos mocks, sem
/// notificações. `-ecra <nome>` abre um ecrã, `-manter <fase>` mostra um estado do Manter e
/// `-calendario ligar` mostra o calendário por ligar (por defeito, ligado com eventos de exemplo).
enum Demo {
    static var ativo: Bool { UserDefaults.standard.bool(forKey: "demo") }
    static var ecra: String? { UserDefaults.standard.string(forKey: "ecra") }
    static var faseManter: String? { ativo ? UserDefaults.standard.string(forKey: "manter") : nil }

    private struct RelogioDemo: Relogio {
        let agora: Date
    }

    /// Tarefas com o relógio recuado, para os anéis aparecerem em vários pontos.
    private static func tarefas(_ contexto: ModelContext, horasAtras: Double) -> Tarefas {
        Tarefas(
            contexto: contexto,
            relogio: RelogioDemo(agora: Date.now.addingTimeInterval(-horasAtras * 3600)),
            definicoes: Definicoes()
        )
    }

    static func povoar(_ contexto: ModelContext) {
        let t = tarefas(contexto, horasAtras: 0)
        guard let trabalho = try? t.criarLista(nome: "Trabalho", cor: .azul, icone: "briefcase.fill"),
              let pessoal = try? t.criarLista(nome: "Pessoal", cor: .roxo, icone: "person.fill"),
              let ideias = try? t.criarLista(nome: "Ideias", cor: .amarelo, icone: "lightbulb.fill"),
              let casa = try? t.criarLista(nome: "Casa", cor: .verde, icone: "house.fill"),
              let ginasio = try? t.criarLista(nome: "Ginásio", cor: .vermelho, icone: "dumbbell.fill"),
              let viagem = try? t.criarLista(nome: "Viagem", cor: .ceu, icone: "airplane"),
              let compras = try? t.criarLista(nome: "Compras", cor: .turquesa, icone: "cart.fill", tipo: .compras)
        else { return }

        func item(_ titulo: String, _ lista: Lista, horas: Double, tipo: TipoItem = .tarefa) -> Item? {
            try? tarefas(contexto, horasAtras: horas).criarItem(titulo: titulo, em: lista, tipo: tipo)
        }

        // Trabalho
        if let fixo = item("Revisão semanal do backlog", trabalho, horas: 10) {
            t.definirFixado(fixo, true)
        }
        if let roadmap = item("Rever proposta do roadmap Q1", trabalho, horas: 24) {
            let antes = tarefas(contexto, horasAtras: 24)
            for (titulo, feito) in [
                ("Ler a versão do Pedro", true),
                ("Comparar com o OKR de retenção", true),
                ("Anotar dúvidas de dependências", false),
                ("Enviar comentários", false),
            ] {
                if let sub = try? antes.adicionarSubtopico(titulo: titulo, a: roadmap), feito {
                    antes.alternarSubtopico(sub)
                }
            }
            _ = try? antes.adicionarFoto(foto(.systemBlue), a: roadmap)
            _ = try? antes.adicionarFoto(foto(.systemOrange), a: roadmap)
            antes.definirNota(roadmap, "Focar nas dependências com a equipa de dados. O Pedro quer resposta até sexta.")
        }
        _ = item("Responder ao fornecedor", trabalho, horas: 1)
        if let demo = item("Preparar demo de sexta", trabalho, horas: 56) {
            let antes = tarefas(contexto, horasAtras: 56)
            for titulo in ["Guião", "Dados de exemplo", "Ensaio"] {
                _ = try? antes.adicionarSubtopico(titulo: titulo, a: demo)
            }
        }
        if let retro = item("Quadro da retro", trabalho, horas: 60, tipo: .notaRapida) {
            _ = try? tarefas(contexto, horasAtras: 60).adicionarFoto(foto(.systemPurple), a: retro)
        }
        _ = item("Marcar 1:1 com a equipa", trabalho, horas: 20)

        // Pessoal
        if let seguro = item("Renovar seguro do carro", pessoal, horas: 30) {
            t.definirFixado(seguro, true)
        }
        _ = item("Ligar ao canalizador por causa da fuga", pessoal, horas: 5, tipo: .notaRapida)
        _ = item("Comprar prenda da Ana", pessoal, horas: 30)
        _ = item("Marcar ginásio", pessoal, horas: 44)

        // Ideias
        _ = item("Ideia: métrica de abandono", ideias, horas: 62, tipo: .notaRapida)
        _ = item("App de receitas com fotos", ideias, horas: 8, tipo: .notaRapida)

        // Mais espaços, para as setas de página.
        _ = item("Trocar a lâmpada da cozinha", casa, horas: 12)
        _ = item("Pagar o condomínio", casa, horas: 40)
        _ = item("Renovar inscrição", ginasio, horas: 20)
        _ = item("Reservar hotel em Lisboa", viagem, horas: 6)

        // Permanentes (no máximo 4) e uma lista vazia há 2 dias, que sai daqui a 3 (DESIGN.md 7.17).
        for lista in [trabalho, pessoal, ideias, casa] {
            try? t.definirPermanente(lista, true)
        }
        if let leituras = try? t.criarLista(nome: "Leituras", cor: .indigo, icone: "book.fill") {
            leituras.vaziaDesde = Date.now.addingTimeInterval(-2 * 86_400)
        }

        // Compras: lojas com artigos, alguns já no carrinho (DESIGN.md 7.15).
        for (loja, artigos) in [
            ("Continente", [("Leite", true), ("Pão", true), ("Peixe", false), ("Fruta", false), ("Café", false)]),
            ("IKEA", [("Candeeiro de pé", false), ("Parafusos", true), ("Cabides", false)]),
        ] {
            guard let loja = try? t.criarItem(titulo: loja, em: compras) else { continue }
            for (titulo, feito) in artigos {
                if let artigo = try? t.adicionarSubtopico(titulo: titulo, a: loja), feito {
                    t.alternarSubtopico(artigo)
                }
            }
        }

        // Expirados: criados há mais de 3 dias, expiram na avaliação abaixo.
        _ = item("Comprar pilhas para o comando", pessoal, horas: 24 * 4)
        _ = item("Ideia: modo foco à sexta", ideias, horas: 24 * 8, tipo: .notaRapida)
        _ = item("Atualizar slides da retro", trabalho, horas: 24 * 11)
        _ = item("Ver horários do ginásio", pessoal, horas: 24 * 15)

        // Concluídos
        if let relatorio = item("Enviar relatório mensal", trabalho, horas: 30) {
            tarefas(contexto, horasAtras: 2).concluir(relatorio)
        }
        if let dentista = item("Marcar dentista", pessoal, horas: 50) {
            tarefas(contexto, horasAtras: 26).concluir(dentista)
        }

        _ = try? t.avaliar()
        try? contexto.save()
    }

    /// Abre o ecrã pedido em `-ecra`.
    @MainActor
    static func abrir(estado: EstadoApp, contexto: ModelContext) {
        guard ativo, let ecra else { return }
        let listas = (try? Tarefas(contexto: contexto, definicoes: Definicoes()).listas()) ?? []
        guard let trabalho = listas.first else { return }

        switch ecra {
        case "lista":
            estado.caminho.append(trabalho)
        case "compras":
            if let compras = listas.first(where: \.ehCompras) {
                estado.caminho.append(compras)
            }
        case "detalhe":
            if let roadmap = trabalho.itensAtivos.first(where: { $0.titulo.hasPrefix("Rever proposta") }) {
                estado.caminho.append(trabalho)
                estado.caminho.append(roadmap)
            }
        case "captura":
            estado.listaAtual = listas.dropFirst().first
            estado.mostrarCaptura = true
        case "widget":
            estado.demoWidgets = true
        case "personalizar":
            estado.abrirPersonalizar = true
        case "calendario":
            estado.rolarParaCalendario = true
        case "evento":
            estado.rolarParaCalendario = true
            estado.abrirEventoDemo = true
        case "expirados":
            estado.separador = .expirados
        case "expirados-filtro":
            estado.filtroExpirados = FiltroItens(listaId: listas.dropFirst().first?.id, periodo: .ultimos7)
            estado.separador = .expirados
        case "concluidos":
            estado.separador = .concluidos
        case "definicoes":
            estado.separador = .definicoes
        default:
            break
        }
    }

    private static func foto(_ cor: UIColor) -> Data {
        let tamanho = CGSize(width: 600, height: 600)
        return UIGraphicsImageRenderer(size: tamanho).jpegData(withCompressionQuality: 0.8) { contexto in
            cor.setFill()
            contexto.fill(CGRect(origin: .zero, size: tamanho))
            UIColor.white.withAlphaComponent(0.35).setFill()
            contexto.cgContext.fillEllipse(in: CGRect(x: 150, y: 150, width: 300, height: 300))
        }
    }
}
