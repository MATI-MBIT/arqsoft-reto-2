#!/usr/bin/env bash
# ==============================================================================
# El único orquestador de los experimentos E01 y E02.
#
# QUÉ se corre es dato (load/plan.tsv); CÓMO se corre es este archivo. Cada
# corrida sigue el mismo ciclo:
#
#   1. preparar   etapas arriba, operación reiniciada, colas vacías y el Monitor
#                 recreado con el T y el N de la fila
#   2. calentar   la carga de fondo corre WARMUP_S; nada de esto entra al veredicto
#   3. medir      E01: la fase de k6 · E02: D1_S sin fallas, REPS caídas, CONGELAR
#                 congelamientos, en ese orden
#   4. cerrar     GRACIA_S más con carga, para que lleguen las salidas tardías
#   5. veredicto  analisis/e01.sql o e02.sql sobre el registro de eventos
#
# Uso:  ./load/experimento.sh                 # el plan completo
#       ./load/experimento.sh e01 e02         # los grupos que se indiquen
#       ./load/experimento.sh humo            # el humo (~7 min)
# ==============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE=(docker compose -f "$ROOT/deploy/docker-compose.yml")
PLAN="$ROOT/load/plan.tsv"
STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"   # el e2e lo fija para encontrar los resultados
RESULTADOS="$ROOT/analisis/resultados"
RESUMEN="$RESULTADOS/resumen-$STAMP.tsv"
mkdir -p "$RESULTADOS"

# k6 empuja sus métricas a Prometheus para verlas junto a las de los micros.
export K6_PROMETHEUS_RW_SERVER_URL="${K6_PROMETHEUS_RW_SERVER_URL:-http://localhost:9090/api/v1/write}"
export K6_PROMETHEUS_RW_TREND_STATS="${K6_PROMETHEUS_RW_TREND_STATS:-p(50),p(95),p(99),max}"
export K6_PROMETHEUS_RW_PUSH_INTERVAL="${K6_PROMETHEUS_RW_PUSH_INTERVAL:-5s}"
K6_OUT=(-o experimental-prometheus-rw)

# Una corrida suspendida queda contaminada: la máquina de Docker se congela, k6
# deja de generar llegadas y los relojes saltan. caffeinate evita la suspensión
# por inactividad, pero no con batería ni con la tapa cerrada: con batería no se
# arranca, salvo FORZAR_BATERIA=1. El 2026-10-06 una corrida nocturna con batería
# se suspendió y hubo que repetir E01 entero.
if command -v pmset >/dev/null && pmset -g batt | grep -q "Battery Power" && [ "${FORZAR_BATERIA:-0}" != 1 ]; then
  echo "El equipo está con batería y macOS lo suspenderá a mitad de la corrida." >&2
  echo "Conéctalo a la corriente, o corre con FORZAR_BATERIA=1 bajo tu propio riesgo." >&2
  exit 1
fi
command -v caffeinate >/dev/null && caffeinate -dims -w $$ &

# Hueco máximo admitido entre dos pedidos de la carga de fondo (1 por segundo).
# En corridas sanas no pasa de 13 s; uno mayor que el plazo de ASR-3 (30 s) solo
# sale si la máquina se congeló. En macOS se mira además el registro de
# suspensiones. Una corrida contaminada no se retoma: se marca inválida y el
# ciclo completo vuelve a empezar desde la primera corrida, hasta REINTENTOS
# veces, para que todas las corridas de un ciclo corran seguidas.
HUECO_MAX_S="${HUECO_MAX_S:-30}"
REINTENTOS="${REINTENTOS:-1}"

