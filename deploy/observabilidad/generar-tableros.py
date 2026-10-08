#!/usr/bin/env python3
"""Genera los tableros de Grafana de E01 y E02 (make tableros).

Cada tablero tiene dos fuentes:
  - el registro de eventos (PostgreSQL): cada falla cruzada con su salida por
    identificador, con las mismas vistas que usa el veredicto. Es la evidencia.
  - Prometheus: lo que miden los micros y k6, para ver la corrida en vivo y
    cortarla si se daña.

Las cifras de arriba de cada tablero se calculan sobre la ventana de tiempo
del tablero. El veredicto de una corrida se calcula sobre su propia ventana,
con analisis/*.sql.
"""
import json
from pathlib import Path

DESTINO = Path(__file__).parent / "grafana" / "dashboards"
PROM = {"type": "prometheus", "uid": "prometheus"}
PG = {"type": "grafana-postgresql-datasource", "uid": "registro"}
ROJO, VERDE, NARANJA, AZUL = "red", "green", "orange", "blue"


class Tablero:
    def __init__(self):
        self.paneles = []
        self.y = 0
        self.x = 0
        self.alto_fila = 0

    def _ubicar(self, w, h):
        if self.x + w > 24:
            self.y += self.alto_fila
            self.x = 0
            self.alto_fila = 0
        pos = {"x": self.x, "y": self.y, "w": w, "h": h}
        self.x += w
        self.alto_fila = max(self.alto_fila, h)
        return pos

    def fila(self, titulo):
        if self.x:
            self.y += self.alto_fila
        self.x, self.alto_fila = 0, 0
        self.paneles.append({"type": "row", "title": titulo, "collapsed": False,
                             "gridPos": {"x": 0, "y": self.y, "w": 24, "h": 1}, "panels": []})
        self.y += 1

    def panel(self, tipo, titulo, targets, w, h, descripcion="", **extra):
        p = {"type": tipo, "title": titulo, "description": descripcion,
             "gridPos": self._ubicar(w, h), "targets": targets,
             "datasource": targets[0]["datasource"]}
        p.update(extra)
        self.paneles.append(p)

    def json(self, uid, titulo, descripcion, anotaciones):
        for i, p in enumerate(self.paneles, start=1):
            p["id"] = i
        return {
            "uid": uid, "title": titulo, "description": descripcion, "tags": ["reto2", uid],
            "timezone": "browser", "refresh": "5s", "schemaVersion": 39, "version": 1,
            "time": {"from": "now-30m", "to": "now"},
            "annotations": {"list": anotaciones}, "panels": self.paneles,
            "templating": {"list": []},
        }


def sql(consulta, formato="table", ref="A"):
    return {"refId": ref, "datasource": PG, "rawSql": consulta.strip(), "format": formato,
            "rawQuery": True, "editorMode": "code"}


def prom(expr, leyenda="", ref="A"):
    return {"refId": ref, "datasource": PROM, "expr": expr, "legendFormat": leyenda, "range": True}


def umbrales(*pasos):
    """pasos: (valor, color), el primero con valor None."""
    return {"mode": "absolute", "steps": [{"value": v, "color": c} for v, c in pasos]}


