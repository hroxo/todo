import Foundation
import SwiftData

/// Uma lista de compras num ficheiro `.todolista` (DESIGN.md 7.15), para a partilhar por
/// AirDrop. Leva as lojas, os artigos e as lápides dos apagados, cada um com a hora da última
/// alteração, para o outro iPhone a juntar à sua cópia.
public struct ListaPartilhada: Codable, Equatable, Sendable {
    public static let versaoAtual = 1
    public static let extensao = "todolista"

    public var versaoFormato = Self.versaoAtual
    public var partilhaId: UUID
    public var nome: String
    public var cor: String
    public var icone: String
    public var emoji: String?
    public var lojas: [Loja]

    public struct Loja: Codable, Equatable, Sendable {
        public var id: UUID
        public var titulo: String
        public var ordem: Int
        public var alteradoEm: Date
        public var apagadoEm: Date?
        public var artigos: [Artigo]
    }

    public struct Artigo: Codable, Equatable, Sendable {
        public var id: UUID
        public var titulo: String
        public var ordem: Int
        public var feito: Bool
        public var alteradoEm: Date
        public var apagadoEm: Date?
    }

    public func dados() throws -> Data {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try codificador.encode(self)
    }

    public static func ler(_ dados: Data) throws -> ListaPartilhada {
        let descodificador = JSONDecoder()
        descodificador.dateDecodingStrategy = .iso8601
        let lida = try descodificador.decode(ListaPartilhada.self, from: dados)
        guard lida.versaoFormato <= versaoAtual else { throw ErroPartilha.versaoDesconhecida }
        return lida
    }
}

public enum ErroPartilha: Error, Equatable {
    /// O ficheiro vem de uma versão da app mais recente.
    case versaoDesconhecida
    case naoEDeCompras
}

/// O que aconteceu ao abrir um ficheiro partilhado.
public struct ResultadoJuntar {
    public let lista: Lista
    /// Verdadeiro se a lista ainda não existia neste iPhone.
    public let nova: Bool
    /// Lojas e artigos novos ou atualizados.
    public let alterados: Int
}

extension Tarefas {
    /// A lista pronta a enviar. Na primeira partilha ganha o `partilhaId`, que as cópias
    /// guardam para se reconhecerem.
    public func paraPartilhar(_ lista: Lista) throws -> ListaPartilhada {
        guard lista.ehCompras else { throw ErroPartilha.naoEDeCompras }
        let id = lista.partilhaId ?? UUID()
        lista.partilhaId = id
        let lojas = lista.itens.sorted { $0.ordem < $1.ordem }.map { loja in
            ListaPartilhada.Loja(
                id: loja.id,
                titulo: loja.titulo,
                ordem: loja.ordem,
                alteradoEm: loja.alteradoEm ?? loja.criadoEm,
                apagadoEm: loja.apagadoEm,
                artigos: loja.subtopicos.sorted { $0.ordem < $1.ordem }.map { artigo in
                    ListaPartilhada.Artigo(
                        id: artigo.id,
                        titulo: artigo.titulo,
                        ordem: artigo.ordem,
                        feito: artigo.estado == .concluido,
                        alteradoEm: artigo.alteradoEm ?? artigo.criadoEm,
                        apagadoEm: artigo.apagadoEm
                    )
                }
            )
        }
        return ListaPartilhada(
            partilhaId: id,
            nome: lista.nome,
            cor: lista.corRaw,
            icone: lista.icone,
            emoji: lista.emoji,
            lojas: lojas
        )
    }

    /// Cria a lista recebida ou junta-a à cópia que já existe (mesmo `partilhaId`). Por cada
    /// loja e artigo, ganha a alteração mais recente; as lápides também contam, para o que
    /// foi apagado num lado não voltar. Não conta como ação: mantém as horas de quem mudou.
    @discardableResult
    public func juntar(_ recebida: ListaPartilhada) throws -> ResultadoJuntar {
        let existente = try listas().first { $0.partilhaId == recebida.partilhaId }
        let lista: Lista
        if let existente {
            lista = existente
        } else {
            lista = try criarLista(
                nome: recebida.nome,
                cor: CorLista.deChave(recebida.cor),
                icone: recebida.icone,
                emoji: recebida.emoji,
                tipo: .compras
            )
            lista.partilhaId = recebida.partilhaId
        }

        var alterados = 0
        for loja in recebida.lojas {
            let local: Item
            if let encontrada = lista.itens.first(where: { $0.id == loja.id }) {
                local = encontrada
                if loja.alteradoEm > (local.alteradoEm ?? .distantPast) {
                    local.titulo = loja.titulo
                    local.ordem = loja.ordem
                    local.apagadoEm = loja.apagadoEm
                    local.alteradoEm = loja.alteradoEm
                    alterados += 1
                }
            } else {
                local = Item(id: loja.id, titulo: loja.titulo, tipo: .tarefa, criadoEm: loja.alteradoEm, ordem: loja.ordem)
                contexto.insert(local)
                local.lista = lista
                local.apagadoEm = loja.apagadoEm
                local.alteradoEm = loja.alteradoEm
                alterados += 1
            }

            for artigo in loja.artigos {
                if let encontrado = local.subtopicos.first(where: { $0.id == artigo.id }) {
                    guard artigo.alteradoEm > (encontrado.alteradoEm ?? .distantPast) else { continue }
                    aplicar(artigo, em: encontrado)
                } else {
                    let novo = Item(id: artigo.id, titulo: artigo.titulo, tipo: .tarefa, criadoEm: artigo.alteradoEm, ordem: artigo.ordem)
                    contexto.insert(novo)
                    novo.pai = local
                    aplicar(artigo, em: novo)
                }
                alterados += 1
            }
        }
        return ResultadoJuntar(lista: lista, nova: existente == nil, alterados: alterados)
    }

    private func aplicar(_ artigo: ListaPartilhada.Artigo, em item: Item) {
        item.titulo = artigo.titulo
        item.ordem = artigo.ordem
        item.estado = artigo.feito ? .concluido : .ativo
        item.concluidoEm = artigo.feito ? (item.concluidoEm ?? artigo.alteradoEm) : nil
        item.apagadoEm = artigo.apagadoEm
        item.alteradoEm = artigo.alteradoEm
    }
}
