import Observation
import SwiftUI
import ToDoCore

/// Estado partilhado pelos ecrãs: separador ativo, captura rápida e a lista aberta.
@Observable
final class EstadoApp {
    enum Separador: Hashable {
        case listas, concluidos, expirados, definicoes, captura
    }

    var separador: Separador = .listas
    /// Navegação do separador Listas (Lista → Detalhe).
    var caminho = NavigationPath()
    var mostrarCaptura = false
    /// Só para o modo de demonstração: abre Personalizar lista no Início.
    var abrirPersonalizar = false
    /// Só para o modo de demonstração: desce até ao calendário no Início.
    var rolarParaCalendario = false
    /// A lista que está aberta, para a captura rápida a pré-selecionar.
    var listaAtual: Lista?

    @ObservationIgnored let notificacoes: Notificacoes

    init(notificacoes: Notificacoes) {
        self.notificacoes = notificacoes
    }

    func reagendarAvisos() {
        notificacoes.reagendar()
    }
}
