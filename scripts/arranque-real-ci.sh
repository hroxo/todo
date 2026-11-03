#!/usr/bin/env bash
# Corre no CI, depois das capturas. O modo de demonstração salta a base de dados real, os avisos
# e o calendário: aqui a app abre como no iPhone, com o calendário autorizado, e tem de continuar
# viva. Sem assinatura não há iCloud nem App Group, por isso o caminho com iCloud só se prova no iPhone.
#   scripts/arranque-real-ci.sh <ToDo.app do simulador> <pasta de saída>
set -euo pipefail

BUNDLE="com.hugo.tudo"
APP="$1"
SAIDA="$2"
UDID=$(cat "${RUNNER_TEMP:-/tmp}/simulador-udid")

xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant calendar "$BUNDLE" || echo "Não foi possível autorizar o calendário"
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" > /dev/null
sleep 20

mkdir -p "$SAIDA/escuro"
xcrun simctl io "$UDID" screenshot "$SAIDA/escuro/15-arranque-real.png" > /dev/null || true

if ! xcrun simctl spawn "$UDID" launchctl list | grep -q "UIKitApplication:$BUNDLE"; then
  echo "::error::A app morreu no arranque real (sem modo de demonstração)."
  exit 1
fi
xcrun simctl terminate "$UDID" "$BUNDLE" || true
echo "Arranque real sem crash"
