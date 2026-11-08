import Foundation
import SwiftData

/// Backup de tudo num ficheiro JSON (especificação 8, DESIGN.md 7.19): listas, itens,
/// subtópicos, fotos e definições, com a versão do formato para o esquema poder evoluir. É o
/// mesmo ficheiro para exportar à mão, para o backup automático e, com a conta paga, para o
/// iCloud Drive: o destino é escolhido pela app, não pelo formato.
public struct Backup: Codable, Equatable, Sendable {
    public static let versaoAtual = 1
    public static let extensao = "json"

    public var versaoFormato = Self.versaoAtual
    public var criadoEm: Date
    public var definicoes: Definicoes
    public var listas: [ListaB]
    /// Os dias do widget "O teu ritmo"; nil em backups de antes do histórico. Ao restaurar, a
    /// app junta-o ao do aparelho (`HistoricoDias.juntado`), sem apagar dias.
    public var historico: HistoricoDias?

    public struct ListaB: Codable, Equatable, Sendable {
        public var id: UUID
        public var nome: String
        public var cor: String
        public var ordem: Int
        public var icone: String
        public var emoji: String?
        public var tipo: String
        public var partilhaId: UUID?
        public var permanente: Bool
        public var vaziaDesde: Date?
        public var itens: [ItemB]
    }

    public struct ItemB: Codable, Equatable, Sendable {
        public var id: UUID
        public var titulo: String
        public var tipo: String
        public var estado: String
        public var fixado: Bool
        public var criadoEm: Date
        public var ultimaAcaoEm: Date
        public var expiraEm: Date?
        public var expiradoEm: Date?
        public var concluidoEm: Date?
        public var ordem: Int
        public var nota: String?
        public var eventoId: String?
        public var eventoInicio: Date?
        public var alteradoEm: Date?
        public var apagadoEm: Date?
        public var subtopicos: [ItemB]
        public var fotos: [FotoB]

        /// A data que decide quem ganha ao juntar: a última alteração, ou a última ação.
        var mudouEm: Date { alteradoEm ?? ultimaAcaoEm }
    }

    public struct FotoB: Codable, Equatable, Sendable {
        public var id: UUID
        /// JPEG; no JSON fica em base64.
        public var dados: Data
        public var ordem: Int
        public var criadaEm: Date
    }

    public var totalItens: Int {
        listas.reduce(0) { $0 + $1.itens.count }
    }

    public func dados() throws -> Data {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        codificador.outputFormatting = [.sortedKeys]
        return try codificador.encode(self)
    }

    public static func ler(_ dados: Data) throws -> Backup {
        let descodificador = JSONDecoder()
        descodificador.dateDecodingStrategy = .iso8601
        let backup: Backup
        do {
            backup = try descodificador.decode(Backup.self, from: dados)
        } catch {
            throw ErroBackup.ficheiroInvalido
        }
        guard backup.versaoFormato <= versaoAtual else { throw ErroBackup.versaoDesconhecida }
        return backup
    }

    /// "ToDo-backup-2026-10-28.json".
    public static func nomeFicheiro(_ data: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: data)
        return String(format: "ToDo-backup-%04d-%02d-%02d.json", c.year!, c.month!, c.day!)
    }
}

public enum ErroBackup: Error, Equatable {
    case ficheiroInvalido
    /// O ficheiro vem de uma versão da app mais recente.
    case versaoDesconhecida
}

/// O que um restauro faz (ou faria, em simulação): mostra-se antes de confirmar.
public struct ResumoRestauro: Equatable, Sendable {
    public var listasNovas = 0
    public var listasJuntas = 0
    public var itensNovos = 0
    public var itensAtualizados = 0
    /// Listas locais vazias que saem para as do backup caberem nas `Tarefas.maxListas`.
    public var listasVaziasRetiradas = 0

    public var nadaMuda: Bool { listasNovas == 0 && itensNovos == 0 && itensAtualizados == 0 }
}

extension Tarefas {
    public func criarBackup(historico: HistoricoDias? = nil) throws -> Backup {
        func item(_ i: Item) -> Backup.ItemB {
            Backup.ItemB(
                id: i.id, titulo: i.titulo, tipo: i.tipoRaw, estado: i.estadoRaw, fixado: i.fixado,
                criadoEm: i.criadoEm, ultimaAcaoEm: i.ultimaAcaoEm, expiraEm: i.expiraEm,
                expiradoEm: i.expiradoEm, concluidoEm: i.concluidoEm, ordem: i.ordem, nota: i.nota,
                eventoId: i.eventoId, eventoInicio: i.eventoInicio, alteradoEm: i.alteradoEm,
                apagadoEm: i.apagadoEm,
                subtopicos: i.subtopicos.sorted { $0.ordem < $1.ordem }.map(item),
                fotos: i.fotosOrdenadas.map { Backup.FotoB(id: $0.id, dados: $0.dados, ordem: $0.ordem, criadaEm: $0.criadaEm) }
            )
        }
        return Backup(
            criadoEm: relogio.agora,
            definicoes: definicoes,
            listas: try listas().map { l in
                Backup.ListaB(
                    id: l.id, nome: l.nome, cor: l.corRaw, ordem: l.ordem, icone: l.icone, emoji: l.emoji,
                    tipo: l.tipoRaw, partilhaId: l.partilhaId, permanente: l.permanente, vaziaDesde: l.vaziaDesde,
                    itens: l.itens.sorted { $0.ordem < $1.ordem }.map(item)
                )
            },
            historico: historico
        )
    }

