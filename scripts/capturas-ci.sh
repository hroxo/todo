#!/usr/bin/env bash
# Corre no CI (macOS). Duas fases:
#   scripts/capturas-ci.sh arrancar
#     escolhe o simulador e começa a arrancá-lo, sem esperar (o primeiro arranque demora
#     vários minutos e corre enquanto o CI testa e compila);
#   scripts/capturas-ci.sh <ToDo.app do simulador> <pasta de saída>
#     instala a app, abre cada ecrã em modo de demonstração e tira a captura em escuro e
#     em claro sem reabrir a app.
set -euo pipefail

BUNDLE="com.hugo.todo"
FICHEIRO_UDID="${RUNNER_TEMP:-/tmp}/simulador-udid"

escolher_simulador() {
  # O iPhone do runtime iOS mais recente, de preferência um "Pro" (não Max).
  xcrun simctl list devices available -j | python3 -c '
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
'
}

if [ "${1:-}" = "arrancar" ]; then
  UDID=$(escolher_simulador)
  echo "$UDID" > "$FICHEIRO_UDID"
  echo "A arrancar o simulador $UDID (em segundo plano)"
  nohup xcrun simctl boot "$UDID" > /dev/null 2>&1 &
  exit 0
fi

APP="$1"
SAIDA="$2"

if [ -f "$FICHEIRO_UDID" ]; then
  UDID=$(cat "$FICHEIRO_UDID")
else
  UDID=$(escolher_simulador)
  xcrun simctl boot "$UDID" || true
fi
echo "Simulador: $UDID"

inicio=$(date +%s)
xcrun simctl bootstatus "$UDID" -b > /dev/null
echo "Simulador pronto em $(( $(date +%s) - inicio )) s"
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 || true
mkdir -p "$SAIDA/escuro" "$SAIDA/claro"

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
  "13-expirados-filtro|expirados-filtro|"
  "14-evento|evento|"
)

primeira=1
for entrada in "${ECRAS[@]}"; do
  IFS='|' read -r nome ecra extra <<< "$entrada"
  xcrun simctl ui "$UDID" appearance dark
  # shellcheck disable=SC2086
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -demo YES -ecra "$ecra" $extra > /dev/null
  if [ "$primeira" = 1 ]; then sleep 8; primeira=0; else sleep 3; fi
  xcrun simctl io "$UDID" screenshot "$SAIDA/escuro/$nome.png" > /dev/null
  # O tema muda com a app aberta; basta esperar pela transição.
  xcrun simctl ui "$UDID" appearance light
  sleep 1.5
  xcrun simctl io "$UDID" screenshot "$SAIDA/claro/$nome.png" > /dev/null
  echo "  $nome"
done

xcrun simctl terminate "$UDID" "$BUNDLE" || true
echo "Capturas em $(( $(date +%s) - inicio )) s"
