#!/usr/bin/env bash
# Converte os mocks em HTML de design/mocks/html/ em PNG (design/mocks/), com o Firefox em
# modo headless, para os ver sem abrir o canvas.
# Uso: scripts/mocks.sh [NomeDoMock ...]   (sem argumentos: todos)
set -euo pipefail
cd "$(dirname "$0")/.."
# O Firefox em snap não lê pastas escondidas: o perfil fica em capturas/ (fora do git).
PERFIL="$PWD/capturas/perfil-firefox"
mkdir -p "$PERFIL"
if [ $# -eq 0 ]; then
  set -- $(cd design/mocks/html && ls *.dc.html | sed 's/\.dc\.html$//')
fi
for nome in "$@"; do
  timeout 90 firefox --headless --no-remote --profile "$PERFIL" --window-size=390,844 \
    --screenshot "$PWD/design/mocks/$nome.png" "file://$PWD/design/mocks/html/$nome.dc.html" > /dev/null 2>&1
  echo "design/mocks/$nome.png"
done
