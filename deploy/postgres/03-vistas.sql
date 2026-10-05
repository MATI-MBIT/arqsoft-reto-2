-- Vistas del cruce uno a uno entre fallas y salidas. Las leen el veredicto
-- (analisis/*.sql) y el tablero de Grafana, para que los dos cuenten igual.
-- Se pueden recargar sin perder datos con `make vistas`.

-- E01 ---------------------------------------------------------------------
-- El identificador de cada sesión lo genera k6 con la fase y el tipo:
-- <FASE>-<TIPO>-<corrida>-<n>, p. ej. S1-INTRUSO-e01-s1-20261004-120000-17.
CREATE OR REPLACE VIEW registro.e01_sesiones AS
SELECT s.sesion_id,
       split_part(s.sesion_id, '-', 1)                    AS fase,
       split_part(s.sesion_id, '-', 2)                    AS tipo,
       s.ts                                               AS abierta,
       s.datos ->> 'vendedorId'                           AS vendedor,
       s.datos ->> 'dispositivoId'                        AS dispositivo,
       a.ts                                               AS aviso,
       (a.datos ->> 'completo')::boolean                  AS completo,
       round(extract(epoch FROM a.ts - s.ts) * 1000, 1)   AS demora_ms
FROM registro.evento s
LEFT JOIN LATERAL (
    SELECT ts, datos FROM registro.evento a
    WHERE a.tipo = 'aviso.recibido' AND a.sesion_id = s.sesion_id
    ORDER BY ts LIMIT 1) a ON true
WHERE s.tipo = 'sesion.abierta';

-- E02 ---------------------------------------------------------------------
-- Cada caída inyectada (D2) con su ventana. Empieza en la falla y termina
-- cuando la etapa vuelve a recibir trabajo, que es lo último entre dos hechos:
-- el reinicio (el inyector ve /salud) y la recuperación que declara el Monitor.
-- El reinicio solo no basta: justo después, /salud responde pero la etapa aún
-- rechaza trabajos, y los pedidos que ventas le envía en ese lapso se detienen.
CREATE OR REPLACE VIEW registro.e02_caidas AS
SELECT f.id AS falla_id, f.etapa, f.ts AS falla,
       (SELECT min(r.ts) FROM registro.evento r
        WHERE r.tipo = 'etapa.reiniciada' AND r.etapa = f.etapa AND r.ts > f.ts) AS reinicio,
       greatest(
         (SELECT min(r.ts) FROM registro.evento r
          WHERE r.tipo = 'etapa.reiniciada' AND r.etapa = f.etapa AND r.ts > f.ts),
         (SELECT min(r.ts) FROM registro.evento r
          WHERE r.tipo = 'etapa.recuperada' AND r.etapa = f.etapa AND r.ts > f.ts)) AS fin
FROM registro.evento f
WHERE f.tipo = 'falla.inyectada' AND f.datos ->> 'tipo' = 'matar';

-- Los pedidos detenidos. D2: los que la etapa tenía en curso al morir y los que
-- ventas le envió hasta que volvió a recibir trabajo (D-4); t0 es el mayor entre la falla y
-- el envío (D-5). Se miran 30 s hacia atrás porque ninguna etapa dura más de
-- 25 s (S-11): un pedido confirmado antes y sin cierre de esa etapa estaba en
-- curso. La ventana no retrocede más allá del fin de la caída anterior de la
-- misma etapa: un pedido detenido allí nunca cierra la etapa, y sin ese límite
-- se contaría otra vez en la caída siguiente. D3: el pedido congelado, con t0
-- cuando entró a la etapa.
CREATE OR REPLACE VIEW registro.e02_detenidos AS
SELECT 'D2'::text AS falla, c.falla_id, c.etapa, p.pedido_id, greatest(c.falla, p.ts) AS t0
FROM registro.e02_caidas c
JOIN registro.evento p
  ON p.tipo = 'pedido.confirmado'
 AND p.ts >= greatest(c.falla - interval '30 seconds',
                      (SELECT max(a.fin) FROM registro.e02_caidas a
                       WHERE a.etapa = c.etapa AND a.falla < c.falla))
 AND p.ts <  coalesce(c.fin, 'infinity')
WHERE NOT EXISTS (SELECT 1 FROM registro.evento x
                  WHERE x.tipo = 'etapa.completada' AND x.pedido_id = p.pedido_id AND x.etapa = c.etapa)
UNION ALL
SELECT 'D3', f.id, f.etapa, f.pedido_id, f.ts
FROM registro.evento f
WHERE f.tipo = 'falla.congelada';

-- Cada detenido con su llegada a la cola: t1 es la confirmación del bróker al
-- Monitor; mensajes es lo que el auditor vio en la copia de la cola.
CREATE OR REPLACE VIEW registro.e02_cruce AS
SELECT d.*,
       e.ts                                              AS encolado,
       round(extract(epoch FROM e.ts - d.t0) * 1000, 1)  AS demora_ms,
       (SELECT count(*) FROM registro.evento m
        WHERE m.tipo = 'mensaje.en.cola' AND m.pedido_id = d.pedido_id AND m.etapa = d.etapa) AS mensajes
FROM registro.e02_detenidos d
LEFT JOIN LATERAL (
    SELECT ts FROM registro.evento e
    WHERE e.tipo = 'pedido.encolado' AND e.pedido_id = d.pedido_id AND e.etapa = d.etapa
    ORDER BY ts LIMIT 1) e ON true;

-- Cada declaración de etapa detenida. Es falsa alarma (un episodio, D-6) si no
-- cae dentro de la ventana de una caída inyectada en esa misma etapa.
CREATE OR REPLACE VIEW registro.e02_declaraciones AS
SELECT d.id, d.ts, d.etapa,
       EXISTS (SELECT 1 FROM registro.e02_caidas c
               WHERE c.etapa = d.etapa AND d.ts >= c.falla
                 AND d.ts <= coalesce(c.fin, 'infinity') + interval '5 seconds') AS justificada
FROM registro.evento d
WHERE d.tipo = 'etapa.declarada.detenida';

-- Mensajes de la cola que no corresponden a ningún pedido detenido: falsas
-- alarmas contadas por mensaje, o pedidos que llegaron a logística.
CREATE OR REPLACE VIEW registro.e02_mensajes_falsos AS
SELECT m.ts, m.pedido_id, m.etapa,
       EXISTS (SELECT 1 FROM registro.evento l
               WHERE l.tipo = 'pedido.en.logistica' AND l.pedido_id = m.pedido_id) AS llego_a_logistica
FROM registro.evento m
WHERE m.tipo = 'pedido.encolado'
  AND NOT EXISTS (SELECT 1 FROM registro.e02_detenidos d
                  WHERE d.pedido_id = m.pedido_id AND d.etapa = m.etapa);
