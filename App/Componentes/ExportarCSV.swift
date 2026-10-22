import SwiftUI
import ToDoCore
import UIKit

/// Exportar CSV pela partilha normal do iPhone (Melhoria 4): escreve o ficheiro
/// `ToDo-<lista>-<AAAA-MM-DD>.csv` numa pasta temporária e abre a folha de partilha do
/// sistema. "Guardar em Ficheiros" descarrega-o como CSV; também há AirDrop, Mail, Numbers…
enum PartilhaCSV {
    /// Uma lista, ou todas quando `lista` é nil.
    @MainActor
    static func partilhar(listas: [Lista], lista: Lista? = nil) {
        guard let url = escrever(listas: listas, lista: lista) else { return }
        // Deixa o menu "…" fechar antes de abrir a folha.
        DispatchQueue.main.async {
            guard let topo = controladorDoTopo() else { return }
            let folha = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            folha.popoverPresentationController?.sourceView = topo.view
            topo.present(folha, animated: true)
        }
    }

    private static func escrever(listas: [Lista], lista: Lista?) -> URL? {
        let gestor = FileManager.default
        // Uma pasta só para isto, limpa a cada exportação, para não acumular ficheiros.
        let pasta = gestor.temporaryDirectory.appendingPathComponent("Exportar", isDirectory: true)
        try? gestor.removeItem(at: pasta)
        guard (try? gestor.createDirectory(at: pasta, withIntermediateDirectories: true)) != nil else { return nil }
        let url = pasta.appendingPathComponent(ExportadorCSV.nomeFicheiro(lista: lista?.nome, data: .now))
        let dados = ExportadorCSV.dados(lista.map { [$0] } ?? listas)
        guard (try? dados.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    @MainActor
    private static func controladorDoTopo() -> UIViewController? {
        let janela = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        var topo = janela?.rootViewController
        while let apresentado = topo?.presentedViewController {
            topo = apresentado
        }
        return topo
    }
}