log() { printf '\033[1m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }

sql() { "${COMPOSE[@]}" exec -T postgres psql -U reto2 -d reto2 -qtA -v ON_ERROR_STOP=1 "$@"; }

esperar_salud() { # puerto
  for _ in $(seq 1 90); do
    curl -fs -m 1 "http://localhost:$1/actuator/health" >/dev/null && return 0
    sleep 1
  done
  log "el micro del puerto $1 no respondió en 90 s"; return 1
}

MICROS="8081 8082 8083 8084 8090 8091 8092 8093 8094 8095 8096 8097"

preparar() {
  # Toda la topología arriba, no solo las etapas: si Docker se reinició (una
  # actualización automática lo hizo a mitad de una corrida el 2026-10-07), la
  # base y el bróker también cayeron.
  "${COMPOSE[@]}" up -d >/dev/null 2>&1
  for p in $MICROS; do esperar_salud "$p" || return 1; done
  sql -c "SELECT operacion.reiniciar()" >/dev/null
  # Las colas se vacían para que el trabajo pendiente de una corrida no llegue a la siguiente.
  for cola in verificador.sesiones notificador.alertas etapa.facturacion etapa.inventario etapa.despacho ventas.completadas logistica.pedidos dead-letter-queue dead-letter-queue.auditoria; do
    "${COMPOSE[@]}" exec -T rabbitmq rabbitmqctl -q purge_queue "$cola" >/dev/null 2>&1 || true
  done
  # El Monitor se recrea en cada corrida: arranca sin cuentas viejas y con el T y N de la fila.
  SONDEO_T_MS="$SONDEO_T_MS" SONDEO_N="$SONDEO_N" SONDEO_ESPERA_MS="$SONDEO_ESPERA_MS" \
    "${COMPOSE[@]}" up -d --force-recreate --no-deps monitor >/dev/null 2>&1
  esperar_salud 8095
}

# Las caídas de D2 se reparten por igual entre las tres etapas, en orden aleatorio.
orden_de_etapas() { # cuantas
  local etapas=(facturacion inventario despacho)
  for i in $(seq 0 $(($1 - 1))); do echo "${etapas[$((i % 3))]}"; done | sort -R
}

medir_e02() { # dir
  if [ "$D1_S" -gt 0 ]; then
    log "  D1: ${D1_S} s sin fallas"
    sleep "$D1_S"
  fi
  if [ "$REPS" -gt 0 ]; then
    local i=0
    for etapa in $(orden_de_etapas "$REPS"); do
      i=$((i + 1))
      log "  D2 $i/$REPS: se mata $etapa por ${CAIDA_S} s"
      docker exec inyector inyectar matar "$etapa" "$CAIDA_S" >>"$1/inyector.log" 2>&1 \
        || log "  la etapa $etapa no volvió: ver $1/inyector.log"
      sleep "$PAUSA_S"
    done
  fi
  if [ "$CONGELAR" -gt 0 ]; then
    local i=0
    for etapa in $(orden_de_etapas "$CONGELAR"); do
      i=$((i + 1))
      log "  D3 $i/$CONGELAR: se congela el próximo pedido de $etapa"
      docker exec inyector inyectar congelar "$etapa" >>"$1/inyector.log" 2>&1
      sleep "$ESPACIO_S"
    done
  fi
}

correr() { # grupo id experimento fase criterio vars pregunta
  local grupo="$1" id="$2" experimento="$3" fase="$4" criterio="$5" vars="$6" pregunta="$7"

  # Valores por omisión; la fila los sobrescribe.
  WARMUP_S=300 TASA_BASE=2 SONDEO_T_MS=2000 SONDEO_N=3 SONDEO_ESPERA_MS=500
  D1_S=0 REPS=0 CAIDA_S=45 PAUSA_S=30 CONGELAR=0 ESPACIO_S=60 GRACIA_S=60
  if [ "$vars" != "-" ]; then
    IFS=';' read -ra pares <<<"$vars"
    for kv in "${pares[@]}"; do printf -v "${kv%%=*}" '%s' "${kv#*=}"; done
  fi

  local corrida="$id-$STAMP" dir="$RESULTADOS/$id-$STAMP"
  mkdir -p "$dir"
  log "== $corrida · $experimento $fase · $pregunta"
  local variables
  variables=$(printf '{"T_ms":%s,"N":%s,"espera_ms":%s,"tasa_base":%s,"d1_s":%s,"caidas":%s,"caida_s":%s,"congelar":%s,"vars":"%s"}' \
    "$SONDEO_T_MS" "$SONDEO_N" "$SONDEO_ESPERA_MS" "$TASA_BASE" "$D1_S" "$REPS" "$CAIDA_S" "$CONGELAR" "$vars")

  preparar || { log "no se pudo preparar la topología"; return 1; }
  sql -c "INSERT INTO registro.corrida (id, experimento, fase, variables, arranque)
          VALUES ('$corrida', '$experimento', '$fase', '$variables'::jsonb, clock_timestamp())"

  # La carga de fondo del Ambiente A corre durante toda la corrida.
  # La etiqueta guion separa las series de los dos k6 de la corrida: con la misma
  # etiqueta, Prometheus rechaza el lote entero por muestras duplicadas.
  (cd "$ROOT/load/k6" && exec k6 run -q "${K6_OUT[@]}" --tag corrida="$corrida" --tag guion=cadena \
      -e CORRIDA="$corrida" cadena.js >"$dir/k6-cadena.txt" 2>&1) &
  local cadena=$!

  log "  calentamiento: ${WARMUP_S} s"
  if [ "$experimento" = E01 ]; then
    (cd "$ROOT/load/k6" && k6 run -q "${K6_OUT[@]}" --tag corrida="$corrida" --tag guion=e01 -e CORRIDA="$corrida" \
        -e FASE=CALENTAMIENTO -e DURACION="${WARMUP_S}s" -e TASA_BASE="$TASA_BASE" e01.js \
        >"$dir/k6-calentamiento.txt" 2>&1)
  else
    sleep "$WARMUP_S"
  fi
  sql -c "UPDATE registro.corrida SET inicio = clock_timestamp() WHERE id = '$corrida'"

  if [ "$experimento" = E01 ]; then
    log "  fase $fase en k6"
    (cd "$ROOT/load/k6" && k6 run "${K6_OUT[@]}" --tag corrida="$corrida" --tag guion=e01 -e CORRIDA="$corrida" \
        -e FASE="$fase" -e TASA_BASE="$TASA_BASE" e01.js >"$dir/k6-$fase.txt" 2>&1)
  else
    medir_e02 "$dir"
  fi
  sql -c "UPDATE registro.corrida SET fin = clock_timestamp() WHERE id = '$corrida'"

  log "  gracia: ${GRACIA_S} s para las salidas tardías"
  sleep "$GRACIA_S"
  kill -INT "$cadena" 2>/dev/null; wait "$cadena" 2>/dev/null
  sleep 1   # el registro de cada micro se vacía cada 200 ms

  local script; script=$(echo "$experimento" | tr 'A-Z' 'a-z')
  "${COMPOSE[@]}" exec -T postgres psql -U reto2 -d reto2 -v corrida="$corrida" \
      -f "/analisis/$script.sql" >"$dir/veredicto.txt" 2>&1
  sql -c "\copy (SELECT e.* FROM registro.evento e, registro.corrida c WHERE c.id = '$corrida' AND e.ts BETWEEN c.arranque AND c.fin + interval '${GRACIA_S} seconds' ORDER BY e.ts) TO STDOUT WITH CSV HEADER" >"$dir/eventos-$corrida.csv"
  cp "$PLAN" "$dir/plan.tsv"

  # Enlaces a los tableros fijados en la ventana de la corrida: la evidencia
  # visual se puede volver a abrir mientras Prometheus conserve la serie (15 d).
  local desde hasta tab
  desde=$(sql -c "SELECT (extract(epoch FROM arranque) * 1000)::bigint FROM registro.corrida WHERE id = '$corrida'")
  hasta=$(sql -c "SELECT (extract(epoch FROM fin + interval '${GRACIA_S} seconds') * 1000)::bigint FROM registro.corrida WHERE id = '$corrida'")
  tab=$(echo "$experimento" | tr 'A-Z' 'a-z')
  printf 'tablero  http://localhost:3000/d/%s?from=%s&to=%s\nkiosco   http://localhost:3000/d/%s?from=%s&to=%s&kiosk\n' \
    "$tab" "$desde" "$hasta" "$tab" "$desde" "$hasta" >"$dir/tablero.txt"

  # Validez: si la máquina se congeló, la carga de fondo deja un hueco.
  local hueco
  hueco=$(sql -c "SELECT coalesce(round(extract(epoch FROM max(hueco))::numeric, 1), 0) FROM (SELECT e.ts - lag(e.ts) OVER (ORDER BY e.ts) AS hueco FROM registro.evento e, registro.corrida c WHERE c.id = '$corrida' AND e.tipo = 'pedido.confirmado' AND e.ts BETWEEN c.arranque AND c.fin) x")
  local suspensiones=0 desde_local hasta_local
  local epoch_arranque
  epoch_arranque=$(sql -c "SELECT extract(epoch FROM arranque)::bigint FROM registro.corrida WHERE id = '$corrida'" 2>/dev/null)
  # Sin respuesta de la base, la corrida no se puede validar: se da por contaminada.
  [ -n "$hueco" ] || hueco=9999
  if command -v pmset >/dev/null && [ -n "$epoch_arranque" ]; then
    desde_local=$(date -r "$epoch_arranque" '+%Y-%m-%d %H:%M:%S')
    hasta_local=$(date '+%Y-%m-%d %H:%M:%S')
    suspensiones=$(pmset -g log | awk -v a="$desde_local" -v b="$hasta_local" \
      'substr($0, 1, 19) >= a && substr($0, 1, 19) <= b && / Sleep  / && /Entering Sleep/' | wc -l | tr -d ' ')
  fi
  # La carga también tiene que ser la del diseño: si un k6 de la medición tuvo
  # más de 1 % de solicitudes fallidas, la corrida no midió el Ambiente A.
  local fallidas
  fallidas=$(grep -h 'http_req_failed' "$dir/k6-cadena.txt" "$dir/k6-$fase.txt" 2>/dev/null \
    | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /%$/) { gsub("%", "", $i); v = $i + 0; if (v > m) m = v } } END { print m + 0 }')
  if [ "$suspensiones" -gt 0 ] || awk -v h="$hueco" -v m="$HUECO_MAX_S" -v f="$fallidas" 'BEGIN { exit !(h > m || f > 1) }'; then
    sql -c "UPDATE registro.corrida SET valida = false, motivo = 'corrida inválida: hueco de $hueco s en la carga de fondo, $suspensiones suspensiones del equipo, $fallidas % de solicitudes de k6 fallidas' WHERE id = '$corrida'"
    mv "$dir" "$dir-contaminada"
    log "  CONTAMINADA: hueco de ${hueco} s (máximo ${HUECO_MAX_S} s), $suspensiones suspensiones, ${fallidas} % de solicitudes fallidas (máximo 1 %). Se descarta: ${dir#"$ROOT"/}-contaminada"
    return 2
  fi

  grep -E '\| (PASA|FALLA|NO APLICA) *$' "$dir/veredicto.txt" | while IFS= read -r linea; do
    printf '%s\t%s\t%s\t%s\n' "$corrida" "$criterio" "$fase" "$linea" >>"$RESUMEN"
  done
  log "  veredicto en ${dir#"$ROOT"/}/veredicto.txt"
  grep -E '\| (PASA|FALLA|NO APLICA) *$' "$dir/veredicto.txt" | sed 's/^/     /'
}

