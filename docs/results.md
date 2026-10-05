---
title: Resultados de E01 y E02
nav_order: 9
helix_section: "Experiments → Results & analysis"
---

# Resultados de los experimentos E01 y E02

H1 se sostiene y H2 cae. El micro de sesiones avisó a seguridad en las 50
aperturas desde un dispositivo no registrado, con 120 ms en el peor caso. No
dio ninguna falsa alarma en 17 832 sesiones desde el dispositivo registrado.
El sondeo del Monitor detectó las etapas caídas en unos 6 s. Pero no vio
ninguno de los 30 pedidos congelados dentro de una etapa viva, ni los pedidos
que ventas envió mientras la etapa caída arrancaba.

| Experimento | Hipótesis | Escenario | Veredicto | Decisión |
|---|---|---|---|---|
| E01 — Seguridad | H1: el micro de sesiones compara la huella del dispositivo al abrir la sesión | ASR-1 | Se sostiene en S1, S2 y S3 | Aceptar ADR-007 |
| E02 — Disponibilidad | H2: el Monitor de la cadena sondea las etapas y encola el pedido detenido | ASR-3 | Cae en D3. D2 pasa con el criterio literal y falla al contar todos los pedidos detenidos | Confirmar ADR-004 |

El diseño de cada experimento, sus fases y su tabla de decisiones están en
[Experimentos E01 y E02](experiments.md). Esta página da lo que salió de las
corridas del 4 de octubre de 2026.

## Cómo se midió

Las corridas usaron el prototipo que vive en este repositorio: once micros en
Java 21 y Spring Boot 3, PostgreSQL y RabbitMQ en Docker Compose, todo en una
sola máquina. k6 generó la carga del Ambiente A de principio a fin de cada
corrida, con 1 pedido y 10 consultas por segundo y arribo aleatorio.

Cada componente anotó en una tabla de eventos el identificador de la sesión o
del pedido y el instante de cada hecho. El veredicto de cada criterio sale de
cruzar esas filas una a una, en SQL: una falla inyectada contra la salida que
causó. Prometheus y Grafana mostraron la corrida en vivo, pero ninguna cifra de
esta página sale de ellos, porque agregan los datos y pierden el identificador.

Las corridas las lanzó en serie un orquestador, el guion `load/experimento.sh`,
que se invoca con `make experimentos`. Cada corrida empezó con 5 minutos de
calentamiento que no entran en ningún criterio. Entre una corrida y la
siguiente, el orquestador reinició la base y las colas, para que lo detenido en
una no apareciera como pendiente en la otra.

Las cifras que el enunciado no da se fijaron como supuestos, y cada una se
cambia con una variable sin tocar el código:

| Supuesto | Valor | De dónde sale |
|---|---|---|
| S-10 · aperturas desde el dispositivo registrado | 2 por segundo | 2 000 vendedores que reabren sesión cada 15 min, al vencer el token (SUP-05) |
| S-11 · duración de cada etapa | Lognormal, mediana de 2 s, p99,9 cercano a 9 s, tope de 25 s | Variación normal por debajo de los 25 s de SUP-03 |
| T y N del Monitor | Sondeo cada 2 s; etapa detenida tras 3 sondeos sin respuesta | N × T = 6 s, dentro de los 30 s de ASR-3 |
| Caída de una etapa (D2) | El proceso muere con SIGKILL durante 45 s y luego se reinicia | Una etapa pausada terminaría al reanudar los pedidos que tenía, y contarían como falsas alarmas |

---

## E01 — Detección del dispositivo no registrado

### Results

| Fase | Casos | Cumplen | Fallan | Veredicto |
|---|---|---|---|---|
| S1 · aviso en ≤ 2 s, con vendedor, dispositivo y hora | 50 | 50 | 0 | **Pasa** |
| S2 · ≤ 1 aviso por cada 100 cambios legítimos | 100 | 100 | 0 | **Pasa**: 0 avisos |
| S3 · 0 avisos en aperturas a menos de 1 s del registro | 20 | 20 | 0 | **Pasa** |
| Las cuatro fases · 0 avisos por el dispositivo registrado | 17 832 | 17 832 | 0 | **Pasa** |
| S4 · tasa a la que el aviso se atrasa | 30 | 30 | 0 | Exploratoria: no se atrasa hasta 10 aperturas por segundo |

