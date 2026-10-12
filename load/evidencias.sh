#!/usr/bin/env bash
# Evidencias de un solo caso, para capturar en pantalla: el estímulo a un lado
# y la respuesta del sistema al otro. Es una demostración, no una medición:
# las cifras de results.md salen de las corridas de decisión.
#
#   load/evidencias.sh intruso      # ASR-1: sesión desde un dispositivo que no es el suyo
#   load/evidencias.sh cambio       # ASR-1: cambio legítimo de dispositivo, sin aviso
#   load/evidencias.sh congelado    # ASR-4: pedido congelado en una etapa viva
#   load/evidencias.sh caida        # ASR-4: etapa caída con pedidos pendientes
#   load/evidencias.sh repetida     # ASR-4: entrega repetida a una etapa que ya terminó
#   load/evidencias.sh mirar <caso> # la respuesta: los logs del caso, filtrados
#   load/evidencias.sh limpiar      # operación reiniciada, colas vacías y Monitor nuevo
set -euo pipefail
cd "$(dirname "$0")/.."

COMPOSE="docker compose -f deploy/docker-compose.yml"
psql_q() { $COMPOSE exec -T postgres psql -U reto2 -d reto2 -qtA -F ' · ' -c "$1"; }
titulo() { printf '\n\033[1m%s\033[0m\n%s\n\n' "$1" "$2"; }
paso() { printf '\033[2m$ %s\033[0m\n' "$1"; }
hora() { python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).strftime("%H:%M:%S.%f")[:-3])'; }

abrir_sesion() {   # vendedor dispositivo sesion
  local cuerpo
  cuerpo=$(printf '{"sesionId":"%s","vendedorId":"%s","password":"clave-%s","dispositivoId":"%s"}' "$3" "$1" "$1" "$2")
  paso "curl -X POST localhost:8081/sesiones -d '$cuerpo'"
  printf 'enviada a las %s UTC\n' "$(hora)"
  curl -s -o /dev/null -w 'respuesta: HTTP %{http_code} en %{time_total} s · el inicio de sesión no espera la comparación\n' \
    -X POST localhost:8081/sesiones -H 'Content-Type: application/json' -d "$cuerpo"
}

mirar() {
  local servicios filtro
  case "$1" in
    intruso|cambio) servicios="usuario-no-valido receptor-sms"; filtro='huella|SMS' ;;
    congelado|caida) servicios="monitor ventas"; filtro='atascado|declarada|Dead-Letter' ;;
    repetida) servicios="etapa-facturacion etapa-inventario etapa-despacho"; filtro='entrega repetida' ;;
    *) echo "caso desconocido: $1" >&2; exit 2 ;;
  esac
  titulo "Respuesta del sistema" "Logs de: $servicios"
  $COMPOSE logs -f --since 1s --no-log-prefix $servicios 2>/dev/null \
    | grep --line-buffered -E "$filtro" \
    | sed -u -E -e 's/^[0-9-]+T([0-9:.]+)Z +[A-Z]+ +1 --- \[[^]]+\] \[[^]]+\] [^:]+: /\1  /' -e 's/manual-[0-9]+-//g'
}

case "${1:-}" in
  intruso)
    titulo "Estímulo · ASR-1" "El vendedor V1961 abre sesión con sus credenciales correctas desde un dispositivo que CCP no le entregó."
    paso "psql: SELECT dispositivo_registrado FROM operacion.vendedor WHERE id = 'V1961'"
    printf 'dispositivo registrado: %s\n\n' "$(psql_q "SELECT dispositivo_registrado FROM operacion.vendedor WHERE id = 'V1961'")"
    abrir_sesion V1961 D-ATACANTE-DEMO "DEMO-INTRUSO-$(date +%s)"
    ;;
  cambio)
    titulo "Estímulo · ASR-1, el contraste" "El vendedor V0777 recibe un dispositivo nuevo: se registra y abre sesión desde él un instante después."
    nuevo="D-V0777-$(date +%s)"
    paso "curl -X POST localhost:8084/vendedores/V0777/dispositivos -d '{\"dispositivoId\":\"$nuevo\"}'"
    curl -s -o /dev/null -w 'registrado: HTTP %{http_code}\n\n' -X POST localhost:8084/vendedores/V0777/dispositivos \
      -H 'Content-Type: application/json' -d "{\"dispositivoId\":\"$nuevo\"}"
    abrir_sesion V0777 "$nuevo" "DEMO-CAMBIO-$(date +%s)"
    ;;
  congelado)
    titulo "Estímulo · ASR-4" "Validación de despacho acepta el próximo pedido y lo olvida; la etapa sigue viva."
    paso "docker exec inyector inyectar congelar despacho"
    docker exec inyector inyectar congelar despacho
    printf 'congelado pedido entrante a las %s UTC\n\n' "$(hora)"
    paso "cada 2 s: curl localhost:8093/salud?mayorQueMs=15000"
    for _ in $(seq 1 11); do
      sleep 2
      printf '%s  ' "$(hora)"
      curl -s -w '\n%{http_code}\n' "localhost:8093/salud?mayorQueMs=15000" | python3 -c '
