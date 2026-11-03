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
  local saida pid tamanho
  saida=$(xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE")
  pid=${saida##*: }
  echo "$nome: pid $pid"
  sleep 15
  xcrun simctl io "$UDID" screenshot "$SAIDA/$nome-15s.png" > /dev/null 2>&1 || true
  sleep 25
  xcrun simctl io "$UDID" screenshot "$SAIDA/$nome-40s.png" > /dev/null 2>&1 || true
  sample "$pid" 5 -file "$SAIDA/$nome-sample.txt" > /dev/null 2>&1 || echo "$nome: sem sample"
  xcrun simctl spawn "$UDID" log show --last 1m --style compact \
    --predicate 'process == "ToDo"' > "$SAIDA/$nome-log.txt" 2>&1 || true

  if ! xcrun simctl spawn "$UDID" launchctl list | grep -q "UIKitApplication:$BUNDLE"; then
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
}

abrir sem-calendario
xcrun simctl privacy "$UDID" grant calendar "$BUNDLE" || echo "Não foi possível autorizar o calendário"
abrir com-calendario

cp "$HOME"/Library/Logs/DiagnosticReports/ToDo* "$SAIDA/" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" || true
exit "$falhou"
