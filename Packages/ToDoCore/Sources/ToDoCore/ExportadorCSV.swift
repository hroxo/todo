import Foundation

/// Exportação de listas em CSV (Melhoria 4). Uma linha por item principal, com os
/// subtópicos numa só coluna. As fotos não entram, só a contagem: o formato completo é o
/// backup JSON.
///
/// O separador é `;`, como na importação (especificação 7): o Excel em português usa `;`
/// e abriria um CSV com vírgulas todo na primeira coluna. O ficheiro leva BOM para o Excel
/// ler os acentos em UTF-8.
public enum ExportadorCSV {
    public static let separador = ";"
    public static let colunas = [
        "lista", "titulo", "estado", "criado_em", "ultima_acao", "expira_em",
        "concluido_em", "fixado", "subtopicos", "n_fotos",
    ]

    private static let bom = "\u{FEFF}"
    private static let fimDeLinha = "\r\n"

    /// O ficheiro: UTF-8 com BOM.
    public static func dados(_ listas: [Lista], calendario: Calendar = .current) -> Data {
        Data((bom + texto(listas, calendario: calendario)).utf8)
    }

    /// O texto CSV, sem BOM: o cabeçalho e os itens de cada lista, pela ordem das listas.
    /// Dentro de cada lista: ativos, concluídos e expirados, cada grupo pela sua ordem.
    public static func texto(_ listas: [Lista], calendario: Calendar = .current) -> String {
        let datas = ISO8601DateFormatter()
        datas.timeZone = calendario.timeZone
        datas.formatOptions = [.withInternetDateTime]

        var linhas = [colunas.joined(separator: separador)]
        for lista in listas.sorted(by: { $0.ordem < $1.ordem }) {
            for item in ordenados(lista.itens) {
                linhas.append(linha(item, lista: lista, datas: datas))
            }
        }
        return linhas.joined(separator: fimDeLinha) + fimDeLinha
    }

    /// "ToDo-Trabalho-2026-10-22.csv", ou "ToDo-tudo-…" sem lista. Tira do nome os caracteres
    /// que os sistemas de ficheiros não aceitam.
    public static func nomeFicheiro(lista: String?, data: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: data)
        let dia = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let proibidos = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let nome = (lista ?? "tudo")
            .components(separatedBy: proibidos)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return "ToDo-\(nome.isEmpty ? "lista" : nome)-\(dia).csv"
    }

    /// Um campo: entre aspas quando tem o separador, aspas ou quebras de linha; as aspas
    /// dobram-se (RFC 4180).
    static func campo(_ texto: String) -> String {
        let especiais = CharacterSet(charactersIn: separador + "\"\r\n")
        guard texto.rangeOfCharacter(from: especiais) != nil else { return texto }
        return "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func ordenados(_ itens: [Item]) -> [Item] {
        let posicao: [EstadoItem: Int] = [.ativo: 0, .concluido: 1, .expirado: 2]
        return itens
            .filter { !$0.ehSubtopico }
            .sorted { (posicao[$0.estado] ?? 0, $0.ordem) < (posicao[$1.estado] ?? 0, $1.ordem) }
    }

    private static func linha(_ item: Item, lista: Lista, datas: ISO8601DateFormatter) -> String {
        func data(_ valor: Date?) -> String { valor.map { datas.string(from: $0) } ?? "" }
        let subtopicos = item.subtopicosOrdenados
            .map { ($0.estado == .concluido ? "[x] " : "[ ] ") + $0.titulo }
            .joined(separator: "; ")
        return [
            lista.nome,
            item.titulo,
            item.estado.rawValue,
            data(item.criadoEm),
            data(item.ultimaAcaoEm),
            data(item.expiraEm),
            data(item.concluidoEm),
            item.fixado ? "sim" : "nao",
            subtopicos,
            String(item.fotos.count),
        ]
        .map(campo)
        .joined(separator: separador)
    }
}