| Demora del aviso | Desde dispositivo no registrado | Mediana | p95 | Máximo |
|---|---|---|---|---|
| S1, a la tasa normal | 50 | 22 ms | 53 ms | 120 ms |
| S4 a 1× (2 aperturas/s) | 10 | 30 ms | 56 ms | 74 ms |
| S4 a 3× (6 aperturas/s) | 10 | 27 ms | 38 ms | 41 ms |
| S4 a 5× (10 aperturas/s) | 10 | 30 ms | 34 ms | 35 ms |

### Analysis of results

La demora del aviso está muy por debajo del umbral de ASR-1. El peor aviso de
las cuatro corridas tardó 120 ms, menos de la décima parte de los 2 s. La
comparación es una sola lectura en la base y corre después de abrir la sesión,
así que no compite con el inicio de sesión del vendedor.

No hubo ninguna falsa alarma: ni en S2, ni en S3, ni en las sesiones desde el
dispositivo registrado. En S2, 100 vendedores registraron un dispositivo nuevo
y abrieron sesión desde él entre 5 y 60 s después. En S3, otros 20 la abrieron
entre 52 y 717 ms después del registro. Ninguno disparó aviso, porque el micro
lee el dispositivo registrado sin caché y ve el cambio en cuanto se confirma.

S4 no encontró el número que buscaba. A 10 aperturas por segundo, cinco veces
la tasa normal, la demora siguió igual que a la tasa normal. El límite de H1
queda por encima de lo que se probó y la decisión no depende de él.

En la corrida de S2, k6 repitió 60 identificadores de sesiones desde el
dispositivo registrado, y el micro rechazó esas aperturas por clave duplicada.
Fue un defecto del guion de carga, no del diseño. No toca el criterio de S2,
cuyos 100 cambios se midieron todos, y se corrigió antes de que S3 empezara a
medir.

### Links & evidence

| Fase | Veredicto | Tablero de la corrida |
|---|---|---|
| S1 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e01-s1-20261004-180236/veredicto.txt) | [captura](assets/resultados/e01-s1-tablero.png) |
| S2 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e01-s2-20261004-180236/veredicto.txt) | [captura](assets/resultados/e01-s2-tablero.png) |
| S3 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e01-s3-20261004-180236/veredicto.txt) | [captura](assets/resultados/e01-s3-tablero.png) |
| S4 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e01-s4-20261004-180236/veredicto.txt) | [captura](assets/resultados/e01-s4-tablero.png) |

![Tablero de E01 durante S1: 50 aperturas desde un dispositivo no registrado, 50 avisos a tiempo, 0 escapes, 0 falsas alarmas y la demora de cada aviso](assets/resultados/e01-s1-tablero.png)

### La decisión

H1 se sostiene en S1, S2 y S3, así que la tabla de decisiones de E01 lleva a
**aceptar ADR-007**. La comparación de la huella se queda dentro del micro de
sesiones. Ninguna de las otras filas aplica: no hubo aviso tarde ni falso, y en
S4 la demora no creció a 3 ni a 5 veces la tasa normal.

