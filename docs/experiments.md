---
title: Experimento E01 — detección y reacción
nav_order: 8
helix_section: "Experiments"
---

# Experimento E01 — detección del dispositivo no registrado, y reacción ante el pedido detenido

Este experimento pone a prueba dos ideas de diseño con un solo prototipo, y cada
una tiene su propio alcance:

- **H1, de seguridad, cubre la detección.** Al abrirse cada sesión, el micro de
  sesiones compara la huella del dispositivo con la registrada para el vendedor,
  y avisa a seguridad cuando no coinciden. Ese aviso es toda la respuesta que el
  escenario le pide al sistema.
- **H2, de disponibilidad, cubre la detección y la reacción.** El Monitor de
  la cadena sondea cada cierto tiempo las etapas que siguen al pedido y detecta
  la que deja de responder. La reacción consiste solo en enviar el pedido
  detenido a una cola de contingencia.

Los escenarios de calidad que cada idea debe cumplir son ASR-1 y ASR-3, y están
en [ASRs de disponibilidad y seguridad](quality-attributes.md). Las decisiones
con las que se comparan los resultados están en el
[registro de ADR](modelos/adrs-ccp-reto2.md).

## El título del experimento

**E01 — Validar la detección del dispositivo no registrado con el micro de
sesiones, y la detección y el encolado del pedido detenido con el Monitor de la
cadena.**

## Las hipótesis de diseño

### H1 — Seguridad: el micro de sesiones detecta la huella de un dispositivo no registrado

**Si el micro de sesiones compara la huella del dispositivo —el ID que la base
guarda para cada vendedor— apenas se abre la sesión, entonces seguridad recibirá
el aviso en ≤ 2 s, porque la comparación es una sola lectura en la base y no
bloquea el inicio de sesión.**

- **Variable independiente:** dónde y cuándo se compara la huella. Se compara
  en el micro de sesiones, en cada apertura y contra el registro de la base, sin
  caché.
- **Variables dependientes:** la demora entre la apertura de la sesión y el
  aviso; los avisos falsos por cada 100 cambios legítimos de dispositivo, que
  ASR-1 limita a uno; y las aperturas desde un dispositivo no registrado que
  quedan sin aviso.

Fundamento: CCP le entrega el dispositivo a cada vendedor, de modo que el
sistema tiene contra qué comparar aunque las credenciales sean correctas. La
comparación corre después de abrir la sesión, así que no frena al vendedor
legítimo.

El cambio legítimo de dispositivo no dispara el aviso porque se registra antes
del primer uso: en el prototipo, el micro Onboarding registra el dispositivo
nuevo. [PREGUNTA] ¿Quién lo registra en la operación real? ADR-007 lo dejó
abierto.

Lo que la refutaría, cualquiera de tres casos:

- Una sesión abierta desde un dispositivo no registrado que no produce aviso, o
  que lo produce fuera de plazo.
- Avisos disparados por dispositivos nuevos ya registrados en más de uno de cada 100
  cambios legítimos.
- Un aviso que llega sin el vendedor, el dispositivo o la hora, que es lo que
  seguridad necesita para actuar.

El número que no conocemos: la tasa de aperturas de sesión por segundo a partir
de la cual el aviso empieza a atrasarse. Los 2 000 vendedores abren sesión
sobre todo al arrancar la jornada, y no sabemos cuánto margen queda por encima
de esa ráfaga.

### H2 — Disponibilidad: el Monitor de la cadena detecta el pedido detenido y el micro de ventas lo encola

**Si el Monitor de la cadena sondea cada etapa y el micro de ventas encola los
pedidos de la etapa que no responde N sondeos seguidos, entonces todo pedido
detenido llegará a la cola de contingencia en ≤ 30 s, porque N sondeos
fallidos caben en ese plazo.**

«Pedido detenido» incluye el que se congela dentro de una etapa que sigue
respondiendo al sondeo. Es el caso que el sondeo quizá no vea, y la fase D3 lo
pone a prueba.

