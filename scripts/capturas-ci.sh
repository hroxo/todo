#!/usr/bin/env bash
# Corre no CI (macOS). Instala a app no simulador, abre cada ecrã em modo de demonstração e
# tira capturas em modo escuro e claro.
# Uso: scripts/capturas-ci.sh <ToDo.app do simulador> <pasta de saída>
set -euo pipefail

APP="$1"
SAIDA="$2"
BUNDLE="com.hugo.todo"

# O iPhone do runtime iOS mais recente, de preferência um "Pro" (não Max).
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
dispositivos = json.load(sys.stdin)["devices"]
candidatos = []
for runtime, lista in dispositivos.items():
    if "iOS" not in runtime:
        continue
    versao = tuple(int(n) for n in re.findall(r"\d+", runtime.split("iOS")[-1]))
    for d in lista:
        if d["name"].startswith("iPhone"):
            nome = d["name"]
            preferido = "Pro" in nome and "Max" not in nome
            candidatos.append((versao, preferido, nome, d["udid"]))
if not candidatos:
    sys.exit("Nenhum simulador de iPhone disponível")
candidatos.sort(key=lambda c: (c[0], c[1], c[2]), reverse=True)
print(candidatos[0][3])
print(candidatos[0][2], candidatos[0][0], file=sys.stderr)
')
echo "Simulador: $UDID"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 || true

# nome do ficheiro | ecrã | argumentos extra
ECRAS=(
  "1-inicio|inicio|"
  "2-lista|lista|"
  "3-detalhe|detalhe|"
  "4-manter-premido|detalhe|-manter premido"
  "5-manter-direita|detalhe|-manter direita"
  "6-captura|captura|"
  "7-personalizar|personalizar|"
  "8-expirados|expirados|"
  "9-concluidos|concluidos|"
  "10-definicoes|definicoes|"
  "11-calendario|calendario|"
  "12-calendario-ligar|calendario|-calendario ligar"
)

primeira=1
for tema in dark light; do
  xcrun simctl ui "$UDID" appearance "$tema"
  pasta="$SAIDA/$([ "$tema" = dark ] && echo escuro || echo claro)"
  mkdir -p "$pasta"
  for entrada in "${ECRAS[@]}"; do
    IFS='|' read -r nome ecra extra <<< "$entrada"
    # shellcheck disable=SC2086
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -demo YES -ecra "$ecra" $extra > /dev/null
    if [ "$primeira" = 1 ]; then sleep 10; primeira=0; else sleep 5; fi
    xcrun simctl io "$UDID" screenshot "$pasta/$nome.png" > /dev/null
    echo "  $pasta/$nome.png"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE" || true
