---
title: Historias de usuario
nav_order: 6
helix_section: "Requirements & Quality"
---

# Historias de usuario

Lo que cada actor necesita hacer con el sistema nuevo de CCP, la
comercializadora de productos de consumo masivo que opera en cinco países. Las
historias salen del enunciado del reto y del diagrama del proceso de ventas.

Se organizan en tres niveles —épica, capacidad e historia— y cada historia se
escribe en tres partes: **como** alguien, **quiero** algo, **para** conseguir un
fin. Esas tres partes dicen quién actúa, qué hace y qué espera obtener.

## El árbol completo

| Épica | Capacidad | Historias |
|---|---|---|
| **E-1** Venta en la tienda | F-1.1 Identidad y sesión del vendedor | HU-01 · HU-08 |
| | F-1.2 Consulta de productos e inventario | HU-02 · HU-04 |
| | F-1.3 Toma del pedido | HU-03 |
| | F-1.4 Ruta de visitas | HU-05 · HU-06 · HU-07 |
| **E-2** Pedido del tendero | F-2.1 Pedido por cuenta propia | HU-09 |
| | F-2.2 Seguimiento del pedido | HU-10 · HU-11 |
| **E-3** Cadena del pedido hasta logística | F-3.1 Cierre de las tres etapas | HU-15 |
| | F-3.2 Atención del pedido detenido | HU-14 |
| **E-4** Protección de la operación | F-4.1 Aviso de sesión sospechosa | HU-12 |
| | F-4.2 Reacción ante el acceso indebido | HU-13 |

## E-1 — Venta en la tienda

El vendedor visita al tendero, le ofrece productos y toma el pedido en el punto
de venta. Todo lo que hace ocurre en la tienda del cliente y desde el
dispositivo que CCP le entregó.

### F-1.1 — Identidad y sesión del vendedor

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-01 | Vendedor | Iniciar sesión desde el dispositivo que CCP me entregó | Que mi identidad no dependa solo de mi contraseña |
| HU-08 | Vendedor | Ver solo mis propias ventas | Que mis cifras no queden a la vista de otro vendedor |

### F-1.2 — Consulta de productos e inventario

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-02 | Vendedor | Consultar un producto y ver su inventario exacto en el momento de la consulta | Ofrecer solo lo que de verdad hay en bodega |
| HU-04 | Vendedor | Que las cantidades del pedido queden reservadas al formalizarlo | Que ningún otro vendedor ofrezca lo que ya comprometí |

### F-1.3 — Toma del pedido

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-03 | Vendedor | Crear el pedido frente al tendero con la disponibilidad confirmada | Cerrar la visita sabiendo que el pedido va en camino |

### F-1.4 — Ruta de visitas

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-05 | Vendedor | Consultar la ruta de visitas del día con los tiempos de desplazamiento | Saber a qué hora llego a cada tienda |
| HU-06 | Vendedor | Recibir un cambio de ruta cuando reordenar las visitas me ahorra tiempo | Visitar más tiendas en la misma jornada |
| HU-07 | Vendedor | Registrar la visita a un cliente | Dejar constancia de que pasé, haya pedido o no |

## E-2 — Pedido del tendero

El tendero pide por su cuenta desde la aplicación, sin esperar a que el vendedor
pase por su tienda, y después le hace seguimiento a lo que pidió.

### F-2.1 — Pedido por cuenta propia

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-09 | Tendero | Hacer mi pedido sin esperar al vendedor | Pedir cuando lo necesito y no cuando pasan por mi tienda |

### F-2.2 — Seguimiento del pedido

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-10 | Tendero | Consultar el estado de un pedido que ya hice | Saber si avanza sin tener que llamar a preguntar |
| HU-11 | Tendero | Seguir el camión que me lleva el pedido | Estar en la tienda cuando llegue |

## E-3 — Cadena del pedido hasta logística

Lo que ocurre después de que el pedido queda confirmado: las tres etapas
—facturación, descargue de inventario y validación de despacho— y lo que pasa
cuando una de ellas se detiene.

### F-3.1 — Cierre de las tres etapas

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-15 | Logística | Recibir el pedido con las tres etapas cerradas una sola vez | Despachar sin tener que verificar si hubo factura o descargue duplicado |

### F-3.2 — Atención del pedido detenido

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-14 | Responsable del pedido escalado | Recibir el pedido que el sistema no pudo hacer avanzar, con la etapa que falta y la razón | Terminarlo o cancelarlo sin reconstruir qué pasó |

## E-4 — Protección de la operación

Las dos situaciones de seguridad que el enunciado exige atender. Ambas tienen
como destinatario al área de seguridad, y se diferencian en el momento: una
avisa, la otra reacciona a algo que ya ocurrió.