- **Variable independiente:** el sondeo del Monitor y el envío a la cola. El
  Monitor sondea cada T segundos y declara detenida la etapa que no responde N
  sondeos seguidos; el micro de ventas envía a la cola cada pedido pendiente en
  ella.
- **Variables dependientes:** la demora entre la falla y la confirmación del
  pedido en la cola; las falsas alarmas por hora, que ASR-3 limita a una; y los
  pedidos detenidos que no llegan a la cola o que llegan dos veces.

Fundamento: el Monitor nota que una etapa no responde sin depender de ella. El
micro de ventas sabe qué pedidos le entregó a esa etapa y cuáles no han vuelto.
Con eso arma, por cada uno, un mensaje con el pedido, la etapa y el tiempo
transcurrido. Publicar en una cola durable cuesta milisegundos: la reacción no
se come el plazo de la detección, y el mensaje sobrevive aunque nadie lo
atienda todavía.

Lo que la refutaría, cualquiera de dos casos:

- Una etapa que sigue viva y responde al sondeo mientras un pedido se queda
  congelado dentro de ella. ASR-3 describe justo esa falla, sin señal de error.
  En [ADR-004](modelos/adrs-ccp-reto2.md) el equipo predijo que el sondeo no
  la ve, y por eso eligió un plazo por pedido y etapa. El experimento contrasta
  esa predicción con datos.
- Un pedido detectado que no llega a la cola, o que llega dos veces. Un
  duplicado haría que la reanudación de ASR-4 repita una etapa.

El número que no conocemos: el menor N de sondeos sin respuesta que no dispara
falsas alarmas con la variación normal de las etapas. Con un sondeo cada T
segundos, el pedido llega a la cola cerca de N × T segundos después de la
falla. Ese producto tiene que caber en los 30 s que da ASR-3.

## Los escenarios enlazados

En Helix el escenario se enlaza con el botón `Link scenario`. Helix lo nombra con
el atributo y la historia de usuario a la que está atado.

| ASR | Nombre en Helix | Historia | Hipótesis | Cobertura |
|---|---|---|---|---|
| ASR-1 | Security — Inicio de sesión desde el dispositivo suministrado | [HU-01](requirements.md) | H1 | Completa: la detección y el aviso a seguridad, que son toda la respuesta del escenario |
| ASR-3 | Availability — Creación del pedido en la tienda | [HU-03](requirements.md) | H2 | Completa: la detección y la reacción, que es encolar el pedido |

## Las tácticas y los patrones

**Para H1.** La táctica es *detectar intrusiones*, con la huella del
dispositivo como parte de la identidad del vendedor. Es la decisión de
[ADR-007](modelos/adrs-ccp-reto2.md), con la comparación dentro del micro de
sesiones, como la dibuja el diagrama del equipo en la sección del prototipo. El
micro lee la huella registrada de la base en cada apertura, sin caché, y
entrega la sesión que no coincide al componente de usuario no válido.

Ese componente avisa a seguridad, que es la táctica *informar a los actores*.
Matar la sesión y revocar al usuario son
reacciones del área de seguridad, fuera del sistema y fuera del escenario.

**Para H2.** La táctica es *monitor*, la misma que nombra
[ADR-004](modelos/adrs-ccp-reto2.md). El Monitor de la cadena (EL-17 en el
registro de ADR) sondea la salud de cada etapa cada T segundos. Cuando una etapa
no responde N sondeos seguidos, el Monitor avisa al micro de ventas. ADR-004 usa ese
sondeo solo como apoyo del plazo por pedido; aquí es el único mecanismo.

La reacción la hace el micro de ventas, como en el diagrama del equipo. En el
registro de ADR es el Monitor quien encola el pedido señalado (CN-36). El
prototipo lo deja en el micro de ventas porque es quien sabe qué pedidos tiene
pendientes cada etapa.

