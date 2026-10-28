import SwiftData
import SwiftUI
import ToDoCore

/// Destino de navegação do ecrã do dia, aberto a partir de "Hoje no calendário" no Início.
struct RotaDia: Hashable {}

/// O dia de hoje numa linha do tempo: um resumo no topo (eventos e o próximo), os eventos de
/// todo o dia e os itens que expiram hoje, e por baixo as horas com cada evento num bloco na
/// cor do calendário e a linha vermelha da hora atual. Tocar num evento abre-o.
struct DiaView: View {
    @Environment(Calendario.self) private var calendario
    @Environment(EstadoApp.self) private var estado
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @Query(filter: #Predicate<Item> { $0.eventoId != nil }) private var deEventos: [Item]
    @Query(filter: #Predicate<Item> { $0.estadoRaw == "ativo" && $0.fixado == false && $0.pai == nil })
    private var ativos: [Item]
    @AppStorage("ultimaListaId") private var ultimaListaId = ""

    @State private var aberto: EventoHoje?
    @State private var criados = 0

    private let alturaHora: CGFloat = 64
    private let larguraHoras: CGFloat = 44

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { relogio in
            let agora = relogio.date
            ScrollView {
                VStack(alignment: .leading, spacing: Espaco.bloco) {
                    resumo(agora)
                    if !diaInteiro.isEmpty {
                        secaoDiaInteiro
                    }
                    let hoje = expiramHoje(agora)
                    if !hoje.isEmpty {
                        secaoExpiram(hoje)
                    }
                    linhaDoTempo(agora)
                }
                .padding(.horizontal, Espaco.margem)
                .padding(.bottom, Espaco.margem)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Hoje")
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.success, trigger: criados)
        .sheet(item: $aberto) { evento in
            let atual = calendario.eventos.first { $0.id == evento.id } ?? evento
            VistaEvento(
                evento: atual,
                espaco: acoes.espaco(de: atual),
                existente: acoes.existente(atual),
                criar: { criar(atual, em: $0) },
                abrir: abrir
            )
        }
    }

    private var acoes: AcoesEvento {
        AcoesEvento(calendario: calendario, listas: listas, deEventos: deEventos, ultimaListaId: ultimaListaId)
    }

    private var diaInteiro: [EventoHoje] { calendario.eventos.filter(\.diaInteiro) }
    private var comHora: [EventoHoje] { calendario.eventos.filter { !$0.diaInteiro } }

    private func expiramHoje(_ agora: Date) -> [Item] {
        ativos
            .filter { Prazo(item: $0, agora: agora)?.ultimoDia == true }
            .sorted { ($0.expiraEm ?? .distantFuture) < ($1.expiraEm ?? .distantFuture) }
    }

    // MARK: - Resumo

    /// Data e dois números grandes, ao estilo Fitness: eventos de hoje e o próximo.
    private func resumo(_ agora: Date) -> some View {
        let seguinte = comHora.first { $0.inicio > agora }
        let atual = comHora.first { $0.aDecorrer(em: agora) }
        return VStack(alignment: .leading, spacing: Espaco.grelha) {
            Text(Formatos.cabecalho(agora).uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: Espaco.grelha) {
                quadro(titulo: "Eventos", valor: "\(calendario.eventos.count)", detalhe: restantes(agora))
                if let atual {
                    quadro(titulo: "Agora", valor: Formatos.hora(atual.fim), detalhe: "termina «\(atual.titulo)»", cor: .red)
                } else if let seguinte {
                    quadro(titulo: "A seguir", valor: Formatos.hora(seguinte.inicio), detalhe: seguinte.titulo, cor: seguinte.cor)
                } else {
                    quadro(titulo: "A seguir", valor: "—", detalhe: "Nada mais hoje")
                }
            }
        }
    }

    private func restantes(_ agora: Date) -> String {
        let faltam = comHora.filter { $0.fim > agora }.count
        return faltam == 0 ? "todos já passaram" : (faltam == 1 ? "falta 1" : "faltam \(faltam)")
    }

    private func quadro(titulo: String, valor: String, detalhe: String, cor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: Espaco.minimo) {
            Text(titulo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(cor)
                .contentTransition(.numericText())
            Text(detalhe)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(Espaco.bloco)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Todo o dia e itens que expiram

    private var secaoDiaInteiro: some View {
        VStack(alignment: .leading, spacing: Espaco.curto) {
            TituloSecao(texto: "Todo o dia")
            ForEach(diaInteiro) { evento in
                Button {
                    aberto = evento
                } label: {
                    HStack(spacing: Espaco.curto) {
                        Circle().fill(evento.cor).frame(width: 8, height: 8)
                        Text(evento.titulo)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Espaco.bloco)
                    .frame(minHeight: 44)
                    .background(evento.cor.opacity(0.15), in: .rect(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func secaoExpiram(_ itens: [Item]) -> some View {
        VStack(alignment: .leading, spacing: Espaco.curto) {
            TituloSecao(texto: "Expiram hoje", cor: CoresEstado.expiraTinta)
            VStack(spacing: 0) {
                ForEach(itens) { item in
                    NavigationLink(value: item) {
                        HStack(spacing: Espaco.grelha) {
                            if let lista = item.lista {
                                IconeListaView(lista: lista, tamanho: 24)
                            }
                            Text(item.titulo)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let expira = item.expiraEm {
                                // "Hoje" no Início são as últimas 24 h do prazo: podem passar da meia-noite.
                                Text(Calendar.current.isDateInToday(expira)
                                     ? "às \(Formatos.hora(expira))"
                                     : "amanhã, \(Formatos.hora(expira))")
                                    .font(.footnote.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(CoresEstado.expiraTinta)
                            }
                        }
                        .padding(.horizontal, Espaco.bloco)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if item != itens.last {
                        Divider().padding(.leading, Espaco.bloco + 24 + Espaco.grelha)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Linha do tempo

    /// Das 7 às 23 h, ou mais cedo/tarde se houver eventos fora disso.
    private var primeiraHora: Int {
        let horas = comHora.map { Calendar.current.component(.hour, from: $0.inicio) }
        return min(7, horas.min() ?? 7)
    }

    private var ultimaHora: Int {
        let horas = comHora.map { evento in
            let c = Calendar.current.dateComponents([.hour, .minute], from: evento.fim)
            return (c.hour ?? 0) + ((c.minute ?? 0) > 0 ? 1 : 0)
        }
        return min(24, max(23, horas.max() ?? 23))
    }

    /// Distância ao topo da linha do tempo de uma hora do dia.
    private func posicao(_ data: Date, inicioDia: Date) -> CGFloat {
        let minutos = data.timeIntervalSince(inicioDia) / 60 - Double(primeiraHora * 60)
        return CGFloat(minutos / 60) * alturaHora
    }

    private func linhaDoTempo(_ agora: Date) -> some View {
        let inicioDia = Calendar.current.startOfDay(for: agora)
        let horas = Array(primeiraHora...ultimaHora)
        return VStack(alignment: .leading, spacing: Espaco.curto) {
            TituloSecao(texto: "Horas")
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(horas, id: \.self) { hora in
                        HStack(alignment: .top, spacing: Espaco.curto) {
                            Text(String(format: "%02d:00", hora % 24))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: larguraHoras, alignment: .leading)
                                .offset(y: -7)
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5)
                        }
                        .frame(height: alturaHora, alignment: .top)
                        .id(hora)
                    }
                }

                GeometryReader { geometria in
                    let x0 = larguraHoras + Espaco.curto
                    let largura = geometria.size.width - x0
                    ForEach(Self.dispor(comHora)) { disposto in
                        let coluna = largura / CGFloat(disposto.colunas)
                        let y = posicao(disposto.evento.inicio, inicioDia: inicioDia)
                        let altura = max(26, posicao(disposto.evento.fim, inicioDia: inicioDia) - y - 2)
                        bloco(disposto.evento, agora: agora, altura: altura)
                            .frame(width: coluna - 3, height: altura)
                            .offset(x: x0 + coluna * CGFloat(disposto.coluna), y: y + 1)
                    }
                    if Calendar.current.component(.hour, from: agora) >= primeiraHora {
                        linhaAgora
                            .frame(width: largura + 4)
                            .offset(x: x0 - 4, y: posicao(agora, inicioDia: inicioDia) - 4)
                    }
                }
            }
            .frame(height: alturaHora * CGFloat(horas.count))
            .padding(.top, Espaco.curto)
        }
    }

    private var linhaAgora: some View {
        HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
            Rectangle().fill(Color.red).frame(height: 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func bloco(_ evento: EventoHoje, agora: Date, altura: CGFloat) -> some View {
        let passou = evento.fim <= agora
        let compacto = altura < 44
        let adicionado = acoes.existente(evento)
        return Button {
            aberto = evento
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(evento.cor)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(evento.titulo)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(compacto ? 1 : 2)
                    if !compacto {
                        Text(evento.detalhe.isEmpty
                             ? Formatos.intervalo(evento.inicio, evento.fim)
                             : Formatos.intervalo(evento.inicio, evento.fim) + " · " + evento.detalhe)
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, compacto ? 2 : 5)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            // Fundo opaco por baixo da cor, para as linhas das horas não se verem através.
            .background(evento.cor.opacity(passou ? 0.1 : 0.2))
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(alignment: .topTrailing) {
                if let lista = adicionado?.lista {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(lista.cor.texto)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(lista.cor.base))
                        .padding(4)
                }
            }
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .opacity(passou ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(evento.titulo), \(Formatos.intervalo(evento.inicio, evento.fim))")
        .accessibilityHint("Mostra o evento")
    }

    /// Um evento com a coluna onde fica e quantas colunas tem o seu grupo de sobrepostos.
    private struct Disposto: Identifiable {
        let evento: EventoHoje
        let coluna: Int
        let colunas: Int
        var id: String { evento.id }
    }

    /// Eventos sobrepostos ficam lado a lado: cada grupo que se toca divide a largura em
    /// colunas, e cada evento fica na primeira coluna livre.
    private static func dispor(_ eventos: [EventoHoje]) -> [Disposto] {
        var resultado: [Disposto] = []
        var grupo: [(evento: EventoHoje, coluna: Int)] = []
        var finsColunas: [Date] = []
        var fimGrupo = Date.distantPast

        func fecharGrupo() {
            let colunas = max(1, finsColunas.count)
            resultado += grupo.map { Disposto(evento: $0.evento, coluna: $0.coluna, colunas: colunas) }
            grupo = []
            finsColunas = []
        }

        for evento in eventos.sorted(by: { $0.inicio < $1.inicio }) {
            if evento.inicio >= fimGrupo {
                fecharGrupo()
            }
            if let livre = finsColunas.firstIndex(where: { $0 <= evento.inicio }) {
                finsColunas[livre] = evento.fim
                grupo.append((evento, livre))
            } else {
                finsColunas.append(evento.fim)
                grupo.append((evento, finsColunas.count - 1))
            }
            fimGrupo = max(fimGrupo, evento.fim)
        }
        fecharGrupo()
        return resultado
    }

    // MARK: - Ações

    private func criar(_ evento: EventoHoje, em lista: Lista) {
        guard case .criado = AcoesEvento.criar(evento, em: lista, contexto: contexto) else { return }
        ultimaListaId = lista.id.uuidString
        criados += 1
        estado.reagendarAvisos()
    }

    /// Fecha a folha do evento e abre o ponto, na mesma pilha de navegação.
    private func abrir(_ item: Item) {
        aberto = nil
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            estado.caminho.append(item)
        }
    }
}
