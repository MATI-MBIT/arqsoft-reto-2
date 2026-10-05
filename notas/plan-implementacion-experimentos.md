# Plan e implementación de los experimentos E01 y E02

2026-10-04. Sale de `docs/experiments.md`, de ADR-004 y ADR-007, del catálogo
de elementos y conectores de `docs/modelos/adrs-ccp-reto2.md` y del diagrama de
alcance del equipo. Toma las convenciones del prototipo del reto 1
(`../arqsoft-reto-1`): monorepo Gradle, `deploy/`, `load/plan.tsv` y un solo
orquestador.

**Estado:** construido, probado con `make e2e` y corrido. E01 y E02 corrieron
el 2026-10-04 con `make experimentos`; los resultados están en
`docs/results.md`. Falta `make d4`.

Este documento no cambia el diseño del experimento. Donde el diseño dejaba un
hueco que el código no podía dejar, la sección 2 fija un supuesto con su
razón. Nicolás pidió el 2026-10-04 resolver con supuestos las preguntas
abiertas; cada uno se puede cambiar con una variable, sin tocar código.

---

## 1. Cómo se corre

Requisitos: Docker con Compose, Java 21, k6 y `make`. Todo corre en local.

```bash
make up          # compila, arma las imágenes, levanta todo y espera a los 11 micros
make tablero     # abre los tableros de Grafana de E01 y E02
make smoke       # humo de ~7 min: E01 y E02 de punta a punta, con veredicto
make e01         # S1, S2, S3 y S4 (~2 h)
make e02         # D1, D2 y D3 con T = 2 s y N = 3 (~3 h)
make d4          # las 12 combinaciones de T y N (~9 h, para la noche)
make plan        # las corridas del plan y a qué pregunta responde cada una
make help        # todos los comandos
```

Cada corrida deja en `analisis/resultados/<corrida>/` el `veredicto.txt`, los
eventos crudos en CSV, la salida de k6 y la copia del plan con que corrió.
`make veredicto CORRIDA=<id>` lo recalcula desde el registro de eventos.

---

## 2. Supuestos fijados

| # | Hueco | Supuesto | Por qué | Variable |
|---|---|---|---|---|
| S-10 | La tasa normal de aperturas de sesión. El Ambiente A fija pedidos y consultas, pero no aperturas | **2 aperturas por segundo** desde el dispositivo registrado | Con 2 000 vendedores activos y el token de 15 min de SUP-05, cada vendedor vuelve a abrir sesión cada 900 s: 2 000 / 900 ≈ 2,2 por segundo. S4 sube a 2, 6 y 10 | `TASA_BASE` |
| S-11 | Cuánto dura cada etapa | **Lognormal con mediana de 2 s y sigma 0,5**: el p99,9 queda cerca de 9,4 s, con tope de 25 s | Deja variación normal que el Monitor tiene que tolerar y cabe en los 25 s de SUP-03. D1 mide de paso el p99,9 real por etapa, que es el dato que ADR-004 pide para calibrar su plazo (TO-004a) | `ETAPA_MEDIANA_MS`, `ETAPA_SIGMA` |
| D-3 | Cómo se detiene una etapa en D2 | `docker kill` con SIGKILL, 45 s de caída y reinicio | Con `docker pause`, al reanudar la etapa termina los pedidos en curso: llegarían a logística después de estar en la cola y contarían como falsas alarmas | `CAIDA_S` |
| D-4 | Qué se cuenta en D2 | **Todos** los pedidos detenidos en las 30 caídas, agrupados por caída | Cada caída deja de 20 a 30 pedidos detenidos a esta carga. Contar uno por caída esconde los que llegan con la etapa ya caída | — |
| D-5 | Desde cuándo corre el reloj de un pedido que llega con la etapa ya caída | t0 = el mayor entre la falla y el envío del pedido a la etapa | Medir desde la falla castigaría al Monitor por pedidos que aún no existían | — |
| D-6 | La unidad de la falsa alarma | **Episodios**: una declaración de etapa detenida sin caída inyectada en esa etapa. El informe da también los mensajes | Un solo sondeo perdido encola todos los pedidos en curso de la etapa; contados por mensaje, incumpliría el «≤ 1 por hora» | — |
| D-7 | D4 no cabe en una noche | 20 min de D1 y 15 caídas (5 por etapa) por combinación: ~9 h | D4 es exploratoria. D1 y D2 completas corren con la combinación elegida | `D1_S`, `REPS` |
| D-8 | ¿Se construye el plazo por pedido de ADR-004? | **No.** El experimento lo deja fuera | Si D3 refuta H2, la decisión vuelve a ADR-004 sin haberlo corrido. Agregarlo como `MONITOR_MODO=plazo` costaría medio día | — |
| D-9 | ¿La carga pasa por el micro de sesiones? | No: k6 abre la sesión y envía pedidos directo a ventas | Ninguna hipótesis mide ese salto | — |
| D-10 | Cómo habla ventas con las etapas | HTTP con `202 Accepted` y aviso de vuelta cuando la etapa termina | Una llamada que espera la respuesta le devolvería un error a ventas, y ASR-3 describe la falla que **no** señala error | — |
| D-11 | El reloj | Todo t0 y todo t1 los anota un contenedor; el inyector corre dentro de Docker | En macOS, k6 y los scripts del host leen otro reloj | — |
| — | T y N para D1 a D3 | **T = 2 s, N = 3**: N × T = 6 s, con 500 ms de espera por sondeo | Deja 24 s de margen dentro de los 30 s. D4 dirá si hay una combinación mejor | `SONDEO_T_MS`, `SONDEO_N`, `SONDEO_ESPERA_MS` |
| — | Repartición de vendedores | V0001–V1000 fondo · V1001–V1100 S2 · V1201–V1220 S3 · V1501–V2000 intrusos | Que las fases no se pisen: un cambio de S2 no puede volver intruso a una sesión de fondo | — |