import json, re, sys
cuerpo, codigo = sys.stdin.read().strip().rsplit("\n", 1)
s = json.loads(cuerpo)
at = ", ".join("%s (%.1f s)" % (re.sub(r"manual-[0-9]+-", "", a["pedidoId"]), a["edadMs"] / 1000) for a in s["atascados"]) or "ninguno"
print("HTTP %s · etapa viva · en curso %d · atascados: %s" % (codigo, s["enCurso"], at))'
    done
    pedido=$(psql_q "SELECT pedido_id FROM registro.evento WHERE tipo = 'falla.congelada' ORDER BY ts DESC LIMIT 1")
    printf '\n'
    paso "psql: el pedido $(sed -E 's/manual-[0-9]+-//' <<<"$pedido") en ventas, etapa por etapa"
    psql_q "SELECT string_agg(etapa || ' ' || estado, '  ·  '
                   ORDER BY array_position(ARRAY['facturacion','inventario','despacho'], etapa))
            FROM operacion.pedido_etapa WHERE pedido_id = '$pedido'"
    ;;
  caida)
    titulo "Estímulo · ASR-4" "Descargue de inventario muere con pedidos en curso y vuelve 20 s después."
    paso "docker exec inyector inyectar matar inventario 20"
    printf 'caída a las %s UTC\n' "$(hora)"
    docker exec inyector inyectar matar inventario 20
    ;;
  repetida)
    titulo "Estímulo · ASR-4" "El bróker le vuelve a entregar a facturación un pedido que ya facturó."
    pedido=$(psql_q "SELECT pedido_id FROM operacion.recibo_etapa WHERE etapa = 'facturacion'
                     AND estado = 'TERMINADA' ORDER BY recibido_en DESC LIMIT 1")
    cuenta() {
      psql_q "SELECT 'entregas a facturación: ' || entregas || ' · facturas emitidas: ' ||
                     (SELECT count(*) FROM registro.evento WHERE tipo = 'etapa.efecto.aplicado'
                      AND pedido_id = '$pedido' AND etapa = 'facturacion')
              FROM operacion.recibo_etapa WHERE pedido_id = '$pedido' AND etapa = 'facturacion'"
    }
    paso "psql: el pedido $pedido antes de la entrega repetida"
    cuenta
    echo
    paso "POST localhost:15672/api/exchanges/%2F/cadena/publish · routing_key etapa.ejecutar.facturacion"
    cuerpo=$(printf '{"pedidoId":"%s","etapa":"facturacion"}' "$pedido" | sed 's/"/\\"/g')
    printf 'entregado otra vez a las %s UTC\n' "$(hora)"
    curl -s -u reto2:reto2 -H 'content-type: application/json' -X POST \
      "localhost:15672/api/exchanges/%2F/cadena/publish" \
      -d "{\"properties\":{\"content_type\":\"application/json\"},\"routing_key\":\"etapa.ejecutar.facturacion\",\"payload\":\"$cuerpo\",\"payload_encoding\":\"string\"}"
    printf '\n\n'
    sleep 1
    paso "psql: el mismo pedido después"
    cuenta
    ;;
  limpiar)
    psql_q "SELECT operacion.reiniciar()" >/dev/null
    for cola in verificador.sesiones notificador.alertas etapa.facturacion etapa.inventario etapa.despacho \
                ventas.completadas logistica.pedidos dead-letter-queue dead-letter-queue.auditoria; do
      $COMPOSE exec -T rabbitmq rabbitmqctl -q purge_queue "$cola" >/dev/null 2>&1 || true
    done
    $COMPOSE up -d --force-recreate --no-deps monitor >/dev/null 2>&1
    echo "operación reiniciada, colas vacías y Monitor nuevo"
    ;;
  mirar) mirar "${2:-}" ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
