import CoreTransferable
import SwiftUI
import ToDoCore
import UniformTypeIdentifiers

/// Ficheiro CSV para a folha de partilha (Melhoria 4). É escrito num ficheiro temporário
/// com o nome certo só quando se partilha.
struct FicheiroCSV: Transferable {
    let nome: String
    let dados: Data

    /// Uma lista, ou todas quando `lista` é nil.
    init(listas: [Lista], lista: Lista? = nil, agora: Date = .now) {
        nome = ExportadorCSV.nomeFicheiro(lista: lista?.nome, data: agora)
        dados = ExportadorCSV.dados(lista.map { [$0] } ?? listas)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { ficheiro in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(ficheiro.nome)
            try ficheiro.dados.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// "Exportar CSV": abre a folha de partilha com o ficheiro.
struct BotaoExportarCSV<Rotulo: View>: View {
    let ficheiro: FicheiroCSV
    @ViewBuilder var rotulo: () -> Rotulo

    var body: some View {
        ShareLink(item: ficheiro, preview: SharePreview(ficheiro.nome, image: Image(systemName: "tablecells"))) {
            rotulo()
        }
    }
}
