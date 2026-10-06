---
title: Inicio
layout: home
nav_order: 1
---

# Reto 2 — Disponibilidad y seguridad en el sistema de pedidos de CCP

**Grupo 1** · ARTI4109 Arquitectura de Software · MATI, Universidad de los Andes

| Integrantes |
|---|
| Carlos Chaparro |
| Javier Rodríguez |
| Alexander Reyes |
| Nicolás E Rozo E |

CCP es una comercializadora de productos de consumo masivo que opera en cinco
países, 7x24x365. Su sistema nuevo tiene que reconocer dos situaciones anómalas
que, vistas desde adentro, parecen operación normal. La primera es una sesión de
vendedor abierta con credenciales correctas desde un dispositivo que no es el
que CCP le suministró. La segunda es un pedido que se detuvo en su cadena sin
lanzar ningún error. La cadena son las tres etapas que siguen al pedido
(facturación, descargue de inventario y validación de despacho), y su cierre
habilita a logística.

Este wiki documenta la arquitectura que el grupo 1 diseñó para atender esas dos
situaciones.

## Cómo se recorre

Las páginas siguen el orden en que se construyó la arquitectura. Los insumos
describen el negocio sin proponer soluciones. De ellos salen los escenarios de
calidad, llamados ASR (*architecturally significant requirements*). Las
decisiones y los modelos responden a esos escenarios, y los experimentos ponen a
prueba dos de ellas. Cada página se sostiene sola, así que se puede entrar por
cualquiera. Para buscar un término en todo el sitio, usa `Ctrl` + `K` o `⌘` + `K`.

| Etapa | Página | Qué responde |
|---|---|---|
| Insumo | [Problema que resuelve la arquitectura](architecture.md) | Qué es CCP, qué promete su sistema nuevo y por qué lo difícil es reconocer lo anómalo |
| Insumo | [Stakeholders](stakeholders.md) | Quién usa el sistema, quién recibe sus avisos y quién responde cuando algo se detiene |
| Insumo | [Restricciones](constraints.md) | Lo que la arquitectura hereda y no puede negociar, separado de las hipótesis de solución |
| Insumo | [Historias de usuario](requirements.md) | Qué necesita hacer cada actor, organizado en épicas, capacidades e historias |
| Insumo | [Glosario](glossary.md) | El vocabulario fijado: actores, pedido y las tres etapas que lo siguen |
| Escenarios | [ASRs de disponibilidad y seguridad](quality-attributes.md) | Los cuatro escenarios de calidad, ASR-1 a ASR-4, con su ambiente, su medida y su origen |
| Decisiones | [Registro de ADR](modelos/adrs-ccp-reto2.md) | Las diez decisiones de arquitectura que atienden los cuatro escenarios |
| Modelos | [Diagramas de arquitectura](modelos/diagramas-ccp-reto2.md) | La portada de los diagramas, con la trazabilidad entre ASR, ADR y diagrama |
| Modelos | [Componentes](modelos/vista-componentes.md) · [Concurrencia](modelos/vista-concurrencia.md) · [Información](modelos/vista-informacion.md) · [Despliegue](modelos/vista-despliegue.md) | Las cuatro vistas, con diez diagramas dibujados en draw.io |
| Validación | [Experimentos E01 y E02](experiments.md) | Las dos hipótesis, el montaje común, la carga y cómo se decide cada una |
| Validación | [Resultados de E01 y E02](results.md) | Qué arrojaron las corridas y qué decisión sale de cada experimento |

## Los cuatro escenarios

Dos escenarios son de seguridad y dos de disponibilidad. En cada atributo, uno
pide detectar la situación anómala y el otro pide reaccionar a ella; en
disponibilidad, la reacción es reparar la cadena.

| ASR | Atributo | Qué exige |
|---|---|---|
| ASR-1 | Seguridad · detección | Detectar en ≤ 2 s que una sesión de vendedor la opera un dispositivo distinto del suministrado, y avisar al área de seguridad |
| ASR-2 | Seguridad · reacción | Ante una escritura hecha por un actor con permiso solo de consulta, bloquearlo, cerrar su sesión y revertir la escritura en ≤ 5 s |
| ASR-3 | Disponibilidad · detección | Detectar en ≤ 30 s que la cadena de un pedido confirmado quedó detenida sin señalar error, con ≤ 1 falsa alarma por hora |
| ASR-4 | Disponibilidad · reparación | Reanudar la cadena detenida desde la etapa que falló en ≤ 5 s, sin duplicar factura, descargue ni orden de despacho |

ASR-3 y ASR-4 comparten un presupuesto conjunto de 35 s, desde que la cadena se
detiene hasta que se reanuda.

## Lo que dijeron los experimentos

Las corridas del 4 de octubre de 2026 probaron dos hipótesis por separado, para
que una pudiera caer sin arrastrar a la otra. E01 prueba la decisión que el
equipo propuso para ASR-1. E02 prueba una alternativa más simple a la decisión
propuesta para ASR-3.

**E01, seguridad (ASR-1).** La hipótesis H1 dice que basta con comparar la
huella del dispositivo apenas se abre la sesión, que es lo que propone ADR-007.
El micro de sesiones avisó al área de seguridad en las 50 aperturas desde un
dispositivo distinto del suministrado, con 120 ms en el peor caso, y no dio
falsas alarmas. H1 se sostiene: ADR-007 queda para aceptar.

**E02, disponibilidad (ASR-3).** La hipótesis H2 dice que basta con un Monitor
que consulta de forma periódica la salud de cada etapa. Ese sondeo detectó las
etapas caídas en unos 6 s, pero no vio ninguno de los 30 pedidos congelados
dentro de una etapa viva. Como H2 cae, se confirma ADR-004, que busca los plazos
vencidos por pedido y deja el sondeo solo como apoyo.

El detalle de cada criterio está en [Resultados de E01 y E02](results.md).

## El prototipo

Fuera de este wiki, en el
[repositorio](https://github.com/MATI-MBIT/arqsoft-reto-2), vive el prototipo de
los experimentos: once micros en Java 21 y Spring Boot 3, con PostgreSQL y RabbitMQ en Docker
Compose. `make help` lista los comandos; `make e2e` verifica el montaje y
`make experimentos` corre E01 y E02, unas 4 h 20 min.

## Cómo agregar o cambiar una página

Todo archivo `.md` que llegue a `main` dentro de `docs/` se publica en este
sitio, y el sitio se reconstruye solo. Sin front matter, el título sale del
primer encabezado `#`. Con front matter se controla el título y la posición en
el menú:

```markdown
---
title: Nombre de la página
nav_order: 10
---
```

Este wiki es la fuente de verdad del reto, y Helix, la herramienta del curso,
es una réplica que se carga desde aquí. Un cambio se hace primero en `docs/`.