### F-4.1 — Aviso de sesión sospechosa

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-12 | Área de seguridad | Recibir aviso cuando una sesión de vendedor se abre desde un dispositivo no suministrado | Actuar mientras la sesión sigue abierta |

### F-4.2 — Reacción ante el acceso indebido

| ID | Como | Quiero | Para |
|---|---|---|---|
| HU-13 | Área de seguridad | Que el sistema bloquee, cierre la sesión y revierta cuando un actor de solo consulta ejecuta una escritura | Que el daño no crezca mientras alguien revisa el aviso |

## Criterios de aceptación

Seis historias cubren el recorrido completo de un pedido y las dos situaciones
de seguridad que el enunciado exige atender. Sus criterios dicen qué tiene que
ocurrir; cuánto puede tardarse todavía no se fija.

### HU-01 — Inicio de sesión desde el dispositivo suministrado

- La sesión queda asociada al dispositivo desde el que se abrió.
- Si el dispositivo no es el registrado para ese vendedor, el sistema marca la
  sesión y avisa al área de seguridad.
- Un cambio legítimo de dispositivo tiene un camino para registrarse sin generar
  aviso.

**Traza:** R-2, que fija que CCP le suministra el dispositivo a cada vendedor.

### HU-03 — Creación del pedido en la tienda

- La disponibilidad que el vendedor ve al crear el pedido es la del momento, no
  la de un cierre anterior.
- Confirmado el pedido, las tres etapas siguientes —facturación, descargue de
  inventario y validación de despacho— avanzan sin intervención.
- El sistema reconoce cuándo una etapa dejó de avanzar aunque no haya señalado
  error.
- Ninguna de las tres etapas produce su efecto dos veces.

**Traza:** R-4, la cifra exacta en tiempo real, y R-5, la reserva al formalizar.

### HU-09 — Pedido del tendero por cuenta propia

- El pedido del tendero recorre las mismas tres etapas que el del vendedor.
- Un pedido detenido se atiende igual, venga de quien venga.
- Ningún pedido detenido se queda sin llegar a logística ni a una persona.

**Traza:** R-8, que fija que el tendero puede pedir sin intermediación.

`[PREGUNTA]` El tendero no opera un dispositivo suministrado por CCP, así que
vigilar el equipo no sirve para protegerlo. Falta definir qué ocupa ese lugar
para detectar la suplantación de un tendero.

### HU-13 — Reacción ante la escritura indebida

- El sistema bloquea al actor, cierra su sesión y revierte la escritura.
- El actor bloqueado no vuelve a escribir.
- La escritura indebida no deja efecto una vez revertida.

**Traza:** R-7, que fija que la información de cada tendero solo la conoce quien
está autorizado.

`[PREGUNTA]` Qué rol del negocio es ese actor de solo consulta. El criterio
describe la reacción sin haber definido a quién se le reacciona.

### HU-14 — Recepción del pedido escalado

- El pedido llega con la etapa pendiente identificada y con el motivo del fallo.
- Las etapas ya completadas no se repiten al terminar el pedido a mano.
- Facturas, descargues y órdenes de despacho duplicados: cero.

**Traza:** S-2, el cierre de las tres etapas habilita a logística.

### HU-15 — Recepción del pedido cerrado en logística

- Logística recibe el pedido solo cuando las tres etapas cerraron.
- El pedido llega con una sola factura, un solo descargue y una sola orden de
  despacho.

**Traza:** S-2 y R-3, la operación repartida en cinco países y treinta bodegas.

## De dónde sale cada historia

Once de las quince salen de una frase del enunciado. Las otras cuatro salen de
la operación que el enunciado describe sin nombrar a quien la ejecuta, y conviene
decirlo para que nadie las lea como alcance inventado.

| Historia | Origen |
|---|---|
| HU-01 a HU-11 | Enunciado del reto |
| HU-12 | R-9 exige impedir la suplantación; el enunciado no dice a quién le llega el aviso |
| HU-13 | R-7 exige que nadie vea lo que no le corresponde; falta quién responde cuando alguien escribe sin poder hacerlo |
| HU-14 | El diagrama del proceso muestra un error en la facturación, pero no dice quién lo atiende |
| HU-15 | El enunciado incluye a logística entre las áreas que el sistema apoya |

## Preguntas abiertas

`[PREGUNTA]` Si HU-05 y HU-06 son una sola historia. El enunciado menciona la
consulta de la ruta y el cambio de ruta en la misma frase, pero optimizar una
ruta es un problema distinto a mostrarla.

`[PREGUNTA]` Si los clientes institucionales —grandes superficies, supermercados
y autoservicios— piden por este mismo canal. El enunciado los nombra como
clientes de CCP, pero describe el módulo de la aplicación para tenderos.

`[PREGUNTA]` Qué prioridad lleva cada historia. El equipo no las ha ordenado, y
sin ese orden no hay forma de decir cuál se construye primero.