El micro de ventas toma los suyos en la etapa detenida y envía cada uno a la
cola de contingencia, que es el nodo de contingencia del diagrama. Cada mensaje lleva como clave el pedido, la etapa y
el intento, para que el mismo pedido no entre dos veces. La cola separa la
detección de quien atiende el pedido: reanudarlo o entregarlo a una persona le
toca a ASR-4, y en este prototipo nadie consume la cola.

**Las alternativas contra las que se compara cada hipótesis:**

| Hipótesis | Alternativa | Dónde está | Por qué no entra al prototipo |
|---|---|---|---|
| H1 | Verificar la huella dentro del inicio de sesión, antes de dejar entrar | ADR-007, descartada | El inicio de sesión espera la comparación, y un cambio legítimo sin registrar deja al vendedor por fuera |
| H1 | Revisar por lotes las aperturas de sesión | ADR-007, descartada | Cada segundo del periodo se suma a la demora, y los 2 s no dejan margen |
| H2 | Plazo vencido por pedido y etapa, con una revisión periódica de los plazos | ADR-004 | Es la decisión que el equipo tomó en ADR-004. Si la fase D3, la del pedido congelado en una etapa viva, refuta H2, el diseño vuelve a ella |
| H2 | Temporizador en memoria, uno por pedido | ADR-004, opción C | Los temporizadores mueren si cae el proceso que los guarda |

## El diseño del experimento

### El prototipo

El alcance sale del diagrama del equipo. Lo verde entra al experimento, lo azul
se simula y lo rojo queda fuera.

![Alcance del experimento E01: verde incluido, azul simulado, rojo fuera](assets/experimento-e01-alcance.png)

```mermaid
flowchart LR
    ONB["micro Onboarding<br/>(simulado)"] --> DB[("SIMULADOR-DB<br/>usuario · contraseña<br/>ID de dispositivo")]
    SIM["Simulador de sesiones"] --> SES["micro sesiones"]
    DB --> SES
    SES --> UNV["usuario no válido"]
    UNV --> SMS["SMS de seguridad<br/>(receptor simulado)"]
    SES --> VEN["micro ventas"]
    VEN --> FAC["facturación"]
    VEN --> INV["descargue de inventario"]
    VEN --> DES["validación de despacho"]
    FAC --> LOG["logística"]
    INV --> LOG
    DES --> LOG
    HB["Monitor de la cadena<br/>(Hearbeat en el diagrama del equipo)"] -. sondeo .-> FAC
    HB -. sondeo .-> INV
    HB -. sondeo .-> DES
    HB --> VEN
    VEN -- encola --> NC[["Cola de contingencia<br/>(nodo de contingencia)"]]
    UNV -.-> KILL["matar la sesión"]
    UNV -.-> REV["usuarios revocados"]
    UNV -.-> LOGS["Logs"]
    classDef simulado stroke:#1f6feb,stroke-width:2px
    classDef fuera stroke:#d1242f,stroke-dasharray:4 3,color:#d1242f
    class ONB simulado
    class KILL,REV,LOGS fuera
```

Cinco decisiones de montaje que el diagrama no dice:

- **El inicio de sesión se simula.** El micro Onboarding carga los usuarios y sus
  dispositivos en la base, y el simulador abre las sesiones con esas
  credenciales sin un desafío de autenticación real. El experimento mide lo que
  pasa después del inicio de sesión, no el inicio mismo.
- **La huella es el ID de dispositivo que ya guarda la base.** El simulador
  envía el ID del dispositivo al abrir la sesión. Un dispositivo no registrado
  es uno cuyo ID no coincide con el registrado para ese vendedor. Un cambio
  legítimo de dispositivo se simula registrando el ID nuevo con el micro Onboarding.
- **El SMS de seguridad lo recibe un receptor simulado** que anota la hora de
  llegada de cada aviso. Un proveedor real sumaría su propia demora, que ningún
  componente del diseño controla.