---

## 3. Qué se construyó

| Entra | Se simula | Queda fuera |
|---|---|---|
| Micro de sesiones con la comparación de huella · usuario no válido · receptor del SMS · ventas en el papel del Coordinador · las tres etapas · Monitor de la cadena · cola de reintentos · logística como receptor · registro de eventos · carga, inyección y veredicto | El inicio de sesión (sin desafío real) · micro Onboarding · el proveedor de SMS · logística | Matar la sesión · usuarios revocados · Logs · consumir la cola de reintentos (ASR-4) · el plazo por pedido de ADR-004 |

```
├── services/
│   ├── comun/              Registro de eventos, cliente HTTP con tiempos de espera, SHA-256
│   ├── sesiones/           Apertura de la sesión y comparación de huella después de abrirla (H1)
│   ├── usuario-no-valido/  Arma el aviso con vendedor, dispositivo y hora
│   ├── onboarding/         Simulado: registra el dispositivo nuevo
│   ├── ventas/             Coordinador (EL-16): estado por pedido y etapa, /pendientes
│   ├── etapa/              Una imagen, tres contenedores; /salud y /fallas/congelar
│   ├── monitor/            Monitor (EL-17): sondeo, cuenta de N, encolado con confirmación (H2)
│   └── receptor/           Una imagen, tres papeles: ROL=sms | logistica | auditor-cola
├── deploy/
│   ├── docker-compose.yml  11 micros + PostgreSQL + RabbitMQ + Prometheus + Grafana + inyector
│   ├── postgres/           Esquema, semilla de 2 000 vendedores y vistas del cruce
│   ├── inyector/           docker-cli y psql: anota t0 y mata o congela la etapa
│   └── observabilidad/     Prometheus, fuentes de Grafana y generador de los tableros
├── load/
│   ├── k6/                 e01.js (sesiones por fase) · cadena.js (Ambiente A) · comun.js
│   ├── plan.tsv            Una fila por corrida, con su pregunta
│   └── experimento.sh      El orquestador: preparar, calentar, medir, cerrar, veredicto
├── analisis/
│   ├── e01.sql · e02.sql   El veredicto de cada criterio, en SQL
│   └── resultados/         Una carpeta por corrida
└── Makefile
```

### Las piezas que deciden el resultado

**La comparación de huella** (`VerificadorDeHuella`). El micro de sesiones
guarda la sesión, anota t0 y responde. Después, en un hilo virtual aparte, lee
el dispositivo registrado de la base, sin caché, y avisa si no coincide.

**La cuenta del Monitor** (`CuentaDeSondeos`). Declara detenida la etapa en el
sondeo N sin respuesta seguido y recuperada en el primero que responde. Tiene
pruebas unitarias.

**El encolado sin duplicados** (`Encolador`). Inserta la señal
`(pedido, etapa, intento)` con `ON CONFLICT DO NOTHING`; solo si entra, publica
el mensaje persistente y espera la confirmación del bróker, que es t1. Si el
bróker no confirma, borra la señal y el ciclo siguiente reintenta.

**La cola.** Un exchange fanout entrega cada mensaje a `reintentos`, que nadie
consume, y a `reintentos.auditoria`, que lee el auditor. Así se cuentan
perdidos y duplicados sin consumir la cola de reintentos.

**El registro de eventos.** Cada micro toma el instante del hecho y lo pone en
una cola en memoria; un hilo aparte la vacía a PostgreSQL cada 200 ms. La
escritura no entra en el camino que se mide.

**El cruce.** Las vistas de `deploy/postgres/03-vistas.sql` cruzan cada falla
con su salida por identificador. Las leen el veredicto y el tablero, así que
los dos cuentan igual. El identificador de cada sesión lleva la fase y el tipo
(`S1-INTRUSO-<corrida>-…`), y el análisis sabe por él qué esperaba de cada
una.

---

## 4. La observabilidad

Dos tableros aprovisionados en Grafana (`make tablero`), uno por experimento.
Cada uno combina dos fuentes:

