#!/usr/bin/env bash
# Descarrega as capturas de ecrã de uma execução do CI para capturas/<versão>-<commit>/
# (escuro/ e claro/). As versões anteriores ficam guardadas ao lado. Precisa do gh autenticado.
# Uso: scripts/capturas.sh            (última execução do CI com capturas)
#      scripts/capturas.sh <id>       (uma execução em concreto)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -ge 1 ]; then
  EXECUCAO="$1"
else
  # A execução mais recente que já terminou e publicou o artefacto "capturas".
  EXECUCAO=""
  for id in $(gh run list --workflow CI --status completed --limit 10 --json databaseId --jq '.[].databaseId'); do
    if gh api "repos/{owner}/{repo}/actions/runs/$id/artifacts" --jq '.artifacts[].name' | grep -qx capturas; then
      EXECUCAO="$id"
      break
    fi
  done
  if [ -z "$EXECUCAO" ]; then
    echo "Nenhuma execução recente com capturas. Se o CI ainda estiver a correr, espera que acabe." >&2
    exit 1
  fi
fi

COMMIT=$(gh run view "$EXECUCAO" --json headSha --jq '.headSha[0:7]')
git fetch --quiet origin || true
VERSAO=$(git show "$COMMIT:project.yml" 2>/dev/null | sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p')
PASTA="capturas/${VERSAO:-sem-versao}-$COMMIT"

if [ -d "$PASTA" ]; then
  echo "Já existe: $PASTA"
else
  mkdir -p capturas
  TEMP=$(mktemp -d capturas/.a-descarregar-XXXX)
  gh run download "$EXECUCAO" --name capturas --dir "$TEMP"
  mv "$TEMP" "$PASTA"
  echo "Capturas da execução $EXECUCAO (versão ${VERSAO:-?}, commit $COMMIT) em $(pwd)/$PASTA"
fi

echo
echo "Versões guardadas:"
ls -1 capturas | grep -v '^\.' | sort -V