- **El nodo de contingencia es una cola durable** de RabbitMQ, y el micro de
  ventas espera la confirmación del bróker antes de dar el pedido por encolado.
  Un registrador lee la cola sin consumirla y anota la hora de llegada de cada
  mensaje.
- **Las tres etapas corren en paralelo**, como en el diagrama. ADR-003 las ordena
  en serie, pero el orden no cambia lo que H2 evalúa, que es si la parada se
  detecta y el pedido llega a la cola.

### La carga

Toda la carga es la del Ambiente A, fijada en el supuesto S-4 de los
[ASR](quality-attributes.md): 1 pedido y 10 consultas por segundo, con arribo
aleatorio. Cada pedido recorre las tres etapas. Cada etapa
tarda un tiempo aleatorio, para que el sondeo y la detección convivan con la
variación normal de la operación.

Cada corrida empieza con un calentamiento de 5 minutos que no entra en ningún
criterio.

### Las fases

| Fase | Hipótesis | Qué se hace | Duración o repeticiones | Tipo |
|---|---|---|---|---|
| S1 — Sesión desde un dispositivo no registrado | H1 | Se abre una sesión con las credenciales correctas de un vendedor y un ID de dispositivo distinto al registrado, y la sesión opera | 50 aperturas en momentos aleatorios dentro de 30 min de carga normal | Con criterio |
| S2 — Cambio legítimo de dispositivo | H1 | Se registra el dispositivo nuevo de un vendedor, y ese vendedor abre sesión desde él | 100 cambios, para medir la tasa por cada 100 que fija el escenario | Con criterio |
| S3 — Registro y apertura casi simultáneos | H1 | El vendedor abre sesión desde el dispositivo nuevo menos de 1 s después de registrarlo | 20 repeticiones | Con criterio |
| S4 — Rampa de aperturas | H1 | Se sube la tasa de aperturas de sesión a 1, 3 y 5 veces la del Ambiente A, con aperturas desde dispositivos no registrados en cada nivel | 10 min por nivel | Exploratoria |
| D1 — Sin fallas | H2 | Carga normal sin ninguna falla inyectada | 1 h | Con criterio |
| D2 — Etapa caída | H2 | Se detiene el proceso de una etapa con pedidos en curso | 10 veces por etapa, 30 en total | Con criterio |
| D3 — Etapa viva, pedido congelado | H2 | La etapa sigue respondiendo al sondeo, pero un pedido se queda congelado dentro de ella, sin respuesta | 10 veces por etapa, 30 en total | Con criterio: es la fase que puede refutar H2 |
| D4 — Combinaciones de T y N | H2 | Se combina un sondeo cada 1, 2 y 5 s con 1, 2, 3 y 5 sondeos sin respuesta | 12 combinaciones, D1 y D2 en cada una | Exploratoria |

Las cifras de repeticiones y duraciones son una propuesta del equipo; no salen
del enunciado.

### Qué se mide y cómo se cruzan entradas y salidas

Cada operación y cada pedido llevan un identificador desde el simulador hasta el
final del recorrido. Un aviso o un mensaje en la cola cuenta solo cuando se
cruza, uno a uno, con la falla inyectada que lo causó. Contar avisos no basta:
hay que mostrar a qué entrada corresponde cada salida.

| Hipótesis | Reloj de inicio | Reloj de fin | Cruce por identificador |
|---|---|---|---|
| H1 | El micro de sesiones registra la apertura de la sesión | El receptor recibe el aviso | Identificador de la sesión |
| H2 | El inyector detiene la etapa (D2) o congela el pedido (D3) | El bróker confirma el mensaje del pedido en la cola | Identificador del pedido y nombre de la etapa |

Todos los componentes corren en la misma máquina y leen el mismo reloj, así que
medir las diferencias de tiempo no exige sincronizar relojes.

Para H2, un mensaje en la cola es **falsa alarma** cuando nombra un pedido que
llegó a logística o una etapa que nunca se detuvo.