- **El registro de eventos**, en PostgreSQL. Arriba, el veredicto en vivo sobre
  la ventana del tablero: casos, a tiempo, escapes, duplicados y falsas
  alarmas. En el centro, un punto por cada sesión o pedido detenido con su
  demora y la línea del umbral. Abajo, las tablas de escapes y falsas alarmas,
  y cada caída con el tiempo que tardó el Monitor en declararla.
- **Prometheus**, que raspa cada 2 s los micros, RabbitMQ y lo que k6 empuja.
  En E02, el estado que el Monitor declara de cada etapa, los sondeos fallidos
  contra N, los pedidos en curso por etapa, los mensajes en la cola, la
  duración de cada etapa en p50 y p99,9 y la CPU.

Las anotaciones marcan cada falla inyectada (rojo), cada etapa que vuelve a
responder (verde) y la ventana de medición de cada corrida (azul).

El veredicto no sale de Prometheus, que agrega y pierde el identificador. Sale
del registro de eventos, y Grafana muestra ese mismo cruce.

---

## 5. Lo que mostró el humo

El humo del 2026-10-04 corrió los dos experimentos de punta a punta, en
versión corta.

| Criterio | Resultado del humo |
|---|---|
| E01 · S1, S2, S3 y sin avisos por dispositivo registrado | PASA en los cuatro: 5 de 5 intrusos con aviso, el peor en 18 ms |
| E02 · D1 | PASA: ninguna falsa alarma dentro de la corrida |
| E02 · D2 | 76 de 77 pedidos detenidos llegaron a la cola, con 6 s de demora máxima. Un escape |
| E02 · D3 | FALLA en los 3: el sondeo no ve el pedido congelado en una etapa viva, como predijo ADR-004 |
| E02 · sin perdidos ni duplicados | PASA |

Tres hallazgos que las corridas largas tienen que confirmar o descartar:

1. **El escape de D2 es una ventana ciega del sondeo puro.** Ventas le envió un
   pedido a la etapa mientras arrancaba, 50 ms después del último ciclo del
   Monitor, y el envío falló. En el ciclo siguiente la etapa ya respondía: el
   Monitor la declaró recuperada y ese pedido quedó en curso para siempre, sin
   señal. Es una falla del diseño de H2, no del montaje, y el veredicto la
   cuenta.
2. **D3 refuta H2.** Si las corridas largas lo confirman, la tabla de
   decisiones de `docs/experiments.md` dice «confirmar ADR-004».
3. **La observabilidad puede perturbar la medición.** La primera vez que se
   abrió el tablero, Grafana arrancó su plugin de PostgreSQL. En esos segundos,
   los sondeos del Monitor se vencieron en las tres etapas y hubo una falsa
   alarma. Además, RabbitMQ gastaba un núcleo entero en reposo por el
   *busy-wait* de Erlang. Se corrigieron las dos cosas: `make up` precalienta
   Grafana y RabbitMQ corre sin *busy-wait*. El panel de CPU queda en el
   tablero para revisar cualquier falsa alarma antes de culpar al diseño.

---

## 6. Los riesgos que quedan

| Riesgo | Qué se hace |
|---|---|
| Once JVM, PostgreSQL, RabbitMQ y la observabilidad en un portátil se pelean por CPU, y un sondeo lento parece una etapa caída | Heap de 256 MB por micro, sondeos con espera de 500 ms y el panel de CPU. Una falsa alarma en D1 se revisa primero contra la CPU |
| La suspensión del portátil a mitad de D4 rompe la corrida | El orquestador corre bajo `caffeinate` |
| El registro en memoria pierde eventos si un contenedor muere con la cola llena | El inyector solo mata etapas, que no escriben ni t0 ni t1 de E02. El registro se vacía cada 200 ms y al apagar |
| La primera caída de una sesión tardó 9 s más en recuperarse que las siguientes | Pasó una vez, antes de registrar la causa de cada sondeo fallido. Ahora cada `sondeo.fallido` lleva su causa para diagnosticarlo si se repite |

---

## 7. Cambios que esto pide a `docs/experiments.md`

No se aplicaron: van con la skill de escritura y la regla de flujo de
`CLAUDE.md`.

1. Responder el `[PREGUNTA]` sobre dónde vive el código: en este repositorio.
2. Corregir «todos los componentes leen el mismo reloj»: vale para lo que corre
   en Docker, y por eso el inyector corre ahí (D-11).
3. En D2, evaluar todos los pedidos detenidos, con el t0 de D-5 (D-4).
4. Definir la falsa alarma de E02 por episodio (D-6).
5. Ajustar D4 a ~9 h (D-7).
6. Agregar los supuestos S-10 y S-11, con su derivación.
7. Anotar que D2 detiene la etapa con `kill` y no con `pause` (D-3).
8. Anotar en las limitaciones de E02 la ventana ciega al recuperarse la etapa,
   si las corridas largas la confirman.
