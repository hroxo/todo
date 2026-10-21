#!/usr/bin/env bash
# Descarrega as capturas de ecrã da última execução do CI para a pasta capturas/
# (capturas/escuro e capturas/claro). Precisa do gh autenticado.
# Uso: scripts/capturas.sh [id da execução]
set -euo pipefail
cd "$(dirname "$0")/.."

EXECUCAO="${1:-$(gh run list --workflow CI --status success --limit 1 --json databaseId --jq '.[0].databaseId')}"
rm -rf capturas
gh run download "$EXECUCAO" --name capturas --dir capturas
echo "Capturas da execução $EXECUCAO em $(pwd)/capturas"
find capturas -name '*.png' | sort
