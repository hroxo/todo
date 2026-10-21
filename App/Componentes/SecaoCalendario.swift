import SwiftData
import SwiftUI
import ToDoCore
import UIKit

/// Fundo do Início (DESIGN.md 7.12, mocks 7 e 8): o cartão para ligar o calendário ou os
/// eventos de hoje, com um "+" que cria um ponto a partir de cada evento.
struct SecaoCalendario: View {
    @Environment(Calendario.self) private var calendario
    @Environment(EstadoApp.self) private var estado
    @Environment(\.modelContext) private var contexto
    @Environment(\.openURL) private var abrirURL
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @AppStorage("ultimaListaId") private var ultimaListaId = ""
    @AppStorage("mostrarCalendario") private var mostrar = true

    @State private var confirmacao: String?
    @State private var criados = 0

    var body: some View {
        Group {
            switch calendario.acesso {
            case .porPedir: cartaoLigar
            case .recusado: cartaoRecusado
            case .autorizado: hoje
            }
        }
        .sensoryFeedback(.success, trigger: criados)
    }

    // MARK: - Por ligar

    private var cartaoLigar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                circuloCalendario
                VStack(alignment: .leading, spacing: 2) {
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
                .padding(.top, -10)
                .padding(.trailing, -10)
                .accessibilityLabel("Agora não")
            }

            HStack(spacing: 8) {
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
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private var cartaoRecusado: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                circuloCalendario
                VStack(alignment: .leading, spacing: 2) {
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
        .padding(16)
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
        HStack(spacing: 6) {
            Circle().fill(cor).frame(width: 9, height: 9)
            Text(nome)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Color(.tertiarySystemFill), in: .capsule)
    }

    // MARK: - Ligado

    private var hoje: some View {
        TimelineView(.periodic(from: .now, by: 60)) { contexto in
            VStack(alignment: .leading, spacing: 8) {
                TituloSecao(texto: "Hoje no calendário")

                if let confirmacao {
                    Label(confirmacao, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CoresEstado.concluido)
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    if calendario.eventos.isEmpty {
                        Text("Nada no calendário hoje")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, 16)
                    }
                    ForEach(calendario.eventos) { evento in
                        linha(evento, agora: contexto.date)
                        if evento != calendario.eventos.last {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func linha(_ evento: EventoHoje, agora: Date) -> some View {
        HStack(spacing: 12) {
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
            .frame(width: 48, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(evento.cor)
                .frame(width: 4)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(evento.titulo)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if evento.aDecorrer(em: agora) {
                        Text("AGORA")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red, in: .rect(cornerRadius: 6))
                    }
                }
                if !evento.detalhe.isEmpty {
                    Text(evento.detalhe)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            botaoCriar(evento)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(minHeight: 58)
        .accessibilityElement(children: .contain)
    }

    /// Toque: cria na última lista usada. Pressão longa: escolher a lista.
    private func botaoCriar(_ evento: EventoHoje) -> some View {
        let destino = listaPorDefeito
        return Menu {
            ForEach(listas) { lista in
                Button("Criar em \(lista.nome)") { criar(evento, em: lista) }
            }
        } label: {
            Image(systemName: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(destino?.cor.tinta ?? .accentColor)
                .frame(width: 30, height: 30)
                .background(Circle().fill(destino?.cor.fundo ?? Color(.tertiarySystemFill)))
                .frame(width: 44, height: 44)
        } primaryAction: {
            if let destino { criar(evento, em: destino) }
        }
        .accessibilityLabel("Criar ponto a partir de \(evento.titulo)")
    }

    private var listaPorDefeito: Lista? {
        listas.first { $0.id.uuidString == ultimaListaId } ?? listas.first
    }

    private func criar(_ evento: EventoHoje, em lista: Lista) {
        let tarefas = Tarefas(contexto: contexto)
        guard (try? tarefas.criarPontoDeEvento(
            titulo: evento.titulo,
            inicio: evento.inicio,
            fim: evento.fim,
            diaInteiro: evento.diaInteiro,
            detalhe: evento.detalhe,
            em: lista
        )) != nil else { return }
        criados += 1
        estado.reagendarAvisos()
        withAnimation { confirmacao = "«\(evento.titulo)» criado em \(lista.nome)" }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { confirmacao = nil }
        }
    }
}