    /// Junta o backup ao que já existe, sem apagar nada (especificação 8):
    /// - cada lista junta-se à que tem o mesmo id ou, sem ela, o mesmo nome (numa instalação
    ///   nova, o "Trabalho" criado de raiz recebe o do backup em vez de ficar duplicado);
    /// - cada item, subtópico ou foto entra se não existir; se existir, ganha a versão alterada
    ///   mais recentemente.
    /// Com `aplicar` falso só conta, para o resumo antes de confirmar. As definições do backup
    /// ficam para a app aplicar (vivem fora da base de dados, ver `Definicoes.aoRestaurar`).
    /// Se as listas não couberem, recusa antes de mudar seja o que for (`limiteListas`); numa
    /// instalação nova, as listas locais sem nada lá dentro dão lugar às do backup.
    @discardableResult
    public func restaurar(_ backup: Backup, aplicar: Bool = true) throws -> ResumoRestauro {
        var resumo = ResumoRestauro()
        let existentes = try listas()
        var itensPorId = Dictionary(
            try contexto.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        let fotosIds = Set(try contexto.fetch(FetchDescriptor<Foto>()).map(\.id))
        let chave: (String) -> String = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let correspondente: (Backup.ListaB) -> Lista? = { b in
            existentes.first { $0.id == b.id } ?? existentes.first { chave($0.nome) == chave(b.nome) }
        }

        let novas = backup.listas.filter { correspondente($0) == nil }.count
        let excesso = existentes.count + novas - Self.maxListas
        if novas > 0 && excesso > 0 {
            let usadas = Set(backup.listas.compactMap { correspondente($0)?.id })
            let vazias = existentes.filter { $0.itens.isEmpty && !usadas.contains($0.id) }
            guard vazias.count >= excesso else { throw ErroTarefas.limiteListas }
            resumo.listasVaziasRetiradas = excesso
            if aplicar {
                for lista in vazias.prefix(excesso) {
                    contexto.delete(lista)
                }
            }
        }

        func restaurarItem(_ b: Backup.ItemB, lista: Lista?, pai: Item?) {
            let item: Item?
            if let local = itensPorId[b.id] {
                item = local
                if b.mudouEm > (local.alteradoEm ?? local.ultimaAcaoEm) {
                    resumo.itensAtualizados += 1
                    if aplicar {
                        copiar(b, para: local)
                        if pai == nil { darTempo(a: local) }
                    }
                }
            } else {
                resumo.itensNovos += 1
                if aplicar {
                    let novo = Item(id: b.id, titulo: b.titulo, tipo: TipoItem(rawValue: b.tipo) ?? .tarefa, criadoEm: b.criadoEm, ordem: b.ordem)
                    contexto.insert(novo)
                    copiar(b, para: novo)
                    if let pai {
                        novo.pai = pai
                    } else {
                        novo.lista = lista
                        darTempo(a: novo)
                    }
                    itensPorId[b.id] = novo
                    item = novo
                } else {
                    item = nil
                }
            }
            if aplicar, let item {
                for foto in b.fotos where !fotosIds.contains(foto.id) {
                    let nova = Foto(id: foto.id, dados: foto.dados, ordem: foto.ordem, criadaEm: foto.criadaEm)
                    contexto.insert(nova)
                    nova.item = item
                }
            }
            for sub in b.subtopicos {
                restaurarItem(sub, lista: nil, pai: item)
            }
        }

        for listaB in backup.listas.sorted(by: { $0.ordem < $1.ordem }) {
            var lista = correspondente(listaB)
            if lista == nil {
                resumo.listasNovas += 1
                if aplicar {
                    let nova = Lista(
                        id: listaB.id, nome: listaB.nome, cor: CorLista.deChave(listaB.cor),
                        ordem: (try listas().map(\.ordem).max() ?? -1) + 1,
                        icone: listaB.icone, emoji: listaB.emoji
                    )
                    nova.tipoRaw = listaB.tipo
                    nova.partilhaId = listaB.partilhaId
                    nova.permanente = listaB.permanente
                    // A contagem recomeça: num backup antigo já teria passado, e a lista saía logo.
                    nova.vaziaDesde = listaB.vaziaDesde == nil ? nil : relogio.agora
                    contexto.insert(nova)
                    lista = nova
                }
            } else {
                resumo.listasJuntas += 1
            }
            for item in listaB.itens {
                restaurarItem(item, lista: lista, pai: nil)
            }
        }
        return resumo
    }

    /// "Nada é apagado" tem de valer também na abertura seguinte: num backup antigo, os prazos e
    /// as retenções já passaram, e sem isto `avaliar` apagava o que acabou de voltar. Só toca no
    /// que já venceu; o resto fica com as datas do backup.
    private func darTempo(a item: Item) {
        let agora = relogio.agora
        if item.estado == .ativo, !item.fixado, let limite = item.expiraEm, agora >= limite {
            item.ultimaAcaoEm = agora
            item.expiraEm = daquiA(definicoes.diasExpiracao, desde: agora)
        }
        if let fim = fimDaRetencao(de: item), agora >= fim {
            if item.estado == .expirado {
                item.expiradoEm = agora
            } else {
                item.concluidoEm = agora
            }
        }
    }

    private func copiar(_ b: Backup.ItemB, para item: Item) {
        item.titulo = b.titulo
        item.tipoRaw = b.tipo
        item.estadoRaw = b.estado
        item.fixado = b.fixado
        item.criadoEm = b.criadoEm
        item.ultimaAcaoEm = b.ultimaAcaoEm
        item.expiraEm = b.expiraEm
        item.expiradoEm = b.expiradoEm
        item.concluidoEm = b.concluidoEm
        item.ordem = b.ordem
        item.nota = b.nota
        item.eventoId = b.eventoId
        item.eventoInicio = b.eventoInicio
        item.alteradoEm = b.alteradoEm
        item.apagadoEm = b.apagadoEm
    }
}