Aceptarlo así pide ajustar el texto de ADR-007. Su decisión describe un
Verificador de dispositivo aparte, que consume cada apertura como evento del
bróker. El experimento probó la otra forma, la del
[diagrama de alcance del equipo](experiments.md#el-prototipo), y es esa la que
queda validada. [PREGUNTA] ¿Quién ajusta ADR-007 y para cuándo?

---

## E02 — Detección y encolado del pedido detenido

### Results

| Fase | Casos | Cumplen | Fallan | Veredicto |
|---|---|---|---|---|
| D1 · ≤ 1 falsa alarma por hora, en 1 h sin fallas | 0 declaraciones | — | 0 | **Pasa** |
| D2 · los pedidos en curso al caer la etapa, en la cola en ≤ 30 s | 91 | 91 | 0 | **Pasa**: demora máxima de 6,4 s |
| D2 · todos los pedidos detenidos, en la cola en ≤ 30 s | 1 537 | 1 512 | 25 | **Falla**: 23 tarde y 2 nunca |
| D3 · el pedido congelado en una etapa viva, en la cola en ≤ 30 s | 30 | 0 | 30 | **Falla** |
| D2 · cada pedido que llegó a la cola entró una sola vez | 1 535 | 1 535 | 0 | **Pasa**: 0 duplicados |

`experiments.md` cuenta en D2 «los 30 pedidos» de las 30 caídas, y el
inyector mata la etapa «con pedidos en curso». Esos son los 91 de la segunda
fila. Las caídas de 45 s, con un pedido por segundo, dejaron detenidos además 1 446
pedidos que ventas envió con la etapa ya caída. La tercera fila los cuenta a
todos.

| Demora hasta la cola en D2 | Detenidos | Mediana | p95 | Máximo |
|---|---|---|---|---|
| Despacho | 487 | 1,1 s | 4,8 s | 35,4 s |
| Facturación | 520 | 1,1 s | 5,8 s | 37,9 s |
| Inventario | 530 | 1,1 s | 5,5 s | 38,1 s |

### Analysis of results

El sondeo cumple lo que promete para las etapas caídas. En cada una de las 30
caídas de D2, el Monitor declaró detenida la etapa con una mediana de 5,5 s y
un máximo de 6,3 s. Es lo que predice N × T = 6 s. En D1, una hora entera sin
fallas, no hubo un solo sondeo sin respuesta ni una falsa alarma.

**D3 refuta H2.** En toda la corrida, ningún sondeo quedó sin respuesta y el
Monitor no declaró detenida ninguna etapa. Los 30 pedidos congelados nunca
llegaron a la cola, y al final de la corrida seguían en curso, sin señal. Es la
falla exacta que describe ASR-3: la etapa sigue viva y responde, pero el pedido
no avanza. El equipo lo previó en ADR-004, y por eso eligió allí un plazo por
pedido y etapa.

D2 tiene su propio punto ciego, al final de cada caída. Los 25 pedidos que
fallan salieron de ventas en una ventana de hasta 8 s alrededor del reinicio de
su etapa. En esa ventana, el proceso ya respondía al sondeo pero aún rechazaba
trabajos. El envío falló, y el Monitor dio la etapa por recuperada apenas el
sondeo respondió.

El Monitor solo encola los pendientes de una etapa mientras la tiene declarada
detenida. Por eso esos 25 quedaron detenidos sin señal. Veintitrés llegaron a
la cola entre 32 y 38 s después, por una coincidencia del montaje: la caída
inyectada siguiente en la misma etapa hizo encolar todos sus pendientes. Los otros 2 nunca llegaron.

Esa ventana dejó además 53 mensajes de más en la cola. Durante esos segundos,
el Monitor encoló 53 pedidos que la etapa sí procesó y que llegaron a
logística. `experiments.md` cuenta cada uno de esos mensajes como falsa alarma.
El criterio de D1, que cuenta declaraciones de etapa detenida, da 0 en D2, y
los 53 mensajes quedan fuera de él. Pero con un consumidor real de la cola, el
de ASR-4, serían 53 reanudaciones de pedidos que no estaban detenidos.

Las dos fallas tienen la misma raíz: el sondeo mira si la etapa responde, no si
cada pedido avanzó. Un plazo por pedido vencería en los dos casos, sin importar
lo que le pase a la etapa.

D1 deja además el dato que ADR-004 necesitaba para calibrar ese plazo (TO-004a).
Sobre 3 513 pedidos, el p99,9 de la duración fue de 8,79 s en despacho, 8,62 s
en facturación y 8,69 s en inventario, con máximos de 11,2 s. Ese dato sale del
supuesto S-11, no de etapas reales, y así debe leerse.

### Links & evidence

| Fase | Veredicto | Tablero de la corrida |
|---|---|---|
| D1 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e02-d1-20261004-180236/veredicto.txt) | [captura](assets/resultados/e02-d1-tablero.png) |
| D2 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e02-d2-20261004-180236/veredicto.txt) | [captura](assets/resultados/e02-d2-tablero.png) |
| D3 | [veredicto.txt](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/analisis/resultados/e02-d3-20261004-180236/veredicto.txt) | [captura](assets/resultados/e02-d3-tablero.png) |

