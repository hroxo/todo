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
    /// Só para o modo de demonstração: abre um evento do calendário.
    var abrirEventoDemo = false
    /// Só para o modo de demonstração: mostra as vistas dos widgets.
    var demoWidgets = false
    /// Os avisos do topo do Início (Expirados e "expiram hoje") só aparecem na primeira vez que
    /// se abre o Início; saem ao trocar de página, ao tocar neles ou ao entrar numa lista.
    /// Voltam quando a app regressa do segundo plano.
    var avisosDispensados = false
    /// A lista que está aberta, para a captura rápida a pré-selecionar.
    var listaAtual: Lista?
    /// Filtros de Concluídos e Expirados: independentes e só enquanto a app está aberta.
    var filtroConcluidos = FiltroItens()
    var filtroExpirados = FiltroItens()
    /// Mensagem depois de abrir uma lista partilhada (DESIGN.md 7.15).
    var avisoPartilha: String?

    @ObservationIgnored let notificacoes: Notificacoes

    init(notificacoes: Notificacoes) {
        self.notificacoes = notificacoes
    }

    func reagendarAvisos() {
        notificacoes.reagendar()
    }
}
