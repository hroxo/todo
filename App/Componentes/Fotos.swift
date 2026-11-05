import ImageIO
import PhotosUI
import SwiftUI
import UIKit

/// Reduz uma foto da biblioteca para JPEG (lado maior ≤ 2048 px, qualidade 0,8; DESIGN.md 7.7).
enum ProcessarFoto {
    static func jpeg(_ dados: Data, ladoMaximo: CGFloat = 2048, qualidade: CGFloat = 0.8) -> Data? {
        // Reduz sem descodificar a foto inteira: uma de 24 MP ocupava ~100 MB só para isto.
        // Nunca aumenta, e aplica a rotação da câmara.
        let opcoes = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: ladoMaximo,
        ] as CFDictionary
        guard let fonte = CGImageSourceCreateWithData(dados as CFData, nil),
              let reduzida = CGImageSourceCreateThumbnailAtIndex(fonte, 0, opcoes)
        else { return nil }
        return UIImage(cgImage: reduzida).jpegData(compressionQuality: qualidade)
    }

    /// Carrega e reduz as fotos escolhidas no PhotosPicker.
    static func carregar(_ selecao: [PhotosPickerItem]) async -> [Data] {
        var resultado: [Data] = []
        for item in selecao {
            if let dados = try? await item.loadTransferable(type: Data.self), let jpeg = jpeg(dados) {
                resultado.append(jpeg)
            }
        }
        return resultado
    }
}

/// Miniatura quadrada com cantos de 14 pt. A imagem é reduzida fora do fio principal.
struct MiniaturaFoto: View {
    let dados: Data
    var tamanho: CGFloat = 76

    @State private var imagem: UIImage?

    var body: some View {
        ZStack {
            Color(.tertiarySystemFill)
            if let imagem {
                Image(uiImage: imagem)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: tamanho, height: tamanho)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .task {
            let dados = dados
            imagem = await Task.detached {
                UIImage(data: dados)?.preparingThumbnail(of: CGSize(width: 240, height: 240))
            }.value
        }
        .accessibilityLabel("Foto")
    }
}

/// Foto em ecrã inteiro.
struct VisualizadorFoto: View {
    let dados: Data

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let imagem = UIImage(data: dados) {
                Image(uiImage: imagem)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Foto")
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .padding()
            .accessibilityLabel("Fechar")
        }
    }
}

/// Quadrado tracejado para acrescentar fotos da biblioteca.
struct BotaoBiblioteca: View {
    let cor: Color
    var tamanho: CGFloat = 76

    var body: some View {
        VStack(spacing: Espaco.fino) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
            Text("Biblioteca")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(cor)
        .frame(width: tamanho, height: tamanho)
        .background(Ceu.cartao.opacity(0.5), in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(cor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        )
    }
}
