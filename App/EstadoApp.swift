import Observation
import SwiftUI
import ToDoCore

/// Estado partilhado pelos ecrãs: separador ativo, captura rápida e a lista aberta.
@Observable
final class EstadoApp {
    enum Separador: Hashable {
        case listas, concluidos, expirados, definicoes
    }

    var separador: Separador = .listas
    /// Navegação do separador Listas (Lista → Detalhe).
    var caminho = NavigationPath()
    var mostrarCaptura = false
    /// Nova lista no menu do "+" (manter premido): abre o formulário.
    var mostrarNovaLista = false
    /// Fecho do dia: pela notificação, pelo Glassy no Início ou pelo widget (todo://fecho).
    var mostrarFecho = false
    /// Quando fechaste o dia; aqui para o Glassy tirar o convite logo, e gravado para os avisos e o widget.
    var fechoFeitoEm = Notificacoes.fechoFeitoEm {
        didSet { Notificacoes.fechoFeitoEm = fechoFeitoEm }
    }
    /// Só para o modo de demonstração: o Início abre na última página (a do "Nova lista").
    var irParaUltimaPagina = false
    /// Só para o modo de demonstração: abre Personalizar lista no Início.
    var abrirPersonalizar = false
    /// Só para o modo de demonstração: desce até ao calendário no Início.
    var rolarParaCalendario = false
    /// Só para o modo de demonstração: abre um evento do calendário.
    var abrirEventoDemo = false
    /// Só para o modo de demonstração: abre o questionário neste passo.
    var questionarioDemo: QuestionarioView.Passo?
    /// Só para o modo de demonstração: mostra as vistas dos widgets.
    var demoWidgets = false
    /// A lista que está aberta, para a captura rápida a pré-selecionar.
    var listaAtual: Lista?
    /// Filtros de Concluídos e Expirados: independentes e só enquanto a app está aberta.
    var filtroConcluidos = FiltroItens()
    var filtroExpirados = FiltroItens()
    /// Mensagem depois de abrir uma lista partilhada (DESIGN.md 7.15).
    var avisoPartilha: String?
    /// Muda quando o dia fica ganho: os confettis aparecem em qualquer ecrã (DESIGN.md 7.22).
    var festa: UUID?

    @ObservationIgnored let notificacoes: Notificacoes

    init(notificacoes: Notificacoes) {
        self.notificacoes = notificacoes
    }

    func reagendarAvisos() {
        notificacoes.reagendar()
    }
}