# Sin argumentos corre todo menos el humo. (Bash 3.2 de macOS: un arreglo vacío
# con set -u falla al expandirse, por eso se recorre "$@" y no un arreglo.)
GRUPOS="$*"
pertenece() {
  [ -z "$GRUPOS" ] && { [ "$1" != humo ]; return; }
  for g in $GRUPOS; do [ "$g" = "$1" ] && return 0; done
  return 1
}

# Un ciclo recorre el plan en orden. Si una corrida sale contaminada, devuelve 2
# y el ciclo entero se repite con un sello nuevo.
ciclo() {
  log "resultados en analisis/resultados/ · resumen en ${RESUMEN#"$ROOT"/}"
  # El plan se lee por el descriptor 3: docker compose exec lee la entrada
  # estándar y se comería las filas siguientes.
  while IFS=$'\t' read -r -u 3 grupo id experimento fase criterio vars pregunta; do
    [[ -z "$grupo" || "$grupo" == \#* ]] && continue
    pertenece "$grupo" || continue
    correr "$grupo" "$id" "$experimento" "$fase" "$criterio" "$vars" "$pregunta"
    if [ $? -eq 2 ]; then return 2; fi
  done 3< <(grep -v '^#' "$PLAN")
  return 0
}

BASE="$STAMP"
for intento in $(seq 0 "$REINTENTOS"); do
  if [ "$intento" -gt 0 ]; then
    STAMP="$BASE-r$intento"
    RESUMEN="$RESULTADOS/resumen-$STAMP.tsv"
    log "== se reinicia el ciclo completo (reintento $intento de $REINTENTOS)"
  fi
  ciclo && break
  [ "$intento" -lt "$REINTENTOS" ] || log "el ciclo sigue contaminado tras $REINTENTOS reintentos: no hay veredicto válido"
done

log "listo. Resumen:"
[ -f "$RESUMEN" ] && column -t -s$'\t' "$RESUMEN"
