#!/usr/bin/env python3
"""Ejecuta cada consulta de los tableros de Grafana y falla si alguna da error.

Un panel roto no avisa: muestra «No data» y parece una corrida sin eventos. Por
eso el e2e corre todas las consultas contra la API de Grafana, con la misma
fuente de datos que usa el tablero, sobre la última hora.

Uso: python3 verificar-tableros.py [--vacios]
  --vacios  falla también si una serie del registro de eventos no trae filas.
            Las tablas no cuentan: la de escapes vacía es lo esperado.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

GRAFANA = "http://localhost:3000"
TABLEROS = Path(__file__).parent / "grafana" / "dashboards"


def consultar(target):
    ahora = int(time.time() * 1000)
    cuerpo = {"from": str(ahora - 3_600_000), "to": str(ahora),
              "queries": [dict(target, intervalMs=2000, maxDataPoints=500)]}
    req = urllib.request.Request(f"{GRAFANA}/api/ds/query", data=json.dumps(cuerpo).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        respuesta = json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        respuesta = json.load(e)
    resultado = respuesta.get("results", {}).get(target["refId"], {})
    if "error" in resultado:
        return None, resultado["error"]
    filas = sum(len(f["data"]["values"][0]) for f in resultado.get("frames", []) if f.get("data", {}).get("values"))
    return filas, None


def main():
    exigir_filas = "--vacios" in sys.argv
    errores = 0
    total = 0
    for archivo in sorted(TABLEROS.glob("*.json")):
        tablero = json.loads(archivo.read_text(encoding="utf-8"))
        for panel in tablero["panels"]:
            for target in panel.get("targets", []):
                total += 1
                filas, error = consultar(target)
                vacio = exigir_filas and target.get("format") == "time_series" and filas == 0
                if error or vacio:
                    errores += 1
                    print(f"  ✗ {tablero['uid']} · {panel['title']} [{target['refId']}]: {error or 'sin filas'}")
    print(f"  {total - errores}/{total} consultas de los tableros responden")
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
