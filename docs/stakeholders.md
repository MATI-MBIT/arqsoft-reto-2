---
title: Stakeholders
nav_order: 4
helix_section: "Stakeholders"
---

# Stakeholders

Quiénes usan el sistema nuevo de CCP, quiénes reciben sus avisos y quiénes
responden cuando algo se detiene. CCP es una comercializadora de productos de
consumo masivo con operación en cinco países, y el sistema apoya sus áreas de
compras, ventas y logística.

Cada stakeholder se describe con tres datos: **nombre**, **rol** y
**descripción**. La descripción dice qué hace con el sistema y qué espera de él.

## Quiénes operan el sistema

| Nombre | Rol | Descripción |
|---|---|---|
| **Vendedor** | Usuario de la fuerza de ventas | Consulta inventario, registra visitas y crea pedidos desde el dispositivo que CCP le suministró. Espera que la cifra de inventario sea exacta cuando la mira y que el pedido que tomó no se quede en el camino |
| **Tendero** | Cliente que opera la aplicación | Pide por cuenta propia, consulta el estado de su pedido y sigue el camión que se lo lleva. Espera que su pedido avance sin tener que llamar, y que nadie más vea lo que compra |
| **Área de seguridad** | Receptor de los avisos de seguridad | Recibe los avisos de sesión sospechosa y de escritura indebida, y decide qué hacer con ellos. Espera identidad, dispositivo y hora en cada aviso, a tiempo para actuar mientras la sesión sigue abierta |
| **Responsable del pedido escalado** | Operador del escalamiento | Termina o cancela a mano el pedido que el sistema no logró hacer avanzar. Espera el estado exacto: qué etapa falta y por qué |
| **Logística** | Área que recibe el pedido cerrado | Recibe el pedido cuando las tres etapas cierran y lo lleva al establecimiento. Espera que lo que le llega esté facturado, descargado y validado una sola vez |
| **Facturación** | Área dueña de la primera etapa | Emite la factura o el documento de cobro diferido del pedido confirmado. Nota primero cuando la cadena se detiene en su etapa |
| **Inventario** | Área dueña de la segunda etapa | Descuenta las cantidades del pedido en la bodega que corresponde. Espera que ningún descargue se aplique dos veces |
| **Despacho** | Área dueña de la tercera etapa | Valida que el pedido se puede despachar y emite la orden que habilita a logística |

## Por qué cada uno está en la lista

**Vendedor.** Trabaja en la tienda del cliente, no en una oficina, y su
dispositivo es el que CCP le entregó. Ese hecho cambia qué significa
identificarlo: el equipo suministrado forma parte de quién es, no solo su
contraseña. De ahí se sigue que todo cambio legítimo de equipo necesita un
camino para registrarse, porque sin él cada teléfono nuevo parece un intruso.

**Tendero.** Entra por el módulo que le permite pedir sin vendedor. El enunciado
es explícito en que su información no puede ser conocida por quien no está
autorizado. A diferencia del vendedor, no opera un dispositivo suministrado, y
esa asimetría deja su identidad sin un equipo conocido contra el cual
compararla.

**Área de seguridad.** Es el destinatario de los avisos de seguridad y quien
decide qué hacer con ellos. El equipo acordó que la reacción ante la
suplantación la ejecuta esta área por fuera del sistema, así que el aviso es el
producto que recibe, no un trámite intermedio.

**Responsable del pedido escalado.** Aparece solo cuando el sistema no logra
hacer avanzar el pedido por su cuenta. Su valor está en lo que recibe: no un
pedido "con error", sino la etapa exacta que falta y la razón. Sin ese detalle,
el escalamiento traslada el problema en vez de resolverlo.

**Facturación, inventario y despacho.** Son áreas del negocio antes que
componentes de software, y cada una tiene dueño. Ese dueño es quien nota primero
cuando la cadena se detiene en su etapa, y quien sufre el efecto duplicado si la
reparación sale mal. Por eso entran como stakeholders y no solo como pasos de un
proceso.

| Área | Etapa | Efecto que produce |
|---|---|---|
| **Facturación** | Primera | Factura o documento de cobro diferido |
| **Inventario** | Segunda | Descargue en la bodega que corresponde |
| **Despacho** | Tercera | Orden de despacho validada, que habilita a logística |

Ninguno de esos tres efectos puede producirse dos veces. Una segunda factura o
un segundo descargue no son un reintento fallido: son una falla nueva, creada
por la reparación.

**Logística.** Cierra la cadena y es la prueba de que funcionó. Un pedido que nunca le llega es exactamente lo que el sistema existe
para evitar. Es distinta de despacho: despacho autoriza, logística transporta.

## Quiénes quedan fuera de la lista

**Fabricantes.** Proveedores de CCP. El sistema apoya la compra que CCP les
hace, pero ellos no lo operan.

**Conductor del camión.** El tendero le hace seguimiento a su camión, así que el
sistema conoce su posición. `[PREGUNTA]` Falta definir si el conductor opera el
sistema o solo es observado por él.

**Clientes institucionales.** El enunciado nombra a las grandes superficies,
supermercados y autoservicios como clientes de CCP junto a las tiendas, pero
describe el módulo de la aplicación para tenderos. `[PREGUNTA]` Falta definir si
piden por el mismo canal o por otro.

**El profesor y el equipo de arquitectura.** Son stakeholders del proyecto, no
del sistema. Esta página lista solo los segundos.

## Preguntas abiertas

`[PREGUNTA]` Qué rol del negocio ocupa el actor cuyo permiso cubre solo
consultar. El enunciado exige que nadie vea lo que no le corresponde, pero no
dice quién es ese alguien en el dominio: un vendedor con permiso recortado, un
tendero, un tercero interno. Sin eso el stakeholder no se puede nombrar.

`[PREGUNTA]` A qué área pertenece el responsable del pedido escalado. En la
reunión se habló de soporte, pero eso fue una hipótesis de solución, no una
decisión.
