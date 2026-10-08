-- Veredicto de E01 para una corrida. Uso: psql -v corrida=<id> -f e01.sql
-- Solo entran las sesiones abiertas entre el fin del calentamiento y el fin de
-- la corrida. El aviso puede llegar después del fin: se busca sin límite.
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

CREATE TEMP VIEW s AS
SELECT v.* FROM registro.e01_sesiones v, registro.corrida c
WHERE c.id = :'corrida' AND v.abierta BETWEEN c.inicio AND c.fin;

\echo
\echo '== Criterios de H1'
WITH intrusos AS (
    SELECT * FROM s WHERE tipo = 'INTRUSO' AND fase = 'S1'),
criterios AS (
    SELECT 1 AS orden, 'S1 · 50 intrusos con aviso en ≤ 2 s y con vendedor, dispositivo y hora' AS criterio,
           count(*) AS casos,
           count(*) FILTER (WHERE demora_ms <= 2000 AND completo) AS cumplen,
           count(*) FILTER (WHERE aviso IS NULL OR demora_ms > 2000 OR NOT completo) AS fallan,
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE aviso IS NULL OR demora_ms > 2000 OR NOT completo) = 0 THEN 'PASA'
                ELSE 'FALLA' END AS veredicto
    FROM intrusos
    UNION ALL
    SELECT 2, 'S2 · ≤ 1 aviso por cada 100 cambios legítimos',
           count(*), count(*) FILTER (WHERE aviso IS NULL), count(*) FILTER (WHERE aviso IS NOT NULL),
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE aviso IS NOT NULL) * 100 <= count(*) THEN 'PASA'
                ELSE 'FALLA' END
    FROM s WHERE tipo = 'CAMBIO'
    UNION ALL
    SELECT 3, 'S3 · 0 avisos en aperturas a menos de 1 s del registro',
           count(*), count(*) FILTER (WHERE aviso IS NULL), count(*) FILTER (WHERE aviso IS NOT NULL),
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE aviso IS NOT NULL) = 0 THEN 'PASA' ELSE 'FALLA' END
    FROM s WHERE tipo = 'PEGADO'
    UNION ALL
    SELECT 4, 'Todas · 0 avisos por sesiones desde el dispositivo registrado',
           count(*), count(*) FILTER (WHERE aviso IS NULL), count(*) FILTER (WHERE aviso IS NOT NULL),
           CASE WHEN count(*) = 0 THEN 'NO APLICA'
                WHEN count(*) FILTER (WHERE aviso IS NOT NULL) = 0 THEN 'PASA' ELSE 'FALLA' END
    FROM s WHERE tipo = 'LEGIT')
SELECT criterio, casos, cumplen, fallan, veredicto FROM criterios ORDER BY orden;

\echo
\echo '== Demora del aviso por fase (ms), solo sesiones de intruso'
SELECT fase,
       count(*)                                                              AS intrusos,
       count(aviso)                                                          AS con_aviso,
       count(*) FILTER (WHERE aviso IS NULL OR demora_ms > 2000)            AS escapes,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY demora_ms)::numeric, 1) AS mediana,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY demora_ms)::numeric, 1) AS p95,
       max(demora_ms)                                                        AS maximo
FROM s WHERE tipo = 'INTRUSO'
GROUP BY fase ORDER BY fase;

\echo
\echo '== S4 · aperturas por segundo logradas en cada nivel (número desconocido de H1)'
SELECT fase, count(*) AS aperturas,
       round(count(*) / greatest(extract(epoch FROM max(abierta) - min(abierta)), 1)::numeric, 2) AS por_segundo
FROM s WHERE fase LIKE 'S4N%'
GROUP BY fase ORDER BY fase;

\echo
\echo '== Avisos fuera de lo esperado (escapes y falsas alarmas)'
SELECT sesion_id, tipo, vendedor, dispositivo, abierta, demora_ms, completo
FROM s
WHERE (tipo = 'INTRUSO' AND (aviso IS NULL OR demora_ms > 2000 OR NOT completo))
   OR (tipo <> 'INTRUSO' AND aviso IS NOT NULL)
ORDER BY abierta LIMIT 50;