### Los criterios de éxito

**H1 se sostiene si se cumplen las cuatro condiciones:**

- En S1, las 50 aperturas desde un dispositivo no registrado producen su aviso
  en ≤ 2 s, cada uno con el vendedor, el dispositivo y la hora.
- En S2, hay ≤ 1 aviso en los 100 cambios legítimos.
- En S3, ninguna de las 20 aperturas produce aviso.
- En ninguna fase aparece un aviso por una sesión desde el dispositivo
  registrado.

**H2 se sostiene si se cumplen las cuatro condiciones:**

- En D2, los 30 pedidos llegan a la cola en ≤ 30 s, cada uno con el pedido, la
  etapa y el tiempo transcurrido.
- En D1, hay ≤ 1 falsa alarma por hora.
- En D3, los 30 pedidos también llegan a la cola en ≤ 30 s.
- En todas las fases, cada pedido detenido entra a la cola una sola vez: cero
  pedidos perdidos y cero duplicados.

Si D2 y D1 pasan y D3 falla, H2 queda refutada para la falla que describe ASR-3,
aunque el Monitor detecte bien las caídas.

### Limitaciones declaradas

- Una sola máquina y una red local: el experimento valida las ideas de diseño,
  no el tamaño de la infraestructura.
- La reacción ante la sesión sospechosa queda fuera: no se corta la sesión, no
  se revoca al usuario y no se escriben registros (logs). ASR-1 deja esa
  reacción en manos del área de seguridad.
- La huella es un ID que el simulador envía. Quien copie el ID de un dispositivo
  registrado pasa la comparación, el mismo riesgo que el equipo anotó en ADR-007
  (R-007b).
- Solo se inyectan fallas de software, por el supuesto S-3. Las caídas de
  máquina, red o base quedan fuera.
- Nadie consume la cola de contingencia: reanudar el pedido o entregarlo a una
  persona es de ASR-4. La caída del bróker es una falla de infraestructura y
  queda fuera por el mismo supuesto.
- El Monitor de la cadena es un solo proceso. Si cae, nadie detecta nada: es el
  mismo riesgo que el equipo anotó en ADR-004 (R-004a).
- Una hora de D1 solo distingue entre cero, una y varias falsas alarmas.
  Afirmar «una o menos por hora» con confianza pide más horas de corrida.

## Recursos, elementos y esfuerzo

**Required resources.** Todo corre en local, en una sola máquina:

| Pieza | Qué se usa | Para qué |
|---|---|---|
| Micros | Java 21 y Spring Boot 3, un proceso por micro, con Spring Web para las llamadas entre ellos | Que el inyector pueda detener cada etapa por separado |
| Monitor de la cadena | Un micro aparte con una tarea programada (`@Scheduled`) que sondea un punto de salud de cada etapa cada T segundos y cuenta los sondeos sin respuesta | Variar T y N en D4 sin tocar código |
| SIMULADOR-DB | PostgreSQL en Docker Compose | Usuarios, ID de dispositivo registrado y estado de cada pedido por etapa |
| Cola de contingencia | RabbitMQ en Docker Compose, con una cola durable, confirmación de publicación y Spring AMQP | Medir cero pedidos perdidos y cero duplicados |
| Carga | k6, con arribo aleatorio, como en el reto 1 | Reproducir el Ambiente A |
| Inyección | Un inyector que detiene procesos y congela pedidos marcados | Las fases D2 y D3 |
| Medición | Una tabla de tiempos por identificador en PostgreSQL | El cruce de entradas y salidas |

[PREGUNTA] ¿Dónde vive el código del prototipo: en este repositorio o en uno
aparte, como en el reto 1?

**Architecture elements involved.** Incluidos: simulador de sesiones, micro de
sesiones, SIMULADOR-DB, usuario no válido, receptor del SMS de seguridad, micro
de ventas, facturación, descargue de inventario, validación de despacho,
Monitor de la cadena (Hearbeat en el diagrama), logística y cola de contingencia
(nodo de contingencia). Simulado: micro Onboarding. Fuera: matar la sesión,
usuarios revocados y Logs.

