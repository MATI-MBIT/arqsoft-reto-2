---
title: Restricciones
nav_order: 5
helix_section: "Constraints"
---

# Restricciones

Lo que la arquitectura del sistema nuevo de CCP no puede negociar. CCP es una
comercializadora de productos de consumo masivo con operación en cinco países, y
el sistema apoya sus áreas de compras, ventas y logística.

Una restricción es una decisión que ya está tomada y que el diseño hereda. Se
distingue de una hipótesis de solución en que nadie puede revocarla desde la
arquitectura. Esta página separa las dos, porque el diagrama del proceso de
ventas mezcla unas y otras.

La columna **tipo** separa las restricciones de negocio de las de tecnología.
Las que dicen «—» no son del sistema sino del proyecto: acotan el trabajo del
equipo, no el diseño.

## Restricciones del negocio

Vienen del enunciado del reto y de la operación de CCP.

| # | Restricción | Tipo | De dónde sale |
|---|---|---|---|
| R-1 | El sistema opera 7x24x365. Los tenderos de cinco países piden y consultan a cualquier hora, así que no hay ventana de mantenimiento | Negocio | Enunciado |
| R-2 | CCP le suministra el dispositivo móvil a cada vendedor de la fuerza de ventas | Negocio | Enunciado |
| R-3 | La operación cubre cinco países, con un promedio de seis bodegas grandes por país | Negocio | Enunciado |
| R-4 | La consulta de inventario entrega una cifra exacta en tiempo real, no una estimación ni un dato del cierre anterior | Negocio | Enunciado |
| R-5 | Al formalizar un pedido, las cantidades quedan reservadas y ningún otro vendedor puede ofrecerlas | Negocio | Enunciado |
| R-6 | Un vendedor no puede ver las ventas de otro vendedor | Negocio | Enunciado |
| R-7 | La información de cada tendero solo la conoce quien está autorizado | Negocio | Enunciado |
| R-8 | El tendero puede pedir por cuenta propia, sin intermediación de un vendedor | Negocio | Enunciado |
| R-9 | La suplantación de tenderos y vendedores por parte de terceros no puede permitirse | Negocio | Enunciado |

**R-2 es la que más pesa en el diseño.** Es lo que le da al sistema algo contra
qué comparar el equipo desde el que se abre una sesión. Si CCP no entregara el
dispositivo, la identidad del vendedor volvería a ser solo su credencial. La
contrapartida es que cada cambio legítimo de equipo necesita un camino para
registrarse, porque sin él todo teléfono nuevo parece un intruso.

**R-1 cierra la puerta a la revisión por lotes.** Sin noche común a cinco
países, ningún control puede esperar al cierre del día: todo tiene que correr
mientras el sistema atiende.

## Restricciones de tecnología

| # | Restricción | Tipo | De dónde sale |
|---|---|---|---|
| R-10 | La cara visible del sistema es una aplicación móvil, tanto para el vendedor como para el tendero | Tecnología | Enunciado |
| R-11 | El vendedor opera sobre el dispositivo que CCP le entregó; el tendero, sobre el suyo | Tecnología | Enunciado |

**R-11 parte el problema de identidad en dos.** El vendedor tiene un equipo
conocido contra el cual comparar; el tendero no. Esa asimetría no la resuelve el
diseño: viene dada por cómo CCP reparte los equipos.

El enunciado no menciona lenguaje, motor de base de datos, nube ni proveedor.
`[PREGUNTA]` Si existe algún sistema heredado, contrato con terceros o exigencia
regulatoria por país que condicione el diseño.

## Restricciones del proyecto

Acotan el trabajo del equipo, no el diseño del sistema. Se registran aquí
porque el alcance de lo que hay que entregar depende de ellas.

| # | Restricción | Tipo | De dónde sale |
|---|---|---|---|
| R-12 | No basta diseñar: hay que implementar las decisiones de arquitectura y medir que los requisitos de calidad se cumplen | — | Objetivo del enunciado |
| R-13 | El alcance son cuatro situaciones de calidad, dos de seguridad y dos de disponibilidad, en el ambiente de operación normal | — | Acuerdo del equipo |
| R-14 | La arquitectura se entrega en Helix, la herramienta de modelado del curso | — | Curso ARTI4109 |

R-12 tiene una consecuencia que suele pasarse por alto: cada condición que el
diseño se imponga necesita un experimento que la produzca. Una condición que no
se puede correr no sirve, por bien redactada que esté.

## Supuestos del equipo

No son restricciones: son decisiones que el equipo tomó y que puede revisar. Se
listan porque el diseño ya se apoya en ellas.

| # | Supuesto | Estado |
|---|---|---|
| S-1 | El proceso espera a que las tres etapas que siguen al pedido confirmado —facturación, descargue de inventario y validación de despacho— terminen antes de continuar | Acordado en la reunión del 18 de septiembre |
| S-2 | El cierre de las tres etapas es lo que habilita a logística | Acordado en la misma reunión |
| S-3 | El alcance cubre solo fallas de software. Las de infraestructura quedan fuera | Acordado |

## Qué del diagrama de ventas no es una restricción

El diagrama del proceso de ventas muestra elementos que parecen dados y no lo
son. Son hipótesis de solución, y el método de diseño que sigue el curso
—ADD, *attribute-driven design*— las confirmará o las cambiará:

- El latido de vigilancia sobre las tres etapas (*heartbeat* en el diagrama, con
  la pregunta *¿Is alive?* sobre cada una)
- **Que las tres etapas corran en paralelo** tras el pago y se unan antes de la
  distribución. El diagrama las dibuja así, pero que sean paralelas o
  consecutivas es una decisión de diseño, no un hecho del negocio
- La cola con dos reintentos
- La réplica de lectura del inventario frente al maestro
- El acceso a la base de datos por JDBC —la interfaz estándar de Java para
  hablar con un motor relacional—, separando lectura y escritura
- El gestor de sesión como componente donde se detecta la suplantación
- El archivo de registros como evidencia contra la manipulación

Tratarlas como restricciones congelaría el diseño antes de empezar, y esa
omisión es deliberada.

## Restricciones cuantitativas pendientes

Sin estos números, las condiciones del sistema quedan sin cuantificar y las
pruebas no replican la operación real.

`[PREGUNTA]` Cuántos pedidos y consultas por minuto en operación normal, sumando
los cinco países.

`[PREGUNTA]` Qué factor multiplica esa carga en hora pico, y cuánto dura la
ráfaga.

`[PREGUNTA]` Cuántos cambios legítimos de dispositivo ocurren por mes en la
fuerza de ventas.

`[PREGUNTA]` Cuánto espera el tendero entre que confirma y ve su pedido "en
preparación". Ese número acota todo lo que el sistema puede tardarse en notar y
arreglar una cadena detenida.
