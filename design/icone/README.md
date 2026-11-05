# Ícone da app

O ícone em uso está em `App/Resources/Assets.xcassets/AppIcon.appiconset`, em três aparências (DESIGN.md 10): a Ampulheta dentro do anel do prazo.

| Ficheiro | Aparência |
| --- | --- |
| `AppIcon-1024.png` | Clara (gradiente roxo → azul) |
| `AppIcon-1024-dark.png` | Escura (noite índigo com estrelas) |
| `AppIcon-1024-tinted.png` | Tingida (cinzentos; o iOS aplica a cor escolhida) |

O iOS só mostra o ícone escuro se o ecrã principal estiver em **Personalizar › Escuro** ou **Automático**.

`icone-preview.png`, nesta pasta, mostra as três aparências lado a lado (usado no README).

## Trocar o ícone

Substituir os três PNG no `AppIcon.appiconset`, mantendo os nomes. Cada um com 1024 × 1024 px, sem transparência e sem cantos arredondados (o iOS aplica a máscara). O próximo CI compila-os; se o ícone não aparecer, procurar `actool` em `gh run view --log-failed`.