**Estimated effort.** [PREGUNTA] ¿Cuántas personas y cuántos días? El trabajo se
divide en cinco frentes:

1. Construir los micros y la base simulada.
2. Construir el generador de carga y el inyector de fallas.
3. Instrumentar los relojes y el cruce por identificador.
4. Correr las ocho fases.
5. Analizar los resultados.

## Resultados y análisis

Los campos `Results`, `Analysis of results` y `Links & evidence` se llenan con
las corridas. Para cada fase, los resultados deben traer:

| Dato | H1 | H2 |
|---|---|---|
| Fallas inyectadas | Aperturas desde dispositivos no registrados, cambios legítimos y aperturas pegadas al registro | Etapas detenidas y pedidos congelados |
| Detectadas | Avisos cruzados con su sesión | Mensajes en la cola cruzados con su pedido y su etapa |
| Escapes | Aperturas desde dispositivos no registrados sin aviso, o con aviso fuera de los 2 s | Pedidos detenidos o congelados que no llegaron a la cola |
| Duplicados | No aplica | Pedidos que entraron a la cola más de una vez |
| Falsas detecciones | Avisos por dispositivos registrados, contados por cada 100 cambios legítimos | Mensajes sobre pedidos que llegaron a logística o sobre etapas que nunca se detuvieron |
| Demora | Mediana, percentil 95 y máximo | Mediana, percentil 95 y máximo |
| Número desconocido | Tasa de aperturas en la que el aviso se atrasa (S4) | Menor N sin falsas alarmas, y N × T (D4) |

En `Links & evidence` van el repositorio del prototipo, el reporte de las
corridas y las salidas crudas de cada fase.

## La decisión que sigue a cada resultado

El equipo fija antes de correr qué decisión toma con cada resultado. Así el
resultado no se acomoda después a la decisión.

| Resultado | Decisión de arquitectura |
|---|---|
| H1 se sostiene en S1, S2 y S3 | Aceptar ADR-007, con la comparación dentro del micro de sesiones |
| H1 falla en S1: hay aperturas sin aviso o con aviso fuera de los 2 s | Sacar la comparación del micro de sesiones a un verificador que consume cada apertura como evento, como lo plantea ADR-007 |
| H1 falla en S2: más de 1 aviso por cada 100 cambios legítimos | Revisar el camino de registro previo del dispositivo nuevo, que ADR-007 dejó sin dueño |
| H1 falla en S3: avisa por dispositivos recién registrados | Revisar primero cuándo ve el micro de sesiones el registro nuevo, antes de tocar otra pieza |
| H1 se atrasa en S4 por debajo de 3 veces la tasa del Ambiente A | Declarar la tasa medida como límite del diseño y llevarla a la decisión sobre cuántas instancias del micro de sesiones correr |
| H2 se sostiene en D1, D2 y D3 | Adoptar el sondeo del Monitor de la cadena como mecanismo de detección de ASR-3, con la cola de contingencia como reacción, y reabrir ADR-004 |
| H2 pasa D1 y D2 pero falla D3 | Confirmar ADR-004: el plazo por pedido y etapa es el mecanismo, y el sondeo del Monitor queda como apoyo para las caídas de etapas enteras |
| H2 falla D2: no detecta ni la etapa caída en ≤ 30 s | Buscar en D4 una combinación de T y N que quepa; si ninguna cabe sin falsas alarmas, adoptar ADR-004 sin el sondeo de apoyo |
| H2 detecta a tiempo pero pierde o duplica pedidos en la cola | Hacer la publicación idempotente con la clave de pedido, etapa e intento (NR-004a), y repetir D2 |
| H2 falla D1: más falsas alarmas de las admitidas | Subir N con el resultado de D4, y verificar que N × T siga cabiendo en los 30 s |
