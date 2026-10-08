#!/usr/bin/env bash
# ==============================================================================
# Prueba de punta a punta del MONTAJE, no de las hipótesis.
#
# Verifica que todo lo que el veredicto necesita existe y fluye: compila y pasa
# las pruebas, levanta la topología, Prometheus raspa a los 12 micros y a
# RabbitMQ, las consultas de los tableros responden, el humo de E01 y E02 corre,
# cada tipo de evento llega al registro y cada criterio tiene casos.
#
# Que H1 o H2 pasen o fallen es el resultado del experimento, y se informa
# aparte sin hacer fallar el e2e: D3 falla por diseño si el sondeo no ve el
# pedido congelado. Lo que sí lo hace fallar es un criterio sin casos (NO
# APLICA), un tipo de evento ausente, un duplicado o un panel roto.
#
# Uso: ./load/e2e.sh        Sale con 0 si el montaje está sano.
# ==============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
COMPOSE=(docker compose -f deploy/docker-compose.yml)
export STAMP="e2e-$(date +%Y%m%d-%H%M%S)"
FALLAS=0
INFORME=()

titulo() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()     { printf '  \033[32m✓\033[0m %s\n' "$*"; INFORME+=("ok	$*"); }
falla()  { printf '  \033[31m✗\033[0m %s\n' "$*"; INFORME+=("FALLA	$*"); FALLAS=$((FALLAS + 1)); }
sql()    { "${COMPOSE[@]}" exec -T postgres psql -U reto2 -d reto2 -qtA -c "$1"; }

titulo "1. Compilación y pruebas unitarias"
if ./gradlew build --console=plain -q >/tmp/e2e-gradle.log 2>&1; then
  ok "gradle build y pruebas unitarias"
else
  falla "gradle build: ver /tmp/e2e-gradle.log"; tail -20 /tmp/e2e-gradle.log
  exit 1
fi

titulo "2. Topología"
if make -s up >/tmp/e2e-up.log 2>&1; then ok "los 12 micros responden /actuator/health"; else
  falla "make up: ver /tmp/e2e-up.log"; tail -20 /tmp/e2e-up.log; exit 1; fi

titulo "3. Observabilidad"
sleep 6   # un par de raspados de Prometheus
arriba=$(curl -s localhost:9090/api/v1/targets | python3 -c '
import json,sys
t=json.load(sys.stdin)["data"]["activeTargets"]
caidos=[x["labels"]["instance"] for x in t if x["health"]!="up"]
print(len(t)-len(caidos), len(t), " ".join(caidos))')
read -r vivos total caidos <<<"$arriba"
if [ "$vivos" = "$total" ] && [ "$total" -ge 13 ]; then ok "Prometheus raspa $vivos de $total objetivos"
else falla "Prometheus raspa $vivos de $total objetivos; caídos: $caidos"; fi
for uid in e01 e02; do
  if curl -fs "localhost:3000/api/dashboards/uid/$uid" >/dev/null; then ok "tablero $uid aprovisionado en Grafana"
  else falla "tablero $uid no está en Grafana"; fi
done

titulo "4. Humo de E01 y E02 (~7 min)"
./load/experimento.sh humo | sed 's/^/  /'

titulo "5. El cruce: cada criterio con casos y cada evento en el registro"
for corrida in "humo-e01-$STAMP" "humo-e02-$STAMP"; do
  v="analisis/resultados/$corrida/veredicto.txt"
  if [ ! -s "$v" ]; then falla "$corrida no dejó veredicto"; continue; fi
  sin_casos=$(grep -c '| NO APLICA *$' "$v")
  if [ "$sin_casos" -eq 0 ]; then ok "$corrida: todos los criterios tienen casos"
  else falla "$corrida: $sin_casos criterios sin casos (NO APLICA)"; fi
  [ -s "analisis/resultados/$corrida/eventos-$corrida.csv" ] && ok "$corrida: eventos exportados a CSV" \
    || falla "$corrida: falta el CSV de eventos"
done

# Cada tipo de evento que el veredicto cruza tiene que haber llegado en la corrida.
esperados="sesion.abierta huella.comparada aviso.emitido aviso.recibido dispositivo.registrado
pedido.confirmado etapa.completada pedido.listo pedido.en.logistica alerta.notificada
falla.inyectada sondeo.fallido etapa.declarada.detenida pedido.encolado mensaje.en.cola
etapa.reiniciada etapa.recuperada falla.congelada"
presentes=$(sql "SELECT DISTINCT e.tipo FROM registro.evento e, registro.corrida c
                 WHERE c.id LIKE 'humo-%-$STAMP' AND e.ts BETWEEN c.arranque AND c.fin + interval '60 seconds'")
faltan=""
for t in $esperados; do grep -qx "$t" <<<"$presentes" || faltan="$faltan $t"; done
if [ -z "$faltan" ]; then ok "los $(echo $esperados | wc -w | tr -d ' ') tipos de evento llegaron al registro"; else falla "faltan eventos:$faltan"; fi

dup=$(grep -E '^ *Todas · cada pedido encolado' "analisis/resultados/humo-e02-$STAMP/veredicto.txt" | grep -c 'PASA')
[ "$dup" = 1 ] && ok "E02: cero perdidos y cero duplicados en la cola" || falla "E02: hay pedidos perdidos o duplicados en la cola"

titulo "6. Los tableros sobre los datos del humo"
if python3 deploy/observabilidad/verificar-tableros.py --vacios; then ok "todas las consultas de los tableros responden con datos"
else falla "hay paneles rotos o vacíos"; fi

titulo "Resultado de las hipótesis en el humo (informativo, no hace fallar el e2e)"
grep -hE '\| (PASA|FALLA|NO APLICA) *$' "analisis/resultados/humo-e01-$STAMP/veredicto.txt" \
  "analisis/resultados/humo-e02-$STAMP/veredicto.txt" 2>/dev/null | sed 's/^ */  /'

titulo "Resumen del e2e"
printf '%s\n' "${INFORME[@]}" | column -t -s$'\t' | sed 's/^/  /'
if [ "$FALLAS" -eq 0 ]; then
  printf '\n  \033[32mEl montaje está sano.\033[0m Tableros: http://localhost:3000/d/e01 · /d/e02\n'
else
  printf '\n  \033[31m%d verificaciones fallaron.\033[0m\n' "$FALLAS"
fi
exit $((FALLAS > 0))
