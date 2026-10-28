import SwiftData
import SwiftUI
import ToDoCore
import UIKit

/// Fundo do Início (DESIGN.md 7.12 e 7.12b, mocks 7, 8 e 11): o cartão para ligar o calendário
/// ou os eventos de hoje, com o espaço por baixo de cada um (ou "Sem espaço") e um "+" que
/// cria o ponto. Tocar num evento abre-o (Melhoria 6.2); o "+" só funciona uma vez por
/// evento e depois passa a ✓ (Melhoria 6.4).
struct SecaoCalendario: View {
    @Environment(Calendario.self) private var calendario
    @Environment(EstadoApp.self) private var estado
    @Environment(\.modelContext) private var contexto
    @Environment(\.openURL) private var abrirURL
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @AppStorage("mostrarCalendario") private var mostrar = true
    @AppStorage("ultimaListaId") private var ultimaListaId = ""
    /// Os pontos criados a partir de eventos, para o ✓ se atualizar sozinho.
    @Query(filter: #Predicate<Item> { $0.eventoId != nil }) private var deEventos: [Item]

    @State private var confirmacao: String?
    @State private var criados = 0
    @State private var aberto: EventoHoje?
    @State private var jaAdicionado: Item?

    /// Coluna das horas de cada evento.
    private let larguraHora: CGFloat = 48

    var body: some View {
        Group {
            if calendario.mostraEventos {
                hoje
            } else if calendario.acesso == .recusado {
                cartaoRecusado
            } else {
                cartaoLigar
            }
        }
        .sensoryFeedback(.success, trigger: criados)
        .sheet(item: $aberto) { evento in
            let atual = calendario.eventos.first { $0.id == evento.id } ?? evento
            VistaEvento(
                evento: atual,
                espaco: espaco(de: atual),
                existente: existente(atual),
                criar: { criar(atual, em: $0) },
                abrir: abrir
            )
        }
        .alert(
            "Já está em \(jaAdicionado?.lista?.nome ?? "")",
            isPresented: Binding(presente: $jaAdicionado),
            presenting: jaAdicionado
        ) { item in
            Button("Abrir") { abrir(item) }
            Button("OK", role: .cancel) {}
        } message: { item in
            Text(item.estado == .concluido ? "Este evento já foi adicionado e concluído." : "Este evento já foi adicionado.")
        }
        .onChange(of: estado.abrirEventoDemo, initial: true) { _, abrir in
            guard abrir else { return }
            estado.abrirEventoDemo = false
            aberto = calendario.eventos.first { !$0.participantes.isEmpty }
        }
    }

    // MARK: - Por ligar

    private var cartaoLigar: some View {
        VStack(alignment: .leading, spacing: Espaco.grelha) {
            HStack(alignment: .top, spacing: Espaco.grelha) {
                circuloCalendario
                VStack(alignment: .leading, spacing: Espaco.minimo) {
                    Text("Junta o teu calendário")
                        .font(.headline)
                    Text("Vê os eventos de hoje por baixo das listas e cria pontos a partir deles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { mostrar = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                // O alvo de 44 pt sai um pouco do canto, para o xis ficar alinhado com o texto.
                .padding(.top, -Espaco.grelha)
                .padding(.trailing, -Espaco.grelha)
                .accessibilityLabel("Agora não")
            }

            HStack(spacing: Espaco.curto) {
                ficha("Apple", cor: .red)
                ficha("Google", cor: .green)
                ficha("Outlook", cor: .blue)
            }

            Button {
                Task { await calendario.pedirAcesso() }
            } label: {
                Text("Ligar calendário")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Text("Lê só no iPhone: usa as contas Google e Outlook que já tens nos Ajustes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(Espaco.bloco)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private var cartaoRecusado: some View {
        VStack(alignment: .leading, spacing: Espaco.grelha) {
            HStack(spacing: Espaco.grelha) {
                circuloCalendario
                VStack(alignment: .leading, spacing: Espaco.minimo) {
                    Text("Sem acesso ao calendário")
                        .font(.headline)
                    Text("Para ver os eventos aqui, dá acesso total em Ajustes › ToDo › Calendários.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                Spacer()
                Button("Agora não") {
                    withAnimation { mostrar = false }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(Espaco.bloco)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private var circuloCalendario: some View {
        Image(systemName: "calendar")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.accentColor))
            .accessibilityHidden(true)
    }

    private func ficha(_ nome: String, cor: Color) -> some View {
        HStack(spacing: Espaco.curto) {
            Circle().fill(cor).frame(width: 9, height: 9)
            Text(nome)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, Espaco.curto)
        .frame(minHeight: 30)
        .background(Color(.tertiarySystemFill), in: .capsule)
    }

    // MARK: - Ligado

    private var hoje: some View {
        TimelineView(.periodic(from: .now, by: 60)) { contexto in
            VStack(alignment: .leading, spacing: Espaco.curto) {
                HStack {
                    TituloSecao(texto: "Hoje no calendário")
                    Spacer()
                    if !calendario.eventos.isEmpty {
                        Text(calendario.eventos.count == 1 ? "1 evento" : "\(calendario.eventos.count) eventos")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if let confirmacao {
                    Label(confirmacao, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CoresEstado.concluido)
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    if calendario.eventos.isEmpty {
                        Text("Nada no calendário hoje. Em Definições › Calendários escolhes o espaço de cada calendário.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, Espaco.bloco)
                            .padding(.vertical, Espaco.curto)
                    }
                    ForEach(calendario.eventos) { evento in
                        linha(evento, agora: contexto.date)
                        if evento != calendario.eventos.last {
                            Divider().padding(.leading, Espaco.bloco + larguraHora + Espaco.grelha)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func linha(_ evento: EventoHoje, agora: Date) -> some View {
        HStack(spacing: Espaco.grelha) {
            Button {
                aberto = evento
            } label: {
                HStack(spacing: Espaco.grelha) {
                    horas(evento)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(evento.cor)
                        .frame(width: 4)
                        .padding(.vertical, Espaco.curto)

                    VStack(alignment: .leading, spacing: Espaco.minimo) {
                        HStack(spacing: Espaco.curto) {
                            Text(evento.titulo)
                                .font(.body.weight(.semibold))
                                .lineLimit(1)
                            if evento.aDecorrer(em: agora) {
                                Text("AGORA")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Espaco.curto)
                                    .padding(.vertical, Espaco.minimo)
                                    .background(Color.red, in: .rect(cornerRadius: 6))
                            }
                        }
                        EspacoDoEvento(espaco: espaco(de: evento), local: evento.detalhe)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Mostra o evento")

            botaoCriar(evento)
        }
        .padding(.leading, Espaco.bloco)
        .padding(.trailing, Espaco.fino)
        .frame(minHeight: Espaco.linhaItem)
        .accessibilityElement(children: .contain)
    }

    private func horas(_ evento: EventoHoje) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if evento.diaInteiro {
                Text("Todo o dia")
                    .font(.caption.weight(.bold))
            } else {
                Text(Formatos.hora(evento.inicio))
                    .font(.footnote.weight(.bold))
                Text(Formatos.hora(evento.fim))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .frame(width: larguraHora, alignment: .leading)
    }

    /// Por adicionar: "+" na cor do destino (toque: cria no espaço do evento ou, sem espaço,
    /// na última lista usada; pressão longa: escolher outra). Já adicionado: ✓ na cor da
    /// lista, que diz onde está (Melhoria 6.4).
    @ViewBuilder
    private func botaoCriar(_ evento: EventoHoje) -> some View {
        if let existente = existente(evento), let lista = existente.lista {
            Button {
                jaAdicionado = existente
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(lista.cor.texto)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(lista.cor.base))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Já está em \(lista.nome)")
        } else if let destino = destino(de: evento) {
            Menu {
                ForEach(listas) { lista in
                    Button("Criar em \(lista.nome)") { criar(evento, em: lista) }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(destino.cor.tinta)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(destino.cor.fundo))
                    .frame(width: 44, height: 44)
            } primaryAction: {
                criar(evento, em: destino)
            }
            .accessibilityLabel("Criar ponto em \(destino.nome) a partir de \(evento.titulo)")
        }
    }

    private func espaco(de evento: EventoHoje) -> Lista? {
        guard let id = calendario.espaco(de: evento.calendarioId) else { return nil }
        return listas.first { $0.id == id }
    }

    /// Onde o "+" cria o ponto: o espaço do evento ou, sem espaço, a última lista usada.
    private func destino(de evento: EventoHoje) -> Lista? {
        espaco(de: evento) ?? listas.first { $0.id.uuidString == ultimaListaId } ?? listas.first
    }

    private func existente(_ evento: EventoHoje) -> Item? {
        Tarefas.pontoDeEvento(em: deEventos, id: evento.eventoId, inicio: evento.inicio)
    }

    private func criar(_ evento: EventoHoje, em lista: Lista) {
        let tarefas = Tarefas(contexto: contexto)
        // Nunca duas vezes o mesmo evento (Melhoria 6.4).
        if let existente = try? tarefas.pontoDeEvento(id: evento.eventoId, inicio: evento.inicio) {
            jaAdicionado = existente
            return
        }
        guard (try? tarefas.criarPontoDeEvento(
            titulo: evento.titulo,
            inicio: evento.inicio,
            fim: evento.fim,
            diaInteiro: evento.diaInteiro,
            detalhe: evento.detalhe,
            eventoId: evento.eventoId,
            em: lista
        )) != nil else { return }
        ultimaListaId = lista.id.uuidString
        criados += 1
        estado.reagendarAvisos()
        withAnimation { confirmacao = "«\(evento.titulo)» criado em \(lista.nome)" }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { confirmacao = nil }
        }
    }

    /// Abre o ponto no separador Listas.
    private func abrir(_ item: Item) {
        aberto = nil
        estado.separador = .listas
        Task {
            // Deixa a folha do evento fechar antes de navegar.
            try? await Task.sleep(for: .milliseconds(400))
            estado.caminho.append(item)
        }
    }
}

/// O espaço de um evento por baixo do título (círculo do ícone e nome), ou "Sem espaço", e
/// o local (Melhoria 6.1).
struct EspacoDoEvento: View {
    let espaco: Lista?
    let local: String

    var body: some View {
        HStack(spacing: Espaco.curto) {
            if let espaco {
                IconeListaView(lista: espaco, tamanho: 18)
                Text(espaco.nome)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.8))
            } else {
                Circle()
                    .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .frame(width: 18, height: 18)
                Text("Sem espaço")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            if !local.isEmpty {
                Text("· \(local)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .lineLimit(1)
    }
}
