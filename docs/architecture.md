---
title: Problema que resuelve la arquitectura
nav_order: 3
helix_section: "Objective"
---

# Problema que resuelve la arquitectura

CCP es una comercializadora de productos de consumo masivo. Compra a los
fabricantes y almacena; vende a grandes superficies, supermercados,
autoservicios y tiendas de barrio; y entrega en el establecimiento. Opera en
cinco países con un promedio de seis bodegas grandes por país, unas treinta en
total.

El nuevo sistema de CCP promete dos cosas: una cifra de inventario exacta en el
momento de la consulta y un pedido que avanza solo hasta quedar en manos de
logística. Esta arquitectura existe para sostener esas dos promesas en cinco
países y a cualquier hora. También para impedir que un tercero se haga pasar por
el vendedor o el tendero que las usa.

## Enunciado del problema

La venta ocurre en la tienda del cliente, no en una oficina. El vendedor visita,
ofrece y toma el pedido desde el dispositivo móvil que CCP le entregó. El
tendero puede además pedir por su cuenta, sin esperar a que alguien pase. De ahí
en adelante el pedido recorre tres etapas (facturación, descargue de inventario
y validación de despacho) antes de llegar a logística.

Las dos exigencias de calidad que abordan los ASR comparten una necesidad:
**detectar la falla que no se anuncia**. Ninguna de las dos se resuelve atrapando una
excepción, porque en ninguna de las dos hay excepción que atrapar.

Del lado de la seguridad, el atacante entra con credenciales correctas. El
sistema ve un inicio de sesión válido, no un intento fallido. Si la identidad
del vendedor es solo su credencial, no existe señal que lo distinga del tercero
que se la robó. Y el daño no siempre viene de afuera: un actor autenticado con
permiso de consulta puede ejecutar una escritura que nadie autorizó, y el
sistema la registra como legítima porque la sesión lo era.

Del lado de la disponibilidad, la etapa que sigue al pedido no falla: se queda
esperando. El pedido confirmado no pasa a logística, nadie reporta error, y el
vendedor cierra la visita creyendo que todo avanzó. La falla aparece cuando el
tendero llama a preguntar por un pedido que el sistema cree en curso. Repararla
trae sus propios riesgos: volver a correr una etapa que ya se dio por hecha
duplica la factura o el descargue, y demorar el arreglo hace perder tiempo al
cliente y puede costar la venta. Ambos son fallas creadas por el arreglo.

A esto se suma la operación en cinco países y a cualquier hora. No hay ventana
nocturna común donde revisar por lotes lo que pasó durante el día, así que todo
control tiene que correr mientras el sistema atiende.

## Dentro del alcance

**Los atributos de calidad:** disponibilidad 7x24x365 y seguridad frente a la
suplantación y al acceso indebido.

**El ambiente de operación normal (A).** El trabajo se mide con la carga y el
patrón de arribo habituales, no en hora pico ni con infraestructura degradada.

**Las fallas de software.** El equipo acordó tomar en cuenta las fallas de
software. Las de infraestructura —caída de un centro de datos, pérdida de red
entre países— quedan por fuera.

**El camino del pedido hasta logística**, con sus tres etapas, su vigilancia y
su reparación. El transporte posterior no entra.

## Fuera del alcance

**La reacción ante la suplantación.** El sistema llega hasta el aviso al área de
seguridad. Qué hace esa área con el aviso lo ejecuta ella, por fuera del
sistema. Fue un acuerdo del equipo en la reunión del 18 de septiembre, no una
omisión.

**La suplantación del tendero.** El tendero no opera un dispositivo suministrado
por CCP, así que no hay un equipo conocido contra el cual comparar. Queda
anotado como riesgo abierto, con la pregunta de qué señal ocuparía ese lugar.

**La divulgación entre vendedores.** Un vendedor no debe ver las ventas de otro.
Para este alcance se dejó fuera de los cuatro casos que trabaja este reto y
queda anotado como riesgo abierto.

**El área de compras.** El sistema apoya la compra a fabricantes y el
almacenamiento, pero el trabajo de este reto no toca esa área.

**El desempeño.** Fue el atributo del reto 1 y no se vuelve a medir aquí, aunque
la consulta de inventario en tiempo real lo roce.

## Propósito del diseño

Esta arquitectura se diseña para responder una pregunta: **¿cómo se nota una
falla que nadie reporta?**

CCP requiere disponibilidad continua y seguridad frente a la suplantación. El
trabajo de esta arquitectura es convertirlas en condiciones que se puedan
comprobar sobre el sistema construido, y sostenerlas sobre cuatro situaciones
concretas del negocio:

1. Una sesión de vendedor abierta con credenciales correctas desde un equipo que
   CCP no entregó.
2. Una escritura ejecutada por alguien cuyo permiso solo cubría consultar.
3. Una cadena de pedido que se detiene en una de sus tres etapas sin señalar
   error.
4. Un pedido detenido que hay que hacer avanzar sin repetir lo que ya se hizo.

Además, la necesidad exige implementar y medir, no solo diseñar. Toda condición
de prueba debe ir acompañada de un experimento que la produzca, porque una
condición que no se puede reproducir en un experimento no permite comprobar el
sistema construido. Así el diseño y la ejecución son coherentes.

## Preguntas abiertas

`[PREGUNTA]` ¿Cuántos pedidos y consultas por minuto maneja el sistema en
operación normal, sumando los cinco países? Sin esa cifra no hay forma de
describir la carga con números ni de montar una prueba que replique la realidad.

`[PREGUNTA]` ¿Cuánto tiempo pasa entre que el tendero confirma y espera ver su
pedido "en preparación"? Ese número es el techo de todo lo que el sistema puede
tardarse en notar y arreglar una cadena detenida.

`[PREGUNTA]` ¿Cuántos cambios legítimos de dispositivo ocurren por mes en la
fuerza de ventas? De ahí sale si vigilar el equipo del vendedor es una carga
razonable o una fuente constante de avisos inútiles.
