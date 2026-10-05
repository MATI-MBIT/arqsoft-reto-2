# Resultados de los experimentos E01 y E02

Bitácora de trabajo de las corridas largas. La versión para lectores está en
`docs/results.md`. Esta se llenó a medida que terminaban las corridas
(`make experimentos`, lanzada el 2026-10-04 a las 18:02). Cuando esté completo,
lo que corresponda pasa a `docs/experiments.md` y a los campos `Results`,
`Analysis of results` y `Links & evidence` de cada experimento en Helix.

Cada cifra sale del veredicto de su corrida (`analisis/resultados/<corrida>/veredicto.txt`),
calculado en SQL sobre el registro de eventos. Las capturas de los tableros
están en `docs/assets/resultados/`, y `tablero.txt` de cada corrida trae el enlace a
Grafana fijado en su ventana.

Montaje: una sola máquina (macOS, Docker Desktop con 14 CPU y 12,5 GB), los
supuestos S-10 y S-11 y T = 2 s, N = 3 para E02. El detalle está en
`notas/plan-implementacion-experimentos.md`.

---

## E01 — Detección del dispositivo no registrado (H1, ASR-1)

### Results

| Fase | Corrida | Casos | Cumplen | Fallan | Veredicto |
|---|---|---|---|---|---|
| S1 · aviso en ≤ 2 s y completo | `e01-s1-20261004-180236` | 50 | 50 | 0 | **PASA** · mediana 22 ms, p95 53 ms, máx. 120 ms |
| S2 · ≤ 1 aviso por 100 cambios | `e01-s2-20261004-180236` | 100 | 100 | 0 | **PASA** · 0 avisos en 100 cambios |
| S3 · 0 avisos a < 1 s del registro | `e01-s3-20261004-180236` | 20 | 20 | 0 | **PASA** · 0 avisos; aperturas entre 52 y 717 ms tras el registro |
| Todas · 0 avisos por dispositivo registrado | las cuatro | 17 832 | 17 832 | 0 | **PASA** · 3 720 + 2 581 + 720 + 10 811 sesiones legítimas |
| S4 · tasa a la que se atrasa el aviso | `e01-s4-20261004-180236` | 30 | 30 | 0 | Exploratoria · no se atrasa hasta 10 aperturas/s (5×): p95 de 56, 38 y 34 ms |

### Analysis of results

Redactado en [docs/results.md](../docs/results.md).

### Links & evidence

- **S1** · [veredicto](resultados/e01-s1-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e01-s1-tablero.png) · 3 720 sesiones de fondo sin aviso
  y 50 intrusos, todos con aviso completo. k6 generó 3 770 aperturas sin
  errores (2,03 por segundo). Observación: la comparación de la huella tuvo un
  pico de p99 de ~400 ms hacia las 18:31, que no coincidió con ningún intruso.
- **S2** · [veredicto](resultados/e01-s2-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e01-s2-tablero.png) · 100 vendedores registraron un
  dispositivo nuevo y abrieron sesión desde él entre 5 y 60 s después: ningún
  aviso. Tampoco en las 2 581 sesiones de fondo.
  **Defecto del montaje encontrado aquí:** k6 repitió 60 identificadores de
  sesión de fondo y el micro rechazó esas aperturas por clave duplicada. No
  entraron a la corrida y no tocan el criterio de S2, cuyos 100 cambios se
  midieron todos. Se corrigió en `load/k6/e01.js` antes de que S3 empezara a
  medir.
- **S3** · [veredicto](resultados/e01-s3-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e01-s3-tablero.png) · 20 aperturas entre 52 y 717 ms
  después de registrar el dispositivo (mediana 329 ms): ninguna disparó aviso,
  porque la comparación lee la base sin caché. 720 sesiones de fondo sin aviso.
  k6 sin solicitudes fallidas: la corrección de los identificadores funcionó.
