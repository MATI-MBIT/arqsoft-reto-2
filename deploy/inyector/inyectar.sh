#!/usr/bin/env bash
# ==============================================================================
# Inyector de fallas de E02. Corre dentro del contenedor `inyector`, que tiene el
# socket de Docker y acceso a la base. El orquestador lo invoca así:
#
#   docker exec inyector inyectar matar <etapa> <segundos-caida>   # D2
#   docker exec inyector inyectar congelar <etapa>                 # D3
#
# matar: anota falla.inyectada (t0 de D2) y mata el proceso de la etapa con
# SIGKILL (D-3). Al cerrar la ventana la levanta y anota etapa.reiniciada cuando
# vuelve a responder. El t0 se anota justo antes del kill: la demora medida
# queda, si acaso, unos milisegundos por encima de la real.
# ==============================================================================
set -euo pipefail

anotar() { # tipo etapa datos-json
  psql -qtA -c "INSERT INTO registro.evento (ts, componente, tipo, etapa, datos)
                VALUES (clock_timestamp(), 'inyector', '$1', '$2', '$3'::jsonb)"
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
  *)
    echo "uso: inyectar matar <etapa> <segundos> | inyectar congelar <etapa>" >&2; exit 2 ;;
esac
