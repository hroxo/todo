import SwiftData
import SwiftUI
import ToDoCore

/// Um evento do calendário, aberto a partir do Início (Melhoria 6.2): título, data e hora,
/// local, link da reunião, organizador, participantes com a resposta e as notas (onde costuma
/// estar o texto do convite; o EventKit não dá o email original). Em baixo, as fichas de lista
/// para criar um ponto a partir do evento (Melhoria 6.3), ou onde ele já está (6.4).
struct VistaEvento: View {
    let evento: EventoHoje
    /// O espaço do calendário do evento, ou nil (sem espaço).
    let espaco: Lista?
    /// O ponto já criado a partir deste evento, se houver.
    let existente: Item?
    let criar: (Lista) -> Void
    let abrir: (Item) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lista.ordem) private var listas: [Lista]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espaco.margem) {
                    cabecalho

                    if let link = evento.link {
                        Link(destination: link) {
                            Label("Entrar na reunião", systemImage: "video.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .accessibilityHint(link.host ?? "")
                    }

                    secaoPonto

                    if let organizador = evento.organizador {
                        Label("Organizado por \(organizador)", systemImage: "person.crop.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !evento.participantes.isEmpty {
                        secaoParticipantes
                    }

                    if !evento.notas.isEmpty {
                        VStack(alignment: .leading, spacing: Espaco.curto) {
                            TituloSecao(texto: "Notas")
                            Text(evento.notas)
                                .font(.subheadline)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Espaco.bloco)
                                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(Espaco.margem)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var cabecalho: some View {
        HStack(alignment: .top, spacing: Espaco.grelha) {
            RoundedRectangle(cornerRadius: 2)
                .fill(evento.cor)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: Espaco.fino) {
                Text(evento.titulo)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(quando)
                    .font(.subheadline.weight(.semibold))
                if !evento.detalhe.isEmpty {
                    Label(evento.detalhe, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label(evento.calendarioNome, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// "Quinta, 22 out · 14:30–15:30".
    private var quando: String {
        let horas = evento.diaInteiro ? "Todo o dia" : Formatos.intervalo(evento.inicio, evento.fim)
        return Formatos.cabecalho(evento.inicio) + " · " + horas
    }

    // MARK: - Ponto e espaço

    @ViewBuilder
    private var secaoPonto: some View {
        VStack(alignment: .leading, spacing: Espaco.curto) {
            HStack {
                TituloSecao(texto: "Espaço do calendário")
                Spacer()
                NavigationLink {
                    EscolherEspacoView(calendarioId: evento.calendarioId, nome: evento.calendarioNome)
                } label: {
                    Text(espaco == nil ? "Associar" : "Mudar")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
            EspacoDoEvento(espaco: espaco, local: "")

            if let existente, let lista = existente.lista {
                HStack(spacing: Espaco.grelha) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(lista.cor.texto)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(lista.cor.base))
                    Text("Já está em \(lista.nome)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Abrir") { abrir(existente) }
                        .font(.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, Espaco.bloco)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
                .padding(.top, Espaco.curto)
            } else {
                TituloSecao(texto: "Criar ponto em")
                    .padding(.top, Espaco.curto)
                FluxoLayout(espaco: Espaco.curto) {
                    ForEach(listas) { lista in
                        ficha(lista)
                    }
                }
            }
        }
    }

    /// Ficha de lista, como na captura rápida; a do espaço do evento vem preenchida.
    private func ficha(_ lista: Lista) -> some View {
        let sugerida = lista.id == espaco?.id
        return Button {
            criar(lista)
        } label: {
            HStack(spacing: Espaco.curto) {
                IconeListaView(lista: lista, tamanho: 28, fundo: sugerida ? lista.cor.ficha : nil)
                Text(lista.nome)
                    .font(.subheadline.bold())
            }
            .padding(.leading, (40 - 28) / 2)
            .padding(.trailing, Espaco.grelha)
            .frame(minHeight: 40)
            .foregroundStyle(sugerida ? lista.cor.texto : Color.primary)
            .background(sugerida ? lista.cor.base : Color(.secondarySystemFill), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Criar ponto em \(lista.nome)")
    }

    // MARK: - Participantes

    private var secaoParticipantes: some View {
        VStack(alignment: .leading, spacing: Espaco.curto) {
            TituloSecao(texto: "Participantes · \(evento.participantes.count)")
            VStack(spacing: 0) {
                ForEach(Array(evento.participantes.enumerated()), id: \.offset) { indice, participante in
                    HStack(spacing: Espaco.grelha) {
                        Image(systemName: simbolo(participante.resposta))
                            .foregroundStyle(cor(participante.resposta))
                            .accessibilityHidden(true)
                        Text(participante.nome)
                            .lineLimit(1)
                        Spacer()
                        Text(participante.resposta.nome)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Espaco.bloco)
                    .frame(minHeight: Espaco.linhaSubtopico)
                    .accessibilityElement(children: .combine)
                    if indice < evento.participantes.count - 1 {
                        Divider().padding(.leading, Espaco.bloco)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
        }
    }

    private func simbolo(_ resposta: RespostaConvite) -> String {
        switch resposta {
        case .aceite: "checkmark.circle.fill"
        case .talvez: "questionmark.circle.fill"
        case .recusado: "xmark.circle.fill"
        case .pendente: "clock"
        }
    }

    private func cor(_ resposta: RespostaConvite) -> Color {
        switch resposta {
        case .aceite: CoresEstado.concluido
        case .talvez: .orange
        case .recusado: .red
        case .pendente: .secondary
        }
    }
}
