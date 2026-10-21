# Ícone da app

Colocar aqui o ícone final com o nome **`AppIcon.png`**. Ficheiros de trabalho (rascunhos, prompts, versões) também podem ficar nesta pasta.

## Requisitos

- **1024 × 1024 px**, PNG.
- **Sem transparência** (fundo opaco); o iOS rejeita ícones com canal alfa.
- **Quadrado, sem cantos arredondados**; o iOS aplica a máscara.
- Elementos importantes afastados das margens (cerca de 10%), porque os cantos são cortados.
- Opcional: `AppIcon-escuro.png` (fundo transparente, para o modo escuro do ecrã principal) e `AppIcon-tingido.png` (tons de cinzento, para o modo tingido).

Depois de o ficheiro estar aqui, o Claude Code copia-o para o catálogo de recursos da app (`App/Assets.xcassets/AppIcon.appiconset`) e liga-o no `project.yml`.