![Tablero de E02 durante D2: el estado que declara el Monitor de cada etapa, los sondeos fallidos contra N y la demora hasta la cola de cada pedido detenido](assets/resultados/e02-d2-tablero.png)

### La decisión

Con el criterio de `experiments.md`, D1 y D2 pasan y D3 falla. Es la fila
«H2 pasa D1 y D2 pero falla D3», que lleva a **confirmar ADR-004**. El plazo
vencido por pedido y etapa es el mecanismo de detección de ASR-3. El sondeo del
Monitor queda como apoyo para adelantar la señal cuando cae una etapa entera.

El conteo completo de D2 no cambia la decisión: la refuerza. La fila de D2
prevé buscar en D4 otra combinación de T y N cuando el Monitor no detecta a
tiempo la etapa caída. Aquí la detectó en 6,3 s en el peor caso. Lo que
falló fue la ventana al recuperarse, y ninguna combinación de T y N la cierra:
la cierra el plazo por pedido.

---

## Dónde la medición se apartó de experiments.md

Cuatro reglas de medición no estaban escritas o no se podían aplicar al pie de
la letra. Están en el
[plan de implementación](https://github.com/MATI-MBIT/arqsoft-reto-2/blob/main/notas/plan-implementacion-experimentos.md)
y no cambian ninguna decisión.

| Tema | `experiments.md` | Lo que se midió | Efecto |
|---|---|---|---|
| Pedidos de D2 | «Los 30 pedidos» de las 30 caídas | Los 91 en curso al caer la etapa, y aparte los 1 537 detenidos | El literal pasa; el conteo completo falla |
| Reloj de D2 | Arranca cuando el inyector detiene la etapa | Para el pedido que llega con la etapa caída, arranca cuando ventas se lo envía | Medido desde la caída, 527 pedidos pasarían de 30 s solo por llegar tarde a una caída de 45 s |
| Falsa alarma | Cada mensaje sobre un pedido que llegó a logística | El criterio de D1 cuenta declaraciones de etapa detenida; los mensajes se informan aparte | D1 da 0 por las dos vías; D2 da 0 declaraciones y 53 mensajes |
| Tasa de aperturas de S4 | 1, 3 y 5 veces la del Ambiente A, que no la fija | S-10: 2 aperturas por segundo | El límite de H1 queda por encima de 10 por segundo |

---

## Lo que estos resultados no cubren

- **Una sola máquina.** Los experimentos validan las ideas de diseño, no el
  tamaño de la infraestructura. Con red y base reales, las demoras de E01
  serían mayores, y estas corridas no dicen cuánto.
- **Duraciones supuestas.** Las etapas duran lo que fija S-11. Antes de aceptar
  ADR-004, su plazo se tiene que calibrar con etapas reales. [PREGUNTA] ¿Quién
  consigue esas duraciones y para cuándo?
- **D4 no corrió.** Falta el número que E02 debía entregar: el menor N sin
  falsas alarmas, y su N × T. No cambia la decisión, porque la falla de H2 no
  depende de T ni de N. [PREGUNTA] ¿Se corre D4 y, si se corre, cuándo?
- **El plazo por pedido no se probó.** E02 confirma que el sondeo solo no basta;
  no mide el mecanismo de ADR-004. [PREGUNTA] ¿Quién arma ese experimento y para
  qué fecha?
- **El panel de k6 en Grafana tiene huecos.** Los dos procesos de k6 de cada
  corrida escribían la misma serie en Prometheus, que rechazó algunos lotes. No
  afecta ningún veredicto y ya está corregido en el orquestador.
