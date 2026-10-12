#!/usr/bin/env python3
"""Gráficas de margen de results.md: cada caso, un punto; el umbral del ASR, una línea.

Lee los valores de la tabla de eventos con psql (docker compose) y escribe SVG
estáticos en docs/assets/resultados/graficas/. Uso: python3 analisis/graficas.py
"""
import math
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "docs" / "assets" / "resultados" / "graficas"
E01 = "20261012-160847"
E02 = "20261012-160845"

# Paleta de referencia (skill dataviz), tema claro del wiki. Una sola serie por
# gráfica: las filas se nombran con texto, no con color.
SUPERFICIE = "#fcfcfb"
TINTA = "#0b0b0b"
TINTA_2 = "#52514e"
TINTA_3 = "#8a8985"
REJILLA = "#e6e5e1"
SERIE = "#2a78d6"
MARGEN = "#eaf2fc"


def consulta(sql):
    r = subprocess.run(
        ["docker", "compose", "-f", str(RAIZ / "deploy/docker-compose.yml"), "exec", "-T", "postgres",
         "psql", "-U", "reto2", "-d", "reto2", "-qtA", "-c", sql],
        check=True, capture_output=True, text=True)
    return [float(x) for x in r.stdout.split()]


def franja(filas, umbral, escala, ticks, titulo, subtitulo, etiqueta_umbral, margen, unidad, archivo):
    """Una franja de puntos por fila, sobre un eje común con el umbral del ASR.

    filas: [(nombre, valores)]; escala: "log" o "lin"; margen: el texto de la
    franja que va del caso más lento al umbral."""
    ancho = 960
    izq, der, arriba, abajo = 170, 40, 96, 62
    alto_fila = 150
    alto = arriba + alto_fila * len(filas) + abajo
    lo, hi = ticks[0][0], max(umbral * (1.6 if escala == "log" else 1.07), ticks[-1][0])
    f = (lambda v: math.log10(max(v, lo))) if escala == "log" else (lambda v: v)

    def x(v):
        return izq + (f(v) - f(lo)) / (f(hi) - f(lo)) * (ancho - izq - der)

    maximo = max(max(v) for _, v in filas)
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {ancho} {alto}" width="{ancho}" height="{alto}" '
         f'font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif">',
         f'<title>{titulo}</title>',
         f'<rect width="{ancho}" height="{alto}" fill="{SUPERFICIE}"/>',
         f'<text x="40" y="34" font-size="18" font-weight="600" fill="{TINTA}">{titulo}</text>',
         f'<text x="40" y="60" font-size="14" fill="{TINTA_2}">{subtitulo}</text>']
    base = alto - abajo + 10
    s.append(f'<rect x="{x(maximo):.1f}" y="{arriba - 10}" width="{x(umbral) - x(maximo):.1f}" '
             f'height="{base - arriba + 10}" fill="{MARGEN}"/>')
    s.append(f'<text x="{(x(maximo) + x(umbral)) / 2:.1f}" y="{arriba + 8}" font-size="13" fill="{TINTA_2}" '
             f'text-anchor="middle">{margen}</text>')
    for v, etiqueta in ticks:
        s.append(f'<line x1="{x(v):.1f}" x2="{x(v):.1f}" y1="{arriba - 10}" y2="{base}" stroke="{REJILLA}"/>')
        s.append(f'<text x="{x(v):.1f}" y="{base + 20}" font-size="12" fill="{TINTA_3}" '
                 f'text-anchor="middle">{etiqueta}</text>')
    s.append(f'<line x1="{izq}" x2="{ancho - der}" y1="{base}" y2="{base}" stroke="{TINTA_3}"/>')
    s.append(f'<text x="{ancho - der}" y="{alto - 8}" font-size="12" fill="{TINTA_3}" text-anchor="end">'
             f'{unidad}{", escala logarítmica" if escala == "log" else ""}</text>')
    s.append(f'<line x1="{x(umbral):.1f}" x2="{x(umbral):.1f}" y1="{arriba - 14}" y2="{base}" '
             f'stroke="{TINTA_2}" stroke-width="2" stroke-dasharray="6 4"/>')
    s.append(f'<text x="{x(umbral) - 8:.1f}" y="{arriba + 32}" font-size="13" font-weight="600" fill="{TINTA}" '
             f'text-anchor="end">{etiqueta_umbral}</text>')
    for i, (nombre, valores) in enumerate(filas):
        medio = arriba + alto_fila * i + alto_fila / 2 + 10
        s.append(f'<text x="{izq - 14}" y="{medio + 5:.1f}" font-size="13" fill="{TINTA}" text-anchor="end">'
                 f'{nombre}</text>')
        puntos = []
        for v in sorted(valores):
            # Enjambre: el punto se aparta en vertical si choca con uno ya puesto;
            # si no cabe en la fila, se queda en la línea central.
            sitio = (x(v), medio)
            for intento in range(30):
                dy = (intento + 1) // 2 * 4.6 * (1 if intento % 2 else -1)
                if all((x(v) - px) ** 2 + (medio + dy - py) ** 2 >= 6.4 ** 2 for px, py in puntos):
                    sitio = (x(v), medio + dy)
                    break
            puntos.append(sitio)
        for px, py in puntos:
            s.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="3" fill="{SERIE}" fill-opacity="0.85" '
                     f'stroke="{SUPERFICIE}" stroke-width="1.2"/>')
    s.append('</svg>')
    DESTINO.mkdir(parents=True, exist_ok=True)
    (DESTINO / archivo).write_text("\n".join(s) + "\n", encoding="utf-8")
    print(f"escrito {DESTINO / archivo}")