- **S4** · [veredicto](resultados/e01-s4-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e01-s4-tablero.png) · Tasas logradas: 2,02, 6,02 y 10,02
  aperturas por segundo, 10 minutos cada una, con 10 intrusos por nivel. Los 30
  avisos llegaron a tiempo y la demora no creció con la carga (máximos de 74,
  41 y 35 ms). El número desconocido de H1 queda por encima de 10 aperturas por
  segundo en esta máquina. 10 811 sesiones legítimas sin aviso; k6 sin
  solicitudes fallidas.

---

## E02 — Detección y encolado del pedido detenido (H2, ASR-3)

### Results

| Fase | Corrida | Casos | Cumplen | Fallan | Veredicto |
|---|---|---|---|---|---|
| D1 · ≤ 1 falsa alarma por hora | `e02-d1-20261004-180236` | 0 | — | 0 | **PASA** · 0 declaraciones de etapa detenida y 0 sondeos fallidos en 1 h |
| D2 · todo detenido en la cola en ≤ 30 s | `e02-d2-20261004-180236` | 1 522 | 1 513 | 9 | **FALLA** · mediana 1,1 s, p95 ≤ 5,8 s; 9 pedidos entre 34,7 y 38,1 s |
| D3 · el congelado en la cola en ≤ 30 s | `e02-d3-20261004-180236` | 30 | 0 | 30 | **FALLA** · ninguno llegó a la cola |
| Todas · 0 perdidos y 0 duplicados | `e02-d2-20261004-180236` | 1 522 | 1 522 | 0 | **PASA** · cada pedido encolado una sola vez |

### Analysis of results

Redactado en [docs/results.md](../docs/results.md).

### Links & evidence

- **D1** · [veredicto](resultados/e02-d1-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e02-d1-tablero.png) · Una hora con 3 513 pedidos, todos
  llegados a logística, y 0 sondeos sin respuesta. k6 sostuvo 11 solicitudes
  por segundo (1 pedido y 10 consultas) sin errores.
  **Dato para ADR-004 (TO-004a):** duración medida de cada etapa, de la
  confirmación del pedido a su cierre. p99,9 de 8,79 s (despacho), 8,62 s
  (facturación) y 8,69 s (inventario); máximos de 11,2 s. Cabe en los 25 s de
  SUP-03. Ojo: sale del supuesto S-11, no de etapas reales.
- **D2** · [veredicto](resultados/e02-d2-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e02-d2-tablero.png) · 30 caídas de 45 s, 10 por etapa,
  con 1 522 pedidos detenidos (unos 50 por caída). El Monitor declaró cada caída
  con una mediana de 5,5 s y un máximo de 6,3 s tras la falla, lo que esperaba
  N × T = 6 s, y encoló
  1 513 pedidos en ≤ 30 s, todos una sola vez.
  **Los 9 que fallan son la ventana ciega al recuperarse.** Los 9 salieron de
  ventas entre 0,3 y 1,9 s antes de que su etapa volviera a responder; el envío
  falló y en el ciclo siguiente el Monitor dio la etapa por recuperada, así que
  quedaron detenidos sin señal. Llegaron a la cola solo porque la caída
  siguiente de la misma etapa, unos 35 s después, hizo encolar todos sus
  pendientes. Sin esa caída habrían sido escapes permanentes. Es una falla del
  sondeo puro, no del montaje: el sondeo mira la etapa, no el pedido.
- **D3** · [veredicto](resultados/e02-d3-20261004-180236/veredicto.txt) ·
  [tablero](../docs/assets/resultados/e02-d3-tablero.png) · 30 pedidos congelados, 10 por
  etapa, dentro de etapas que seguían respondiendo. En toda la corrida hubo 0
  sondeos sin respuesta y 0 declaraciones de etapa detenida, y ninguno de los
  30 llegó a la cola. Al final de la corrida, ventas los seguía teniendo en
  curso: detenidos sin señal, la falla exacta que describe ASR-3. Es lo que
  ADR-004 predijo del sondeo solo.
