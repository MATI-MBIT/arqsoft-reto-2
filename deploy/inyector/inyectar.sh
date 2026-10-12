#!/usr/bin/env bash
# ==============================================================================
# Inyector de fallas de E02. Corre dentro del contenedor `inyector`, que tiene el
# socket de Docker y acceso a la base. El orquestador lo invoca así:
#
#   docker exec inyector inyectar matar <etapa> <segundos-caida>   # D2
#   docker exec inyector inyectar congelar <etapa>                 # D3
#   docker exec inyector inyectar repetir <etapa>                  # D5
#
# matar: anota falla.inyectada (t0 de D2) y mata el proceso de la etapa con
# SIGKILL (D-3). Al cerrar la ventana la levanta y anota etapa.reiniciada cuando
# vuelve a responder. El t0 se anota justo antes del kill: la demora medida
# queda, si acaso, unos milisegundos por encima de la real.
#
# repetir: toma al azar un pedido que la etapa ya terminó, anota la falla con su
# identificador y le vuelve a publicar etapa.ejecutar por la API de RabbitMQ,
# como lo haría el bróker tras una caída o quien reprocese la Dead-Letter-Queue.
# ==============================================================================
set -euo pipefail

anotar() { # tipo etapa datos-json
  psql -qtA -c "INSERT INTO registro.evento (ts, componente, tipo, etapa, datos)
                VALUES (clock_timestamp(), 'inyector', '$1', '$2', '$3'::jsonb)"
}

anotar_pedido() { # tipo etapa pedido datos-json
  psql -qtA -c "INSERT INTO registro.evento (ts, componente, tipo, pedido_id, etapa, datos)
                VALUES (clock_timestamp(), 'inyector', '$1', '$3', '$2', '$4'::jsonb)"
}

etapa_valida() {
  case "$1" in facturacion|inventario|despacho) ;; *) echo "etapa desconocida: $1" >&2; exit 2 ;; esac
}

case "${1:-}" in
  matar)
    etapa="$2"; caida="${3:-45}"; etapa_valida "$etapa"
    anotar falla.inyectada "$etapa" "{\"tipo\":\"matar\",\"caidaS\":$caida}"
    docker kill --signal KILL "etapa-$etapa" >/dev/null
    sleep "$caida"
    docker start "etapa-$etapa" >/dev/null
    for _ in $(seq 1 120); do
      if curl -fs -m 1 "http://etapa-$etapa:8080/salud" >/dev/null; then
        anotar etapa.reiniciada "$etapa" '{}'
        exit 0
      fi
      sleep 0.5
    done
    echo "la etapa $etapa no volvió a responder en 60 s" >&2; exit 1
    ;;
  congelar)
    etapa="$2"; etapa_valida "$etapa"
    anotar falla.inyectada "$etapa" '{"tipo":"congelar"}'
    curl -fs -m 2 -X POST "http://etapa-$etapa:8080/fallas/congelar" >/dev/null
    ;;
  repetir)
    etapa="$2"; etapa_valida "$etapa"
    pedido=$(psql -qtA -c "SELECT pedido_id FROM operacion.recibo_etapa
                           WHERE etapa = '$etapa' AND estado = 'TERMINADA' ORDER BY random() LIMIT 1")
    [ -n "$pedido" ] || { echo "la etapa $etapa no tiene pedidos terminados" >&2; exit 1; }
    anotar_pedido falla.inyectada "$etapa" "$pedido" '{"tipo":"repetir"}'
    cuerpo=$(printf '{"pedidoId":"%s","etapa":"%s"}' "$pedido" "$etapa" | sed 's/"/\\"/g')
    curl -fs -m 2 -u "$RABBIT_USER:$RABBIT_PASSWORD" -H 'content-type: application/json' \
      -X POST "$RABBIT_API/exchanges/%2F/cadena/publish" \
      -d "{\"properties\":{\"content_type\":\"application/json\"},\"routing_key\":\"etapa.ejecutar.$etapa\",\"payload\":\"$cuerpo\",\"payload_encoding\":\"string\"}" \
      | grep -q '"routed":true' || { echo "el bróker no enrutó la entrega repetida de $pedido" >&2; exit 1; }
    ;;
  *)
    echo "uso: inyectar matar <etapa> <segundos> | inyectar congelar <etapa> | inyectar repetir <etapa>" >&2; exit 2 ;;
esac
