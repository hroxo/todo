import Foundation
import SwiftData
import ToDoCore

/// Cópias manuais em JSON (DESIGN.md 7.19): exportar para onde a pessoa quiser (iCloud Drive,
/// Ficheiros, AirDrop) e restaurar de um ficheiro. A cópia de segurança contínua é a
/// sincronização com o iCloud (SwiftData com CloudKit), quando a app tiver a conta paga; este
/// ficheiro serve para uma cópia à mão e para mudar de instalação sem perder nada.
enum Backups {
    /// O contentor CloudKit da app (o mesmo das entitlements, no dia da conta paga).
    static let contentorICloud = "iCloud.com.hugo.todo"
    private static let chaveUltimoExportado = "backupExportadoEm"

    static var ultimoExportado: Date? {
        UserDefaults.standard.object(forKey: chaveUltimoExportado) as? Date
    }

    static func marcarExportado(_ data: Date = .now) {
        UserDefaults.standard.set(data, forKey: chaveUltimoExportado)
    }

    /// Um ficheiro temporário com o backup, para a folha de partilha.
    static func paraExportar(_ contexto: ModelContext, agora: Date = .now) throws -> URL {
        let gestor = FileManager.default
        let pasta = gestor.temporaryDirectory.appendingPathComponent("Backup", isDirectory: true)
        try? gestor.removeItem(at: pasta)
        try gestor.createDirectory(at: pasta, withIntermediateDirectories: true)
        let url = pasta.appendingPathComponent(Backup.nomeFicheiro(agora))
        try Tarefas(contexto: contexto).criarBackup().dados().write(to: url, options: .atomic)
        return url
    }

    /// Lê um ficheiro escolhido pela pessoa (fora da app: precisa de acesso com âmbito).
    static func ler(_ url: URL) throws -> Backup {
        let acesso = url.startAccessingSecurityScopedResource()
        defer { if acesso { url.stopAccessingSecurityScopedResource() } }
        return try Backup.ler(Data(contentsOf: url))
    }
}
