#!/usr/bin/env bash
# Corre no CI, depois das capturas. O modo de demonstração salta a base de dados real, os avisos
# e o calendário: aqui a app abre como no iPhone, sem e com o calendário autorizado, e tem de
# continuar viva e desenhar a interface. O simulador não mata uma app bloqueada, por isso também
# se confirma que há interface, e fica a pilha (sample) para ver onde parou. Sem assinatura não
# há iCloud, por isso esse caminho só se prova no iPhone.
#   scripts/arranque-real-ci.sh <ToDo.app do simulador> <pasta de saída>
set -uo pipefail

BUNDLE="com.hugo.tudo"
APP="$1"
SAIDA="$2/arranque-real"
UDID=$(cat "${RUNNER_TEMP:-/tmp}/simulador-udid")
# Um ecrã só com o lançamento (liso) deu 70 KB; o ecrã real mais simples, 160 KB.
MINIMO_BYTES=110000

mkdir -p "$SAIDA"
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
falhou=0

abrir() {
  local nome="$1"
  shift
  local saida pid tamanho processos
  # Os argumentos extra (-chave valor) sobrepõem-se às preferências só nesta abertura.
  saida=$(xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "$@")
  pid=${saida##*: }
  echo "$nome: pid $pid"
  sleep 15
  xcrun simctl io "$UDID" screenshot "$SAIDA/$nome-15s.png" > /dev/null 2>&1 || true
  sleep 25
  xcrun simctl io "$UDID" screenshot "$SAIDA/$nome-40s.png" > /dev/null 2>&1 || true
  sample "$pid" 5 -file "$SAIDA/$nome-sample.txt" > /dev/null 2>&1 || echo "$nome: sem sample"
  xcrun simctl spawn "$UDID" log show --last 1m --style compact \
    --predicate 'process == "ToDo"' > "$SAIDA/$nome-log.txt" 2>&1 || true

  # Lista guardada antes do grep -q: com pipefail, a pipe falhava com a app viva (SIGPIPE).
  processos=$(xcrun simctl spawn "$UDID" launchctl list)
  if ! grep -q "UIKitApplication:$BUNDLE" <<< "$processos"; then
    echo "::error::$nome: a app morreu no arranque real."
    falhou=1
    return
  fi
  tamanho=$(stat -f%z "$SAIDA/$nome-40s.png" 2>/dev/null || echo 0)
  echo "$nome: captura com $tamanho bytes"
  if [ "$tamanho" -lt "$MINIMO_BYTES" ]; then
    echo "::error::$nome: sem interface ao fim de 40 s (bloqueada no ecrã de lançamento?)."
    falhou=1
  fi
  # O tamanho não chega: o aviso das notificações enche a captura mesmo com a app em branco.
  if grep -q "_firstCommitBlock" "$SAIDA/$nome-sample.txt"; then
    echo "::error::$nome: bloqueada no primeiro desenho ao fim de 40 s."
    falhou=1
  fi
}

abrir sem-calendario
xcrun simctl privacy "$UDID" grant calendar "$BUNDLE" || echo "Não foi possível autorizar o calendário"
# Com o aviso das notificações a app não fica ativa e a marca de abertura fica posta: sem limpar,
# a abertura seguinte mostrava o cartão em vez dos eventos. A última testa esse cartão.
abrir com-calendario -calendarioALer NO
abrir com-calendario-sem-boas-vindas -boasVindasVistas YES -calendarioALer NO
abrir apos-abertura-interrompida -boasVindasVistas YES

cp "$HOME"/Library/Logs/DiagnosticReports/ToDo* "$SAIDA/" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" || true
exit "$falhou"
