import SwiftUI

/// A base de dados não abriu, por exemplo por causa do iCloud (DESIGN.md 7.19): a app diz porquê
/// em vez de se fechar, e o texto do erro pode partilhar-se sem precisar de um Mac.
struct ErroBaseDadosView: View {
    let erro: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espaco.bloco) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Não foi possível abrir os teus dados")
                    .font(.largeTitle.weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
                Text("A app não alterou nada. Não a apagues: os teus dados podem estar só neste iPhone. Tenta abrir mais tarde ou partilha este erro.")
                ShareLink("Partilhar o erro", item: erro)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                Text(erro)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(Espaco.margem)
        }
        .background(Color(.systemGroupedBackground))
    }
}