def stat(t, titulo, consulta, desc, pasos=((None, VERDE),), unidad="none", w=4):
    t.panel("stat", titulo, [sql(consulta)], w, 4, desc,
            fieldConfig={"defaults": {"unit": unidad, "thresholds": umbrales(*pasos), "color": {"mode": "thresholds"}},
                         "overrides": []},
            options={"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                     "colorMode": "background", "graphMode": "none", "textMode": "value"})


def serie(t, titulo, targets, desc, unidad="none", w=12, h=8, puntos=False, linea=None, minimo=None):
    defaults = {"unit": unidad, "custom": {"drawStyle": "points" if puntos else "line", "pointSize": 6,
                                           "lineWidth": 2, "showPoints": "always" if puntos else "never",
                                           "spanNulls": False}}
    if minimo is not None:
        defaults["min"] = minimo
    if linea is not None:
        defaults["thresholds"] = umbrales((None, VERDE), (linea, ROJO))
        defaults["custom"]["thresholdsStyle"] = {"mode": "dashed"}
    t.panel("timeseries", titulo, targets, w, h, desc,
            fieldConfig={"defaults": defaults, "overrides": []},
            options={"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "multi"}})


def tabla(t, titulo, consulta, desc, w=24, h=8):
    t.panel("table", titulo, [sql(consulta)], w, h, desc,
            fieldConfig={"defaults": {}, "overrides": []}, options={"showHeader": True})


def anotacion_pg(nombre, consulta, color):
    return {"name": nombre, "datasource": PG, "enable": True, "iconColor": color,
            "target": {"refId": "A", "rawSql": consulta.strip(), "format": "table", "rawQuery": True,
                       "editorMode": "code"}}


CORRIDAS = """
SELECT id, experimento, fase, inicio, fin, fin - inicio AS duracion, variables
FROM registro.corrida WHERE experimento = '{exp}' ORDER BY arranque DESC LIMIT 20"""

ANOT_CORRIDA = """
SELECT inicio AS time, coalesce(fin, now()) AS timeend, id AS text, 'corrida' AS tags
FROM registro.corrida WHERE experimento = '{exp}' AND inicio IS NOT NULL AND $__timeFilter(inicio)"""

CPU = prom("max by (application) (process_cpu_usage)", "{{application}}")
CPU_SISTEMA = prom("max(system_cpu_usage)", "máquina", ref="B")


def e01():
    t = Tablero()
    t.fila("Veredicto en vivo · registro de eventos, ventana del tablero")
    stat(t, "Sesiones de intruso", """
SELECT count(*) FROM registro.e01_sesiones WHERE tipo = 'INTRUSO' AND $__timeFilter(abierta)""",
         "Aperturas con las credenciales correctas y un dispositivo que no es el registrado (S1 y S4).",
         pasos=((None, AZUL),))
    stat(t, "Avisos a tiempo (≤ 2 s)", """
SELECT count(*) FROM registro.e01_sesiones
WHERE tipo = 'INTRUSO' AND demora_ms <= 2000 AND completo AND $__timeFilter(abierta)""",
         "Avisos cruzados con su sesión, en ≤ 2 s y con vendedor, dispositivo y hora.")
    stat(t, "Escapes", """
SELECT count(*) FROM registro.e01_sesiones
WHERE tipo = 'INTRUSO' AND abierta < now() - interval '3 seconds'
  AND (aviso IS NULL OR demora_ms > 2000 OR NOT completo) AND $__timeFilter(abierta)""",
         "Intrusos sin aviso, con aviso tarde o con aviso incompleto. Uno solo refuta H1.",
         pasos=((None, VERDE), (1, ROJO)))
    stat(t, "Falsas alarmas", """
SELECT count(*) FROM registro.e01_sesiones
WHERE tipo <> 'INTRUSO' AND aviso IS NOT NULL AND $__timeFilter(abierta)""",
         "Avisos por sesiones desde el dispositivo registrado: fondo, cambios legítimos (S2) y aperturas "
         "pegadas al registro (S3). S2 admite 1 por cada 100 cambios; las demás, cero.",
         pasos=((None, VERDE), (1, NARANJA)))
    stat(t, "Demora p95 del aviso", """
SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY demora_ms) FROM registro.e01_sesiones
WHERE tipo = 'INTRUSO' AND $__timeFilter(abierta)""",
         "Desde que el Gestor de sesión registra la apertura hasta que el receptor del SMS recibe el aviso: pasa por el bróker dos veces.",
         pasos=((None, VERDE), (2000, ROJO)), unidad="ms")
    stat(t, "Demora máxima del aviso", """
SELECT max(demora_ms) FROM registro.e01_sesiones WHERE tipo = 'INTRUSO' AND $__timeFilter(abierta)""",
         "El peor caso de la ventana. ASR-1 pide ≤ 2 s en todos.",
         pasos=((None, VERDE), (2000, ROJO)), unidad="ms")

    t.fila("Cada aviso, cruzado con su sesión")
    serie(t, "Demora de cada aviso, por fase (ms)", [sql("""
SELECT abierta AS time, fase AS metric, demora_ms FROM registro.e01_sesiones
WHERE tipo = 'INTRUSO' AND aviso IS NOT NULL AND $__timeFilter(abierta) ORDER BY 1""", "time_series")],
          "Un punto por sesión de intruso. La línea punteada es el umbral de ASR-1 (2 s).",
          unidad="ms", puntos=True, linea=2000, minimo=0)
    serie(t, "Aperturas de sesión por segundo, por tipo", [sql("""
SELECT date_bin('5 seconds', abierta, timestamptz '2000-01-01') AS time, tipo AS metric, count(*) / 5.0 AS valor
FROM registro.e01_sesiones WHERE $__timeFilter(abierta) GROUP BY 1, 2 ORDER BY 1""", "time_series")],
          "LEGIT es el fondo a la tasa base (S-10); CAMBIO y PEGADO son S2 y S3; INTRUSO, S1 y S4.",
          unidad="reqps")

    t.fila("Los micros · Prometheus")
    serie(t, "Aperturas, sospechas y avisos por segundo", [
        prom("sum(rate(sesiones_aperturas_total[15s]))", "aperturas"),
        prom("sum(rate(verificador_huella_no_coincide_total[15s]))", "huella no coincide (Verificador)", "B"),
        prom("sum(rate(receptor_avisos_recibidos_total[15s]))", "avisos recibidos", "C")],
          "Lo que cuentan el Gestor de sesión, el Verificador de dispositivo y el receptor. Sospechas y avisos deben ir juntos.", unidad="reqps", w=8)
    serie(t, "Comparación de la huella: p95 y p99 (ms)", [
        prom("histogram_quantile(0.95, sum by (le) (rate(verificador_huella_comparacion_seconds_bucket[30s]))) * 1000", "p95"),
        prom("histogram_quantile(0.99, sum by (le) (rate(verificador_huella_comparacion_seconds_bucket[30s]))) * 1000", "p99", "B")],
          "La lectura del dispositivo registrado en la base, en el Verificador de dispositivo.",
          unidad="ms", w=8)
    serie(t, "Mensajes esperando en las colas de E01", [
        prom('max by (queue) (rabbitmq_queue_messages{queue=~"verificador.sesiones|notificador.alertas"})', "{{queue}}")],
          "sesion.abierta esperando al Verificador y alerta.seguridad esperando al Notificador. Si crecen, el "
          "aviso se atrasa en el bróker y no en la comparación.", w=8, minimo=0)
    serie(t, "k6: solicitudes por segundo, por tipo", [
        prom("sum by (tipo) (rate(k6_http_reqs_total[15s]))", "{{tipo}}")],
          "La carga que genera k6. Las consultas y los pedidos son el fondo del Ambiente A.", unidad="reqps")
    serie(t, "CPU", [CPU, CPU_SISTEMA],
          "Uso de CPU de cada JVM y de la máquina virtual de Docker. Si la máquina se satura, la demora sube "
          "por el montaje y no por el diseño.", unidad="percentunit")

    t.fila("Detalle")
    tabla(t, "Sesiones fuera de lo esperado: escapes y falsas alarmas", """
SELECT abierta, sesion_id, tipo, vendedor, dispositivo, demora_ms, completo FROM registro.e01_sesiones
WHERE $__timeFilter(abierta)
  AND ((tipo = 'INTRUSO' AND abierta < now() - interval '3 seconds'
        AND (aviso IS NULL OR demora_ms > 2000 OR NOT completo))
       OR (tipo <> 'INTRUSO' AND aviso IS NOT NULL))
ORDER BY abierta DESC LIMIT 100""", "Vacía es lo esperado.", w=12)
    tabla(t, "Últimos avisos", """
SELECT abierta, sesion_id, vendedor, dispositivo, demora_ms, completo FROM registro.e01_sesiones
WHERE aviso IS NOT NULL AND $__timeFilter(abierta) ORDER BY abierta DESC LIMIT 50""",
          "Cada aviso con lo que recibe seguridad: el vendedor, el dispositivo y la hora.", w=12)
    tabla(t, "Corridas de E01", CORRIDAS.format(exp="E01"),
          "La ventana de medición de cada corrida empieza al terminar el calentamiento.", h=6)

    return t.json("e01", "E01 · Detección del dispositivo no registrado (H1, ASR-1)",
                  "Si el Verificador de dispositivo compara la huella apenas el Gestor de sesión publica la apertura, "
                  "seguridad recibe el aviso en ≤ 2 s.",
                  [anotacion_pg("Corridas", ANOT_CORRIDA.format(exp="E01"), AZUL)])


def e02():
    t = Tablero()
    t.fila("Veredicto en vivo · registro de eventos, ventana del tablero")
    stat(t, "Fallas inyectadas", """
SELECT count(*) FROM registro.evento WHERE tipo = 'falla.inyectada' AND $__timeFilter(ts)""",
         "Caídas de etapa (D2) y congelamientos (D3) que ejecutó el inyector.", pasos=((None, AZUL),), w=3)
    stat(t, "Pedidos detenidos", """
SELECT count(*) FROM registro.e02_detenidos WHERE $__timeFilter(t0)""",
         "Pedidos cuya etapa no cerró en los 30 s de ASR-3. D2: los que la etapa tenía en curso o recibió caída. D3: el pedido congelado.",
         pasos=((None, AZUL),), w=3)
    stat(t, "En la cola ≤ 30 s", """
SELECT count(*) FROM registro.e02_cruce WHERE demora_ms <= 30000 AND $__timeFilter(t0)""",
         "Detenidos cuyo mensaje confirmó el bróker en la Dead-Letter-Queue en ≤ 30 s desde la falla.", w=3)
    stat(t, "Escapes", """
SELECT count(*) FROM registro.e02_cruce
WHERE t0 < now() - interval '30 seconds' AND (encolado IS NULL OR demora_ms > 30000) AND $__timeFilter(t0)""",
         "Detenidos que no llegaron a la cola o llegaron tarde. D3 los produce si el sondeo no ve el pedido "
         "congelado, que es lo que ADR-004 predijo.", pasos=((None, VERDE), (1, ROJO)), w=3)
    stat(t, "Duplicados", """
SELECT count(*) FROM registro.e02_cruce WHERE mensajes > 1 AND $__timeFilter(t0)""",
         "Pedidos que entraron más de una vez a la cola. Uno solo haría repetir una etapa en ASR-4.",
         pasos=((None, VERDE), (1, ROJO)), w=3)
    stat(t, "Falsas alarmas (episodios)", """
SELECT count(*) FROM registro.e02_declaraciones WHERE NOT justificada AND $__timeFilter(ts)""",
         "Declaraciones de etapa detenida sin caída inyectada en esa etapa (D-6). ASR-3 admite ≤ 1 por hora.",
         pasos=((None, VERDE), (1, NARANJA), (2, ROJO)), w=3)
    stat(t, "Mensajes sin pedido detenido", """
SELECT count(*) FROM registro.e02_mensajes_falsos WHERE $__timeFilter(ts)""",
         "Mensajes en la Dead-Letter-Queue por pedidos cuya etapa sí cerró en 30 s.",
         pasos=((None, VERDE), (1, NARANJA)), w=3)
    stat(t, "Demora p95 hasta la cola", """
SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY demora_ms) FROM registro.e02_cruce
WHERE encolado IS NOT NULL AND $__timeFilter(t0)""",
         "Desde la falla, o desde el envío si el pedido llegó con la etapa ya caída (D-5), hasta la confirmación "
         "del bróker en la Dead-Letter-Queue.", pasos=((None, VERDE), (30000, ROJO)), unidad="ms", w=3)

    t.fila("El Monitor de la cadena · Prometheus")
    t.panel("state-timeline", "Lo que declara el Monitor de cada etapa",
            [prom("max by (etapa) (monitor_etapa_detenida)", "{{etapa}}")], 12, 6,
            "Verde: viva. Rojo: declarada detenida tras N sondeos sin respuesta. Las anotaciones rojas marcan "
            "cada falla inyectada; las verdes, cada etapa que volvió a responder.",
            fieldConfig={"defaults": {"mappings": [{"type": "value", "options": {
                "0": {"text": "viva", "color": VERDE}, "1": {"text": "detenida", "color": ROJO}}}],
                "thresholds": umbrales((None, VERDE), (1, ROJO)), "color": {"mode": "thresholds"}},
                "overrides": []},
            options={"showValue": "never", "mergeValues": True, "rowHeight": 0.8})
    serie(t, "Sondeos sin respuesta seguidos, contra N", [
        prom("max by (etapa) (monitor_sondeos_fallidos_seguidos)", "{{etapa}}"),
        prom("max(monitor_config_n)", "N", "B")],
          "Cuando una etapa alcanza la línea de N, el Monitor la declara detenida.", w=12, h=6, minimo=0)
    serie(t, "Pedidos en curso por etapa (ventas)", [
        prom("max by (etapa) (ventas_pedidos_en_curso)", "{{etapa}}")],
          "Los pedidos que ventas envió a cada etapa y no han vuelto. En una caída crecen sin parar; en D3, el "
          "congelado queda para siempre.", w=8, minimo=0)
    serie(t, "Mensajes en las colas del bróker de la cadena", [
        prom('max by (queue) (rabbitmq_queue_messages{queue=~"dead-letter-queue|etapa.*"})', "{{queue}}")],
          "La Dead-Letter-Queue no tiene consumidor: crece con cada pedido detenido. La cola de una etapa caída "
          "acumula su trabajo, que se retoma cuando la etapa vuelve.", w=8, minimo=0)
    serie(t, "A la Dead-Letter-Queue por segundo: ventas y auditor", [
        prom("sum by (etapa) (rate(ventas_pedidos_encolados_total[15s]))", "ventas · {{etapa}}"),
        prom("sum by (etapa) (rate(auditor_mensajes_total[15s]))", "auditor · {{etapa}}", "B")],
          "Lo que ventas envió con confirmación del bróker y lo que el auditor leyó de la copia. Deben coincidir.", unidad="reqps", w=8)

    t.fila("Cada pedido detenido, cruzado con su mensaje")
    serie(t, "Demora hasta la cola de cada pedido detenido (ms)", [sql("""
SELECT t0 AS time, falla || ' · ' || etapa AS metric, demora_ms FROM registro.e02_cruce
WHERE encolado IS NOT NULL AND $__timeFilter(t0) ORDER BY 1""", "time_series")],
          "Un punto por pedido. La línea punteada es el umbral de ASR-3 (30 s). En una caída, los pedidos "
          "que llegan después forman una escalera que baja: esperan solo hasta el ciclo siguiente.",
          unidad="ms", puntos=True, linea=30000, minimo=0, w=16)
    serie(t, "Duración de cada etapa: p50 y p99,9 (s)", [
        prom("histogram_quantile(0.5, sum by (le, etapa) (rate(etapa_duracion_seconds_bucket[2m])))", "p50 · {{etapa}}"),
        prom("histogram_quantile(0.999, sum by (le, etapa) (rate(etapa_duracion_seconds_bucket[2m])))", "p99,9 · {{etapa}}", "B")],
          "La variación normal que el Monitor tiene que tolerar (S-11). D1 la mide de paso: es el dato que "
          "ADR-004 pide para calibrar su plazo (TO-004a).", unidad="s", w=8)
    serie(t, "k6: solicitudes por segundo, por tipo", [
        prom("sum by (tipo) (rate(k6_http_reqs_total[15s]))", "{{tipo}}")],
          "El Ambiente A: 1 pedido y 10 consultas por segundo (S-4).", unidad="reqps")
    serie(t, "CPU", [CPU, CPU_SISTEMA],
          "Si la máquina se satura, un sondeo lento parece una etapa caída: revisar aquí antes de culpar al "
          "diseño por una falsa alarma.", unidad="percentunit")

    t.fila("Detalle")
    tabla(t, "Cada caída (D2): pedidos detenidos y cuándo la declaró el Monitor", """
SELECT c.falla, c.etapa, c.reinicio - c.falla AS caida,
       (SELECT min(d.ts) - c.falla FROM registro.e02_declaraciones d
        WHERE d.etapa = c.etapa AND d.ts >= c.falla AND d.ts <= coalesce(c.reinicio, 'infinity')) AS declarada_tras,
       count(x.pedido_id) AS detenidos, count(x.encolado) AS encolados, max(x.demora_ms) AS demora_max_ms
FROM registro.e02_caidas c
LEFT JOIN registro.e02_cruce x ON x.falla = 'D2' AND x.falla_id = c.falla_id
WHERE $__timeFilter(c.falla)
GROUP BY c.falla_id, c.falla, c.etapa, c.reinicio ORDER BY c.falla DESC LIMIT 50""",
          "declarada_tras debería rondar N × T.", w=12)
    tabla(t, "Escapes, duplicados y falsas alarmas", """
SELECT t0 AS cuando, 'escape' AS que, falla || ' · ' || etapa AS detalle, pedido_id, demora_ms
FROM registro.e02_cruce
WHERE $__timeFilter(t0) AND t0 < now() - interval '30 seconds' AND (encolado IS NULL OR demora_ms > 30000)
UNION ALL
SELECT t0, 'duplicado', falla || ' · ' || etapa, pedido_id, demora_ms FROM registro.e02_cruce
WHERE $__timeFilter(t0) AND mensajes > 1
UNION ALL
SELECT ts, 'falsa alarma', etapa, NULL, NULL FROM registro.e02_declaraciones
WHERE $__timeFilter(ts) AND NOT justificada
UNION ALL
SELECT ts, CASE WHEN llego_a_logistica THEN 'mensaje · llegó a logística' ELSE 'mensaje sin detenido' END,
       etapa, pedido_id, NULL FROM registro.e02_mensajes_falsos WHERE $__timeFilter(ts)
ORDER BY 1 DESC LIMIT 100""", "Vacía es lo esperado, salvo los escapes de D3 si el sondeo no ve el pedido congelado.",
          w=12)
    tabla(t, "Corridas de E02", CORRIDAS.format(exp="E02"),
          "La ventana de medición de cada corrida empieza al terminar el calentamiento.", h=6)

    anot = [
        anotacion_pg("Fallas inyectadas", """
SELECT ts AS time, etapa || ' · ' || (datos ->> 'tipo') AS text, 'falla' AS tags
FROM registro.evento WHERE tipo = 'falla.inyectada' AND $__timeFilter(ts)""", ROJO),
        anotacion_pg("Etapa reiniciada", """
SELECT ts AS time, etapa || ' responde de nuevo' AS text, 'reinicio' AS tags
FROM registro.evento WHERE tipo = 'etapa.reiniciada' AND $__timeFilter(ts)""", VERDE),
        anotacion_pg("Corridas", ANOT_CORRIDA.format(exp="E02"), AZUL),
    ]
    return t.json("e02", "E02 · Detección del pedido detenido y envío a la Dead-Letter-Queue (H2, ASR-3)",
                  "Si el Monitor sondea cada etapa y avisa a ventas cuando una no responde N sondeos seguidos, y ventas "
                  "envía sus pedidos pendientes a la Dead-Letter-Queue, todo pedido detenido llega a ella en ≤ 30 s.",
                  anot)


if __name__ == "__main__":
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nombre, tablero in (("e01.json", e01()), ("e02.json", e02())):
        (DESTINO / nombre).write_text(json.dumps(tablero, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"escrito {DESTINO / nombre}")
