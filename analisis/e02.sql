-- Veredicto de E02 para una corrida. Uso: psql -v corrida=<id> -f e02.sql
-- Entran las fallas con t0 entre el fin del calentamiento y el fin de la
-- corrida. La llegada a la cola puede ser posterior: se busca sin límite.
\set ON_ERROR_STOP on
\pset footer off
\pset null '—'

\echo
\echo '== Corrida'
SELECT id, experimento, fase, variables, inicio, fin, fin - inicio AS duracion, valida
FROM registro.corrida WHERE id = :'corrida';

\echo
\echo '== Validez: el hueco más largo de la carga de fondo (un pedido por segundo)'
SELECT c.valida, c.motivo,
       round(extract(epoch FROM max(x.hueco))::numeric, 1) AS hueco_maximo_s
FROM registro.corrida c
LEFT JOIN LATERAL (
    SELECT e.ts - lag(e.ts) OVER (ORDER BY e.ts) AS hueco FROM registro.evento e
    WHERE e.tipo = 'pedido.confirmado' AND e.ts BETWEEN c.arranque AND c.fin) x ON true
WHERE c.id = :'corrida'
GROUP BY c.valida, c.motivo;

CREATE TEMP VIEW w AS SELECT inicio, fin FROM registro.corrida WHERE id = :'corrida';
CREATE TEMP VIEW x AS SELECT c.* FROM registro.e02_cruce c, w WHERE c.t0 BETWEEN w.inicio AND w.fin;
CREATE TEMP VIEW decl AS SELECT d.* FROM registro.e02_declaraciones d, w WHERE d.ts BETWEEN w.inicio AND w.fin;
CREATE TEMP VIEW falsos AS SELECT f.* FROM registro.e02_mensajes_falsos f, w WHERE f.ts BETWEEN w.inicio AND w.fin;
CREATE TEMP VIEW atascos AS SELECT a.* FROM registro.e02_atascos a, w WHERE a.ts BETWEEN w.inicio AND w.fin;
CREATE TEMP VIEW reps AS SELECT r.* FROM registro.e02_repeticiones r, w WHERE r.ts BETWEEN w.inicio AND w.fin;
-- Efectos por pedido y etapa de los pedidos que entraron a la etapa en la ventana.
CREATE TEMP VIEW efectos AS
SELECT e.pedido_id, e.etapa, count(*) AS veces
FROM registro.evento e, w
WHERE e.tipo = 'etapa.efecto.aplicado' AND e.ts BETWEEN w.inicio AND w.fin + interval '60 seconds'
GROUP BY e.pedido_id, e.etapa;

\echo
\echo '== Criterios de H2'
WITH horas AS (SELECT greatest(extract(epoch FROM fin - inicio) / 3600.0, 1e-9) AS h FROM w),
criterios AS (
    SELECT 1 AS orden, 'D2 · todo pedido de una etapa caída llega a la cola en ≤ 30 s' AS criterio,
           count(*) AS casos,
           count(*) FILTER (WHERE demora_ms <= 30000) AS cumplen,
           count(*) FILTER (WHERE encolado IS NULL OR demora_ms > 30000) AS fallan,
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE encolado IS NULL OR demora_ms > 30000) = 0 THEN 'PASA'
                ELSE 'FALLA' END AS veredicto
    FROM x WHERE falla = 'D2'
    UNION ALL
    SELECT 2, 'D3 · todo pedido congelado en una etapa viva llega a la cola en ≤ 30 s',
           count(*), count(*) FILTER (WHERE demora_ms <= 30000),
           count(*) FILTER (WHERE encolado IS NULL OR demora_ms > 30000),
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE encolado IS NULL OR demora_ms > 30000) = 0 THEN 'PASA'
                ELSE 'FALLA' END
    FROM x WHERE falla = 'D3'
    UNION ALL
    SELECT 3, 'D1 · ≤ 1 falsa alarma por hora (etapas declaradas y pedidos informados como atascados)',
           (SELECT count(*) FROM decl) + (SELECT count(*) FROM atascos),
           (SELECT count(*) FROM decl WHERE justificada) + (SELECT count(*) FROM atascos WHERE justificado),
           (SELECT count(*) FROM decl WHERE NOT justificada) + (SELECT count(*) FROM atascos WHERE NOT justificado),
           CASE WHEN (SELECT count(*) FROM decl WHERE NOT justificada)
                     + (SELECT count(*) FROM atascos WHERE NOT justificado) <= (SELECT h FROM horas) THEN 'PASA'
                ELSE 'FALLA' END
    UNION ALL
    SELECT 4, 'Todas · cada pedido encolado entra a la cola una sola vez (0 perdidos, 0 duplicados)',
           count(*) FILTER (WHERE encolado IS NOT NULL),
           count(*) FILTER (WHERE encolado IS NOT NULL AND mensajes = 1),
           count(*) FILTER (WHERE encolado IS NOT NULL AND mensajes <> 1),
           CASE WHEN count(*) FILTER (WHERE encolado IS NOT NULL) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE encolado IS NOT NULL AND mensajes <> 1) = 0 THEN 'PASA'
                ELSE 'FALLA' END
    FROM x
    UNION ALL
    SELECT 5, 'D5 · la entrega repetida no repite el efecto de la etapa',
           count(*), count(*) FILTER (WHERE efectos = 1 AND detectada),
           count(*) FILTER (WHERE efectos <> 1 OR NOT detectada),
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE efectos <> 1 OR NOT detectada) = 0 THEN 'PASA'
                ELSE 'FALLA' END
    FROM reps
    UNION ALL
    SELECT 6, 'Todas · cada etapa aplica su efecto una sola vez por pedido',
           count(*), count(*) FILTER (WHERE veces = 1), count(*) FILTER (WHERE veces > 1),
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE veces > 1) = 0 THEN 'PASA'
                ELSE 'FALLA' END
    FROM efectos)
