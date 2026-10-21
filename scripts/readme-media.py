#!/usr/bin/env python3
"""Gera as imagens e os GIFs do README (docs/media/) a partir das capturas do CI e dos mocks.

Uso: python3 scripts/readme-media.py capturas/<versão>-<commit>
Precisa do Pillow. Os telemóveis ficam com 300 px de largura e cantos arredondados.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "docs" / "media"
LARGURA = 300


def telemovel(caminho: Path, largura: int = LARGURA) -> Image.Image:
    """Captura reduzida, com os cantos arredondados de um iPhone."""
    imagem = Image.open(caminho).convert("RGBA")
    altura = round(imagem.height * largura / imagem.width)
    imagem = imagem.resize((largura, altura), Image.LANCZOS)
    mascara = Image.new("L", imagem.size, 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, *imagem.size), radius=round(largura * 0.12), fill=255)
    imagem.putalpha(mascara)
    return imagem


def lado_a_lado(imagens, espaco=28) -> Image.Image:
    largura = sum(i.width for i in imagens) + espaco * (len(imagens) - 1)
    altura = max(i.height for i in imagens)
    tela = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
    x = 0
    for imagem in imagens:
        tela.paste(imagem, (x, 0), imagem)
        x += imagem.width + espaco
    return tela


def gif(nome: str, caminhos, duracao=1400):
    """GIF de um fluxo, com fundo escuro (os GIF não têm transparência parcial)."""
    quadros = []
    for caminho in caminhos:
        imagem = telemovel(caminho)
        fundo = Image.new("RGB", imagem.size, (13, 17, 23))
        fundo.paste(imagem, (0, 0), imagem)
        quadros.append(fundo.convert("P", palette=Image.ADAPTIVE, colors=255))
    quadros[0].save(SAIDA / nome, save_all=True, append_images=quadros[1:], duration=duracao, loop=0, optimize=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    capturas = RAIZ / sys.argv[1]
    escuro, claro = capturas / "escuro", capturas / "claro"
    mocks = RAIZ / "design" / "mocks"
    SAIDA.mkdir(parents=True, exist_ok=True)

    # Ícone da app, com o canto do iOS.
    icone = Image.open(RAIZ / "App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png").convert("RGBA")
    icone = icone.resize((160, 160), Image.LANCZOS)
    mascara = Image.new("L", icone.size, 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, 160, 160), radius=36, fill=255)
    icone.putalpha(mascara)
    icone.save(SAIDA / "icone.png", optimize=True)

    # Imagem principal: três ecrãs em escuro.
    lado_a_lado([telemovel(escuro / f) for f in ("1-inicio.png", "2-lista.png", "3-detalhe.png")]).save(
        SAIDA / "principal.png", optimize=True
    )

    # Fluxos.
    gif("fluxo-navegacao.gif", [escuro / "1-inicio.png", escuro / "2-lista.png", escuro / "3-detalhe.png"])
    gif("fluxo-manter.gif", [escuro / "3-detalhe.png", escuro / "4-manter-premido.png",
                             escuro / "5-manter-direita.png", escuro / "3-detalhe.png"], duracao=1100)
    gif("fluxo-calendario.gif", [escuro / "12-calendario-ligar.png", escuro / "11-calendario.png"], duracao=1800)
    gif("fluxo-espacos.gif", [mocks / "EspacosPagina1.png", mocks / "EspacosPagina2.png"], duracao=1800)
    gif("fluxo-tema.gif", [escuro / "1-inicio.png", claro / "1-inicio.png"], duracao=1600)

    # Galeria: escuro e claro.
    for nome in ("1-inicio", "2-lista", "3-detalhe", "6-captura", "8-expirados", "10-definicoes"):
        for tema, pasta in (("escuro", escuro), ("claro", claro)):
            imagem = telemovel(pasta / f"{nome}.png", largura=220)
            imagem.save(SAIDA / f"galeria-{nome}-{tema}.png", optimize=True)

    (SAIDA / "ORIGEM.txt").write_text(f"Gerado por scripts/readme-media.py a partir de {sys.argv[1]}\n")
    total = sum(f.stat().st_size for f in SAIDA.iterdir())
    print(f"docs/media: {len(list(SAIDA.iterdir()))} ficheiros, {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
