-- E02 · de la señal a la cola, la medida de ASR-4 que este prototipo puede tomar.
-- Uso: make psql < analisis/e02-senal.sql con -v ciclo=20261012-151148
-- De la señal a la cola, por tipo de falla. D3: señal = el Monitor detecta el pedido atascado.
-- D2: señal = el Monitor declara detenida la etapa; cuenta solo los pedidos que ya estaban en ella.
WITH w AS (SELECT id, inicio, fin FROM registro.corrida WHERE id LIKE 'e02-%' || :'ciclo'),
d3 AS (
  SELECT extract(epoch FROM e.ts - a.ts) * 1000 AS ms
  FROM w JOIN registro.evento a ON a.tipo = 'pedido.atascado.detectado' AND a.ts BETWEEN w.inicio AND w.fin
  JOIN registro.evento e ON e.tipo = 'pedido.encolado' AND e.pedido_id = a.pedido_id AND e.etapa = a.etapa
  WHERE w.id LIKE '%-d3-%'),
decl AS (
  SELECT d.etapa, d.ts FROM w JOIN registro.evento d ON d.tipo = 'etapa.declarada.detenida'
  AND d.ts BETWEEN w.inicio AND w.fin WHERE w.id LIKE '%-d2-%'),
d2 AS (
  SELECT extract(epoch FROM e.ts - k.ts) * 1000 AS ms
  FROM decl k
  JOIN registro.evento e ON e.tipo = 'pedido.encolado' AND e.etapa = k.etapa
       AND e.ts BETWEEN k.ts AND k.ts + interval '30 seconds'
  JOIN registro.evento p ON p.tipo = 'pedido.confirmado' AND p.pedido_id = e.pedido_id
  WHERE NOT EXISTS (SELECT 1 FROM decl k2 WHERE k2.etapa = k.etapa AND k2.ts > k.ts AND k2.ts <= e.ts)
    AND (e.datos->>'transcurridoMs')::bigint > extract(epoch FROM e.ts - k.ts) * 1000)
SELECT 'D3' AS fase, count(*), round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms)::numeric, 1) AS mediana,
       round(max(ms)::numeric, 1) AS maximo FROM d3
UNION ALL
SELECT 'D2', count(*), round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms)::numeric, 1), round(max(ms)::numeric, 1) FROM d2;