SELECT criterio, casos, cumplen, fallan, veredicto FROM criterios ORDER BY orden;

\echo
\echo '== Demora hasta la cola (ms), por tipo de falla y etapa'
SELECT falla, etapa,
       count(*)                                            AS detenidos,
       count(encolado)                                     AS encolados,
       count(*) FILTER (WHERE encolado IS NULL)            AS escapes,
       count(*) FILTER (WHERE mensajes > 1)                AS duplicados,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY demora_ms)::numeric, 1) AS mediana,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY demora_ms)::numeric, 1) AS p95,
       max(demora_ms)                                      AS maximo
FROM x GROUP BY falla, etapa ORDER BY falla, etapa;

\echo
\echo '== D2 · cada caída con sus pedidos detenidos'
SELECT c.falla_id, c.etapa, c.falla, c.reinicio - c.falla AS caida,
       count(x.pedido_id) AS detenidos, count(x.encolado) AS encolados, max(x.demora_ms) AS demora_max_ms,
       (SELECT min(d.ts) - c.falla FROM registro.e02_declaraciones d
        WHERE d.etapa = c.etapa AND d.ts >= c.falla AND d.ts <= coalesce(c.reinicio, 'infinity')) AS declarada_tras
FROM registro.e02_caidas c
JOIN w ON c.falla BETWEEN w.inicio AND w.fin
LEFT JOIN x ON x.falla = 'D2' AND x.falla_id = c.falla_id
GROUP BY c.falla_id, c.etapa, c.falla, c.reinicio ORDER BY c.falla;

\echo
\echo '== D3 · cada pedido congelado: cuándo lo informó el punto de salud y cuándo llegó a la cola'
SELECT x.etapa, x.pedido_id, x.t0,
       (SELECT min(a.ts) - x.t0 FROM registro.e02_atascos a
        WHERE a.pedido_id = x.pedido_id AND a.etapa = x.etapa) AS informado_tras,
       x.demora_ms
FROM x WHERE x.falla = 'D3' ORDER BY x.t0;

\echo
\echo '== D5 · entregas repetidas: detectadas y efectos por pedido'
SELECT etapa, count(*) AS repeticiones, count(*) FILTER (WHERE detectada) AS detectadas,
       count(*) FILTER (WHERE efectos = 1) AS un_efecto, count(*) FILTER (WHERE efectos > 1) AS efecto_doble,
       count(*) FILTER (WHERE efectos = 0) AS sin_efecto
FROM reps GROUP BY etapa ORDER BY etapa;

\echo
\echo '== Entregas que el bróker devolvió y la etapa retomó (tras una caída)'
SELECT e.etapa, count(*) AS retomadas
FROM registro.evento e, w
WHERE e.tipo = 'etapa.entrega.retomada' AND e.ts BETWEEN w.inicio AND w.fin + interval '60 seconds'
GROUP BY e.etapa ORDER BY e.etapa;

\echo
\echo '== Falsas alarmas: declaraciones sin caída, pedidos sanos informados como atascados y mensajes sin pedido detenido'
SELECT 'declaración' AS que, ts, etapa, NULL AS pedido_id, NULL::boolean AS llego_a_logistica
FROM decl WHERE NOT justificada
UNION ALL
SELECT 'atascado', ts, etapa, pedido_id, NULL FROM atascos WHERE NOT justificado
UNION ALL
SELECT 'mensaje', ts, etapa, pedido_id, llego_a_logistica FROM falsos
ORDER BY ts LIMIT 50;

\echo
\echo '== Escapes: pedidos detenidos que no llegaron a la cola o llegaron tarde'
SELECT falla, etapa, pedido_id, t0, encolado, demora_ms
FROM x WHERE encolado IS NULL OR demora_ms > 30000
ORDER BY t0 LIMIT 50;
