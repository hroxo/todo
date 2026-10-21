# Ícone da app

O ícone em uso está no catálogo de recursos da app: `App/Resources/Assets.xcassets/AppIcon.appiconset`, em três aparências.

| Ficheiro | Aparência |
| --- | --- |
| `AppIcon-1024.png` | Clara (gradiente roxo → azul, elementos em vidro branco) |
| `AppIcon-1024-dark.png` | Escura (fundo preto, elementos no gradiente) |
| `AppIcon-1024-tinted.png` | Tingida (cinzentos; o iOS aplica a cor escolhida) |

O iOS só mostra o ícone escuro se o ecrã principal estiver em **Personalizar › Escuro** ou **Automático**.

Nesta pasta:
- `icone-preview.png`: referência visual das três aparências.
- `icon-layers/`: as camadas em SVG, guardadas só como arquivo. O Icon Composer só corre em macOS, por isso não fazem parte do fluxo.

## Trocar o ícone
Substituir os três PNG no `AppIcon.appiconset`, mantendo os nomes. Cada um com 1024 × 1024 px, sem transparência e sem cantos arredondados (o iOS aplica a máscara). O próximo CI compila-os; se o ícone não aparecer, procurar `actool` em `gh run view --log-failed`.
