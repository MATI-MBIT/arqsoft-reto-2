---
title: Glosario
nav_order: 7
helix_section: "Objective → Glossary"
---

# Glosario

Los términos del negocio de CCP, como los usa este proyecto. Cuando uno de
estos términos aparezca en un requisito, en un escenario de calidad o en un
modelo, significa **esto**, no lo que signifique en otro dominio.

CCP es una comercializadora de productos de consumo masivo que compra a
fabricantes, almacena y vende a grandes superficies, supermercados,
autoservicios y tiendas de barrio en cinco países.

## Actores

**Vendedor.** Empleado de la fuerza de ventas de CCP. Visita tiendas, ofrece
productos y toma pedidos desde el dispositivo móvil que CCP le entregó. No es un
cliente: trabaja para CCP.

**Tendero.** Dueño o encargado de una tienda de barrio, cliente de CCP. Recibe
al vendedor y también puede pedir por su cuenta desde la aplicación. Opera un
dispositivo propio, no uno suministrado.

**Cliente institucional.** Gran superficie, supermercado o autoservicio. El
enunciado los nombra como compradores de CCP junto a las tiendas.

**Área de seguridad.** Equipo de CCP que recibe los avisos de sesión sospechosa
y de escritura indebida, y decide qué hacer con ellos.

## El pedido y su cadena

**Pedido.** La solicitud de productos que un vendedor toma en la tienda o que un
tendero crea por su cuenta. **Se dice pedido, no compra ni orden**: compra es lo
que CCP le hace al fabricante, y orden se presta a confusión con la orden de
despacho.

**Cadena del pedido.** Las tres etapas que un pedido confirmado recorre antes de
llegar a logística. Cada una produce un efecto distinto y ninguna puede
producirlo dos veces.

| Etapa | Qué produce |
|---|---|
| **Facturación** | Una factura o un documento de cobro diferido |
| **Descargue de inventario** | El descuento de las cantidades en la bodega que corresponde |
| **Validación de despacho** | Una orden de despacho validada |

**Cadena detenida.** Un pedido confirmado cuya etapa pendiente dejó de avanzar
sin señalar error. No es un pedido fallido: es un pedido que espera, y esa
diferencia es la que hace difícil detectarlo.

**Escalamiento.** La entrega de un pedido detenido a una persona, con la etapa
pendiente identificada y el motivo del fallo, para que lo termine o lo cancele.

## Despacho, distribución y logística

Tres palabras que el proceso usa para cosas distintas, y conviene no
intercambiarlas.

**Despacho.** La tercera etapa de la cadena. Valida que el pedido se puede
despachar y emite la orden.

**Distribución.** El armado físico del envío en la bodega, una vez las tres
etapas cerraron.

**Logística.** El área que recibe el pedido cuando las tres etapas cierran y se
encarga de llevarlo hasta el establecimiento. Es distinta de despacho: despacho
autoriza, logística transporta.

## Inventario y reserva

**Inventario exacto en tiempo real.** La cifra de existencias en el momento de
la consulta, no la del cierre anterior ni una estimación. El enunciado lo exige
de forma literal.

**Reserva.** El apartado de las cantidades de un pedido formalizado, de modo que
ningún otro vendedor pueda ofrecerlas.

**Bodega.** Centro de almacenamiento de CCP. Hay unas seis por país, treinta en
total, ubicadas en las zonas que pesan en cada mercado.

## Visitas

**Ruta de visitas.** La secuencia de tiendas que un vendedor debe recorrer en un
día, con los tiempos de desplazamiento entre una y otra.

**Visita.** El paso de un vendedor por una tienda, que él registra en la
aplicación haya pedido o no.

## Identidad y acceso

**Dispositivo suministrado.** El equipo móvil que CCP le entrega a cada vendedor.
Este proyecto lo trata como parte de la identidad del vendedor, no como un
accesorio: el equipo desde el que se abre una sesión dice tanto como la
credencial con que se abrió.

**Suplantación.** Que un tercero opere la sesión de un vendedor o de un tendero
haciéndose pasar por él. El sistema ve un inicio de sesión válido, no un intento
fallido.

**Actor de solo consulta.** Un actor autenticado cuyo permiso cubre consultar
—inventario, estado de pedidos— pero no escribir. Qué rol del negocio ocupa ese
lugar está sin definir: `[PREGUNTA]`.

## Convenciones de este proyecto

**Ambiente.** Las condiciones de operación bajo las cuales se describe y se mide
el comportamiento del sistema. Este proyecto distingue tres: normal, pico y
degradado.

**`[PREGUNTA]`.** Marca un dato que el equipo no tiene y que nadie debe inventar.
Sale de la página cuando alguien lo responda, no antes.

## Notación

**7x24x365** para la disponibilidad continua · **≤** para los umbrales · la
coma como separador decimal · **R-1** en adelante para las restricciones ·
**S-1** en adelante para los supuestos · **E-1**, **F-1.1** y **HU-01** para
épicas, capacidades e historias.
