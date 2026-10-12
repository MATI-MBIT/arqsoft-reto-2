#!/usr/bin/env python3
"""Gráficas de margen de results.md: cada caso, un punto; el umbral del ASR, una línea.

Lee los valores de la tabla de eventos con psql (docker compose) y escribe SVG
estáticos en docs/assets/resultados/graficas/. Uso: python3 analisis/graficas.py
"""
import math
import random
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "docs" / "assets" / "resultados" / "graficas"

# Paleta de referencia (skill dataviz), tema claro del wiki.
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


def franja(valores, umbral, ticks, titulo, subtitulo, etiqueta_umbral, unidad, archivo):
    """Franja de puntos en escala logarítmica: muestra cuánto falta para el umbral."""
    ancho, alto = 960, 300
    izq, der, arriba, abajo = 40, 40, 92, 62
    x0, x1 = math.log10(ticks[0][0]), math.log10(umbral * 1.6)

    def x(v):
        return izq + (math.log10(v) - x0) / (x1 - x0) * (ancho - izq - der)

    medio = arriba + (alto - arriba - abajo) / 2
    random.seed(7)
    puntos = []
    for v in sorted(valores):
        # Enjambre simple: el punto se aparta en vertical si choca con uno ya puesto.
        for intento in range(40):
            dy = (intento + 1) // 2 * 9 * (1 if intento % 2 else -1)
            if all((x(v) - px) ** 2 + (medio + dy - py) ** 2 >= 9.5 ** 2 for px, py in puntos):
                puntos.append((x(v), medio + dy))
                break
    maximo = max(valores)
    veces = umbral / maximo
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {ancho} {alto}" width="{ancho}" height="{alto}" '
         f'font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif">',
         f'<title>{titulo}</title>',
         f'<rect width="{ancho}" height="{alto}" fill="{SUPERFICIE}"/>',
         f'<text x="{izq}" y="34" font-size="18" font-weight="600" fill="{TINTA}">{titulo}</text>',
         f'<text x="{izq}" y="60" font-size="14" fill="{TINTA_2}">{subtitulo}</text>']
    # El margen: del caso más lento al umbral.
    s.append(f'<rect x="{x(maximo):.1f}" y="{arriba - 10}" width="{x(umbral) - x(maximo):.1f}" '
             f'height="{alto - arriba - abajo + 20}" fill="{MARGEN}"/>')
    s.append(f'<text x="{(x(maximo) + x(umbral)) / 2:.1f}" y="{arriba + 8}" font-size="13" fill="{TINTA_2}" '
             f'text-anchor="middle">margen: {math.floor(veces)} veces por debajo del umbral</text>')
    for v, etiqueta in ticks:
        s.append(f'<line x1="{x(v):.1f}" x2="{x(v):.1f}" y1="{arriba - 10}" y2="{alto - abajo + 10}" stroke="{REJILLA}"/>')
        s.append(f'<text x="{x(v):.1f}" y="{alto - abajo + 30}" font-size="12" fill="{TINTA_3}" '
                 f'text-anchor="middle">{etiqueta}</text>')
    s.append(f'<line x1="{izq}" x2="{ancho - der}" y1="{alto - abajo + 10}" y2="{alto - abajo + 10}" stroke="{TINTA_3}"/>')
    s.append(f'<text x="{ancho - der}" y="{alto - 8}" font-size="12" fill="{TINTA_3}" text-anchor="end">'
             f'{unidad}, escala logarítmica</text>')
    s.append(f'<line x1="{x(umbral):.1f}" x2="{x(umbral):.1f}" y1="{arriba - 14}" y2="{alto - abajo + 10}" '
             f'stroke="{TINTA_2}" stroke-width="2" stroke-dasharray="6 4"/>')
    s.append(f'<text x="{x(umbral) - 8:.1f}" y="{arriba + 32}" font-size="13" font-weight="600" fill="{TINTA}" '
             f'text-anchor="end">{etiqueta_umbral}</text>')
    for px, py in puntos:
        s.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="4.5" fill="{SERIE}" stroke="{SUPERFICIE}" stroke-width="1.5"/>')
    mx = x(maximo)
    s.append(f'<line x1="{mx:.1f}" x2="{mx:.1f}" y1="{alto - abajo - 6}" y2="{alto - abajo + 10}" stroke="{TINTA_2}"/>')
    s.append(f'<text x="{mx:.1f}" y="{alto - abajo - 10}" font-size="12" fill="{TINTA_2}" text-anchor="middle">'
             f'máximo {maximo:.0f} {unidad}</text>')
    s.append('</svg>')
    DESTINO.mkdir(parents=True, exist_ok=True)
    (DESTINO / archivo).write_text("\n".join(s) + "\n", encoding="utf-8")
    print(f"escrito {DESTINO / archivo}")


def asr1():
    demoras = consulta("""
        SELECT v.demora_ms FROM registro.e01_sesiones v, registro.corrida c
        WHERE c.id = 'e01-s1-20261012-160847' AND v.fase = 'S1' AND v.tipo = 'INTRUSO'
          AND v.abierta BETWEEN c.inicio AND c.fin ORDER BY 1""")
    mediana = sorted(demoras)[len(demoras) // 2]
    franja(demoras, 2000,
           [(1, "1 ms"), (10, "10 ms"), (100, "100 ms"), (1000, "1 s")],
           "ASR-1 · demora del aviso a seguridad, un punto por intruso de S1",
           f"{len(demoras)} de {len(demoras)} avisos dentro del umbral · mediana {mediana:.0f} ms · "
           f"máximo {max(demoras):.0f} ms",
           "umbral de ASR-1: 2 s", "ms", "asr1-margen.svg")


if __name__ == "__main__":
    asr1()