def coma(v, dec=1):
    """Redondeo a la mitad hacia arriba, como en las tablas de results.md."""
    q = math.floor(v * 10 ** dec + 0.5 + 1e-9) / 10 ** dec
    return f"{q:.{dec}f}".replace(".", ",")


def asr1():
    demoras = consulta(f"""
        SELECT v.demora_ms FROM registro.e01_sesiones v, registro.corrida c
        WHERE c.id = 'e01-s1-{E01}' AND v.fase = 'S1' AND v.tipo = 'INTRUSO'
          AND v.abierta BETWEEN c.inicio AND c.fin ORDER BY 1""")
    mediana = sorted(demoras)[len(demoras) // 2]
    franja([("S1 · intrusos", demoras)], 2000, "log",
           [(1, "1 ms"), (10, "10 ms"), (100, "100 ms"), (1000, "1 s")],
           "ASR-1 · demora del aviso a seguridad, un punto por intruso",
           f"{len(demoras)} de {len(demoras)} avisos dentro del umbral · mediana {mediana:.0f} ms · "
           f"máximo {max(demoras):.0f} ms",
           "umbral de ASR-1: 2 s", f"margen: {math.floor(2000 / max(demoras))} veces menor que el umbral",
           "ms", "asr1-margen.svg")


def asr3():
    def demoras(fase):
        return [v / 1000 for v in consulta(f"""
            SELECT x.demora_ms FROM registro.e02_cruce x, registro.corrida c
            WHERE c.id = 'e02-{fase.lower()}-{E02}' AND x.falla = '{fase}'
              AND x.t0 BETWEEN c.inicio AND c.fin ORDER BY 1""")]
    d2, d3 = demoras("D2"), demoras("D3")
    maximo = max(d2 + d3)
    franja([("D2 · etapa caída", d2), ("D3 · pedido congelado", d3)], 30, "lin",
           [(0, "0 s"), (5, "5 s"), (10, "10 s"), (15, "15 s"), (20, "20 s"), (25, "25 s"), (30, "30 s")],
           "ASR-3 · del pedido detenido a la Dead-Letter-Queue, un punto por pedido",
           f"{len(d2)} de {len(d2)} en D2 y {len(d3)} de {len(d3)} en D3 dentro del umbral · "
           f"máximo {coma(maximo)} s",
           "umbral de ASR-3: 30 s", f"margen: {coma(30 - float(coma(maximo).replace(',', '.')))} s por debajo del umbral", "segundos", "asr3-margen.svg")


def asr4():
    def senal(fase):
        if fase == "D3":
            sql = f"""
              SELECT extract(epoch FROM e.ts - a.ts) * 1000
              FROM registro.corrida w
              JOIN registro.evento a ON a.tipo = 'pedido.atascado.detectado' AND a.ts BETWEEN w.inicio AND w.fin
              JOIN registro.evento e ON e.tipo = 'pedido.encolado' AND e.pedido_id = a.pedido_id AND e.etapa = a.etapa
              WHERE w.id = 'e02-d3-{E02}' ORDER BY 1"""
        else:
            sql = f"""
              WITH decl AS (
                SELECT d.etapa, d.ts FROM registro.corrida w JOIN registro.evento d
                  ON d.tipo = 'etapa.declarada.detenida' AND d.ts BETWEEN w.inicio AND w.fin
                WHERE w.id = 'e02-d2-{E02}')
              SELECT extract(epoch FROM e.ts - k.ts) * 1000 FROM decl k
              JOIN registro.evento e ON e.tipo = 'pedido.encolado' AND e.etapa = k.etapa
                   AND e.ts BETWEEN k.ts AND k.ts + interval '30 seconds'
              WHERE NOT EXISTS (SELECT 1 FROM decl k2 WHERE k2.etapa = k.etapa AND k2.ts > k.ts AND k2.ts <= e.ts)
                AND (e.datos->>'transcurridoMs')::bigint > extract(epoch FROM e.ts - k.ts) * 1000
              ORDER BY 1"""
        return consulta(sql)
    d2, d3 = senal("D2"), senal("D3")
    maximo = max(d2 + d3)
    franja([("D2 · etapa caída", d2), ("D3 · pedido congelado", d3)], 5000, "log",
           [(1, "1 ms"), (10, "10 ms"), (100, "100 ms"), (1000, "1 s")],
           "ASR-4 · de la señal de detención a la Dead-Letter-Queue, un punto por pedido",
           f"{len(d2) + len(d3)} de {len(d2) + len(d3)} pedidos dentro del umbral · máximo {maximo:.0f} ms · "
           f"el envío a la cola, no la reanudación",
           "umbral de ASR-4: 5 s", f"margen: {math.floor(5000 / maximo)} veces menor que el umbral",
           "ms", "asr4-margen.svg")


if __name__ == "__main__":
    asr1()
    asr3()
    asr4()
