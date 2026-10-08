# Plan e implementación de los experimentos E01 y E02

2026-10-04. Sale de `docs/experiments.md`, de ADR-004 y ADR-007, del catálogo
de elementos y conectores de `docs/modelos/adrs-ccp-reto2.md` y del diagrama de
alcance del equipo. Toma las convenciones del prototipo del reto 1
(`../arqsoft-reto-1`): monorepo Gradle, `deploy/`, `load/plan.tsv` y un solo
orquestador.

**Estado:** construido con el diseño de DG-CMP-004 y DG-CMP-005, probado con
`make e2e` y corrido. El ciclo de E01 y E02 corrió el 2026-10-07 con
`make experimentos`; los resultados están en `docs/results.md`. Falta `make d4`.

Este documento no cambia el diseño del experimento. Donde el diseño dejaba un
hueco que el código no podía dejar, la sección 2 fija un supuesto con su
razón. Nicolás pidió el 2026-10-04 resolver con supuestos las preguntas
abiertas; cada uno se puede cambiar con una variable, sin tocar código.

---

## 1. Cómo se corre

Requisitos: Docker con Compose, Java 21, k6 y `make`. Todo corre en local.

```bash
make up          # compila, arma las imágenes, levanta todo y espera a los 12 micros
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
| D-3 | Cómo se detiene una etapa en D2 | `docker kill` con SIGKILL, 45 s de caída y reinicio | Es «se detiene el proceso» de `experiments.md`. El trabajo que la etapa no confirmó vuelve a su cola del bróker y se retoma al reiniciar | `CAIDA_S` |
| D-4 | Qué se cuenta en D2 | **Todos** los pedidos detenidos en las 30 caídas, agrupados por caída | Cada caída deja de 20 a 30 pedidos detenidos a esta carga. Contar uno por caída esconde los que llegan con la etapa ya caída | — |
| D-5 | Desde cuándo corre el reloj de un pedido que llega con la etapa ya caída | t0 = el mayor entre la falla y el envío del pedido a la etapa | Medir desde la falla castigaría al Monitor por pedidos que aún no existían | — |
| D-6 | La unidad de la falsa alarma | **Episodios**: una declaración de etapa detenida sin caída inyectada en esa etapa. El informe da también los mensajes | Un solo sondeo perdido encola todos los pedidos en curso de la etapa; contados por mensaje, incumpliría el «≤ 1 por hora» | — |
| D-7 | D4 no cabe en una noche | 20 min de D1 y 15 caídas (5 por etapa) por combinación: ~9 h | D4 es exploratoria. D1 y D2 completas corren con la combinación elegida | `D1_S`, `REPS` |
| D-8 | ¿Se construye el plazo por pedido de ADR-004? | **No.** El experimento lo deja fuera | Si D3 refuta H2, la decisión vuelve a ADR-004 sin haberlo corrido. Agregarlo como `MONITOR_MODO=plazo` costaría medio día | — |
| D-9 | ¿La carga pasa por el micro de sesiones? | No: k6 abre la sesión y envía pedidos directo a ventas | Ninguna hipótesis mide ese salto | — |
| D-10 | Cómo habla ventas con las etapas | Por el bróker de la cadena (T8): `etapa.ejecutar.<etapa>` y `etapa.completada`, como en DG-CMP-005. Nicolás lo eligió el 2026-10-07 | Una etapa caída no le devuelve error a ventas: el pedido simplemente no vuelve, que es la falla de ASR-3. Cada etapa confirma el mensaje al terminar el trabajo | — |
| D-12 | Qué es un pedido detenido | El que no cierra su etapa dentro de los 30 s de ASR-3 | Con el bróker casi todos los pedidos de una etapa caída terminan cerrando cuando vuelve: «nunca cerró» no sirve | — |
| D-13 | Cuándo avisa el Monitor a ventas | En cada ciclo mientras la etapa siga caída. Nicolás lo eligió el 2026-10-07 | Así salen también los pedidos que le llegan a la etapa después del primer aviso | — |
| D-11 | El reloj | Todo t0 y todo t1 los anota un contenedor; el inyector corre dentro de Docker | En macOS, k6 y los scripts del host leen otro reloj | — |
| — | T y N para D1 a D3 | **T = 2 s, N = 3**: N × T = 6 s, con 500 ms de espera por sondeo | Deja 24 s de margen dentro de los 30 s. D4 dirá si hay una combinación mejor | `SONDEO_T_MS`, `SONDEO_N`, `SONDEO_ESPERA_MS` |
| — | Repartición de vendedores | V0001–V1000 fondo · V1001–V1100 S2 · V1201–V1220 S3 · V1501–V2000 intrusos | Que las fases no se pisen: un cambio de S2 no puede volver intruso a una sesión de fondo | — |

---

## 3. Qué se construyó

| Entra | Se simula | Queda fuera |
|---|---|---|
| Gestor de sesión · Verificador de dispositivo · Notificador a seguridad · receptor del SMS · ventas en el papel del Coordinador · las tres etapas · Monitor de la cadena · bróker (T8) y Dead-Letter-Queue (T11) · logística · registro de eventos · carga, inyección y veredicto | El inicio de sesión (sin desafío real) · micro Onboarding · el proveedor de SMS · logística | Matar la sesión · usuarios revocados · Logs · consumir la Dead-Letter-Queue (ASR-4) · el plazo por pedido de ADR-004 |

```
├── services/
│   ├── comun/              Registro de eventos, topología del bróker (Bus), cliente HTTP, SHA-256
│   ├── sesiones/           Gestor de sesión: abre la sesión y publica sesion.abierta
│   ├── usuario-no-valido/  Verificador de dispositivo: compara la huella y publica alerta.seguridad (H1)
│   ├── onboarding/         Simulado: registra el dispositivo nuevo
│   ├── ventas/             Coordinador (EL-16): estado por pedido y etapa; envía a la Dead-Letter-Queue
│   ├── etapa/              Una imagen, tres contenedores; consume su cola, /salud y /fallas/congelar
│   ├── monitor/            Monitor (EL-17): sondeo, cuenta de N y aviso a ventas (H2)
│   └── receptor/           Una imagen, cuatro papeles: ROL=notificador | sms | logistica | auditor-cola
├── deploy/
│   ├── docker-compose.yml  12 micros + PostgreSQL + RabbitMQ + Prometheus + Grafana + inyector
│   ├── postgres/           Esquema, semilla de 2 000 vendedores y vistas del cruce
│   ├── inyector/           docker-cli y psql: anota t0 y mata o congela la etapa
│   └── observabilidad/     Prometheus, fuentes de Grafana y generador de los tableros
├── load/
│   ├── k6/                 e01.js (sesiones por fase) · cadena.js (Ambiente A) · comun.js
│   ├── plan.tsv            Una fila por corrida, con su pregunta
│   └── experimento.sh      El orquestador: preparar, calentar, medir, cerrar, validar, veredicto
├── analisis/
│   ├── e01.sql · e02.sql   El veredicto de cada criterio, en SQL
│   └── resultados/         Una carpeta por corrida del ciclo vigente; no se guarda histórico
└── Makefile
```

### Las piezas que deciden el resultado

**La comparación de huella** (`VerificadorDeDispositivo`). El Gestor de sesión
guarda la sesión, anota t0, publica `sesion.abierta` y responde. El Verificador
consume el evento, lee el dispositivo registrado de la base sin caché y, si no
coincide, publica `alerta.seguridad`. El Notificador la consume y entrega el
aviso al receptor del SMS, que anota t1.

**La cuenta del Monitor** (`CuentaDeSondeos`). Declara detenida la etapa en el
sondeo N sin respuesta seguido y recuperada en el primero que responde. Tiene
pruebas unitarias. Mientras la etapa siga detenida, avisa a ventas en cada
ciclo.

**El envío sin duplicados** (`EnvioALaDeadLetterQueue`, en ventas). Inserta la
señal `(pedido, etapa, intento)` con `ON CONFLICT DO NOTHING`; solo si entra,
publica `pedido.detenido` persistente y espera la confirmación del bróker, que
es t1. Si el bróker no confirma, borra la señal y el aviso siguiente reintenta.

**El bróker.** `Bus` declara toda la topología: el exchange `seguridad` para E01
y el exchange `cadena` (T8) para E02. `pedido.detenido` llega a dos colas: la
`dead-letter-queue`, que nadie consume, y su copia de auditoría, que lee el
auditor para contar perdidos y duplicados. Cada etapa confirma su mensaje al
terminar: si muere, el trabajo vuelve a su cola.

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

## 5. Validez de cada corrida

El orquestador comprueba cada corrida al cerrarla y la da por inválida si pasa
cualquiera de estas tres cosas:

- **Hueco en la carga de fondo** de más de 30 s entre dos pedidos: la máquina se
  congeló. En corridas sanas no pasa de 13 s.
- **Suspensión del equipo** durante la corrida: `pmset` en macOS y el evento 42
  de Kernel-Power en Windows.
- **Más de 1 % de solicitudes fallidas** en k6: la carga no fue la del diseño.

Una corrida inválida descarta el ciclo, que vuelve a empezar desde la primera
corrida. Nicolás lo pidió el 2026-10-07: un ciclo no se reanuda a medias. El
veredicto de cada corrida trae su validez y su hueco máximo. Los resultados
están en `docs/results.md`.

---

## 6. Los riesgos que quedan

| Riesgo | Qué se hace |
|---|---|
| Doce JVM, PostgreSQL, RabbitMQ y la observabilidad en un portátil se pelean por CPU, y un sondeo lento parece una etapa caída | Heap de 256 MB por micro, sondeos con espera de 500 ms, RabbitMQ sin *busy-wait* y el panel de CPU |
| El equipo se suspende a mitad de una corrida | `caffeinate -dims`; con batería el orquestador no arranca; la corrida se invalida si hubo suspensión |
| Docker Desktop se actualiza y se reinicia a mitad de una corrida | Desactivar las actualizaciones automáticas mientras se corre; la preparación levanta toda la topología y la corrida se invalida |
| Abrir Grafana durante una medición carga la máquina | `make up` precalienta Grafana; las capturas se toman al final, con Chrome sin interfaz |
| El registro en memoria pierde eventos si un contenedor muere con la cola llena | El inyector solo mata etapas, que no escriben ni t0 ni t1 de E02. El registro se vacía cada 200 ms y al apagar |

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
8. Definir «pedido detenido» como el que no cierra su etapa en 30 s (D-12).
