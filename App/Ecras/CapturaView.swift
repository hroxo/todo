import PhotosUI
import SwiftData
import SwiftUI
import ToDoCore

/// Captura rápida (mock "Captura rápida", DESIGN.md 7.6): o teclado abre logo; escrever e
/// tocar em Guardar chega. Por cima do teclado: foto da biblioteca, subtópico e fixar.
struct CapturaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Environment(EstadoApp.self) private var estado
    @Query(sort: \Lista.ordem) private var listas: [Lista]
    @AppStorage("ultimaListaId") private var ultimaListaId = ""

    private enum Campo: Hashable {
        case texto
        case subtopico(Int)
    }

    @State private var texto = ""
    @State private var listaId: UUID?
    @State private var subtopicos: [String] = []
    @State private var fixado = false
    @State private var fotos: [Data] = []
    @State private var selecaoFotos: [PhotosPickerItem] = []
    @FocusState private var foco: Campo?

    private var lista: Lista? {
        listas.first { $0.id == listaId } ?? listas.first
    }

    private var cor: CorLista { lista?.cor ?? .azul }

    private var podeGuardar: Bool {
        lista != nil && !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espaco.bloco) {
                    VStack(alignment: .leading, spacing: Espaco.curto) {
                        TituloSecao(texto: "O que tens na cabeça?")
                        TextField("Escreve aqui", text: $texto, axis: .vertical)
                            .font(.title2.weight(.semibold))
                            .lineLimit(1...8)
                            .focused($foco, equals: .texto)
                            .tint(cor.base)
                    }

                    if !subtopicos.isEmpty {
                        VStack(spacing: Espaco.curto) {
                            ForEach(subtopicos.indices, id: \.self) { indice in
                                linhaSubtopico(indice)
                            }
                        }
                    }

                    if !fotos.isEmpty {
                        HStack(spacing: Espaco.curto) {
                            ForEach(fotos.indices, id: \.self) { indice in
                                miniatura(indice)
                            }
                        }
                    }

                    FluxoLayout(espaco: Espaco.curto) {
                        ForEach(listas) { opcao in
                            ficha(opcao)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: listaId)

                    Label(
                        fixado ? "Fixada: não expira" : "Expira daqui a \(Definicoes.carregar().diasExpiracao) dias se não lhe tocares",
                        systemImage: fixado ? "pin.fill" : "clock"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(Espaco.margem)
            }
            .navigationTitle("Nova nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardar)
                        .font(.headline)
                        .buttonStyle(.borderedProminent)
                        .tint(cor.base)
                        .foregroundStyle(cor.texto)
                        .disabled(!podeGuardar)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    PhotosPicker(
                        selection: $selecaoFotos,
                        maxSelectionCount: max(1, Tarefas.maxFotos - fotos.count),
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .disabled(fotos.count >= Tarefas.maxFotos)
                    .accessibilityLabel("Adicionar foto da biblioteca")

                    Button {
                        subtopicos.append("")
                        foco = .subtopico(subtopicos.count - 1)
                    } label: {
                        Image(systemName: "checklist")
                    }
                    .accessibilityLabel("Adicionar subtópico")

                    Button {
                        fixado.toggle()
                    } label: {
                        Image(systemName: fixado ? "pin.fill" : "pin")
                    }
                    .accessibilityLabel(fixado ? "Desafixar" : "Fixar")

                    Spacer()
                }
            }
            .tint(cor.tinta)
            .onAppear {
                listaId = estado.listaAtual?.id ?? UUID(uuidString: ultimaListaId)
                foco = .texto
            }
            .defaultFocus($foco, .texto)
            .onChange(of: selecaoFotos) { _, selecao in
                guard !selecao.isEmpty else { return }
                Task {
                    let novas = await ProcessarFoto.carregar(selecao)
                    fotos.append(contentsOf: novas.prefix(Tarefas.maxFotos - fotos.count))
                    selecaoFotos = []
                }
            }
        }
        .presentationDetents([.large])
    }

    private func ficha(_ opcao: Lista) -> some View {
        let escolhida = opcao.id == lista?.id
        return Button {
            listaId = opcao.id
        } label: {
            HStack(spacing: Espaco.curto) {
                IconeListaView(lista: opcao, tamanho: 28, fundo: escolhida ? opcao.cor.ficha : nil)
                Text(opcao.nome)
                    .font(.subheadline.bold())
            }
            .padding(.leading, Espaco.curto)
            .padding(.trailing, Espaco.grelha)
            .frame(minHeight: 40)
            .foregroundStyle(escolhida ? opcao.cor.texto : Color.primary)
            .background(escolhida ? opcao.cor.base : Color(.secondarySystemFill), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(opcao.nome)
        .accessibilityAddTraits(escolhida ? .isSelected : [])
    }

    private func linhaSubtopico(_ indice: Int) -> some View {
        HStack(spacing: Espaco.grelha) {
            Image(systemName: "circle")
                .foregroundStyle(cor.base)
            TextField("Subtópico", text: $subtopicos[indice])
                .focused($foco, equals: .subtopico(indice))
                .submitLabel(.next)
                .onSubmit {
                    subtopicos.append("")
                    foco = .subtopico(subtopicos.count - 1)
                }
            Button {
                subtopicos.remove(at: indice)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remover subtópico")
        }
        .font(.body)
    }

    private func miniatura(_ indice: Int) -> some View {
        MiniaturaFoto(dados: fotos[indice], tamanho: 72)
            .overlay(alignment: .topTrailing) {
                Button {
                    fotos.remove(at: indice)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color(.darkGray)))
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                .accessibilityLabel("Remover foto")
            }
    }

    private func guardar() {
        guard let lista else { return }
        let tarefas = Tarefas(contexto: contexto)
        guard let item = try? tarefas.criarItem(titulo: texto, em: lista, tipo: .notaRapida) else { return }
        for sub in subtopicos {
            _ = try? tarefas.adicionarSubtopico(titulo: sub, a: item)
        }
        for dados in fotos {
            _ = try? tarefas.adicionarFoto(dados, a: item)
        }
        if fixado {
            tarefas.definirFixado(item, true)
        }
        ultimaListaId = lista.id.uuidString
        estado.reagendarAvisos()
        dismiss()
    }
}
