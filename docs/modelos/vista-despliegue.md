---
title: Vista de despliegue — Reto 2 CCP (v7)
---

# Vista de despliegue — Reto 2 CCP (v7)

Esta página dibuja dónde corre cada componente, con qué tecnología, por qué protocolo se hablan los nodos y qué pieza queda como instancia única. Es un solo diagrama con los dos caminos del reto, porque los dos comparten el bróker y la base. Es la única vista que nombra productos.

**Estado: propuesta.** Los diez ADR de [adrs-ccp-reto2.md](adrs-ccp-reto2.md) están en estado Propuesta. La pila (Java 21 y Spring Boot 3, PostgreSQL, RabbitMQ y Redis) es el supuesto SUP-01 de ese documento: ningún producto viene del enunciado. La portada de los diagramas está en [diagramas-ccp-reto2.md](diagramas-ccp-reto2.md).

**Fuente: draw.io.** El diagrama vive en [vista-despliegue.drawio](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FMATI-MBIT%2Farqsoft-reto-2%2Fmain%2Fdocs%2Fmodelos%2Fdrawio%2Fvista-despliegue.drawio), que se abre en draw.io web ([descargar](drawio/vista-despliegue.drawio)). La imagen de esta página se exporta de ese archivo; un cambio se hace en el draw.io y después se vuelve a exportar.

## Leyenda

| Notación | Significado |
|---|---|
| Cubo «device» | Nodo físico o virtual: un teléfono, un equipo, el balanceador o el nodo de un producto comprado (Redis, RabbitMQ, PostgreSQL) |
| Cubo «executionEnvironment» | Entorno de ejecución; aquí, la JVM 21 que corre cada servicio, o el Docker de la observabilidad |
| Cubo gris «external» | Actor o sistema fuera del alcance que recibe algo del sistema: el Área de seguridad y el Sistema de logística |
| «artifact» (hoja con esquina doblada) | Lo que se despliega en el nodo. Dentro de RabbitMQ son los vhosts con sus temas; dentro de PostgreSQL, los «schema» de cada servicio |
| ×N | Número de instancias que corren a la vez, las mismas de DG-CON-002 y DG-CON-003. ×1 marca una pieza sin réplica. En los dispositivos, ×N o 1..N indica que hay muchos |
| Línea negra continua | «HTTPS»: llamada síncrona, con la operación que invoca |
| Línea azul discontinua | «AMQP»: el servicio publica o consume en el bróker |
| Línea verde continua | «JDBC»: el servicio escribe y lee en su esquema de la base |
| Línea roja continua | «REST»: lectura o escritura en Redis |
| Línea gris punteada | Recolección de métricas desde cada JVM |
| Arco en una línea | Cruce de dos rutas que no se tocan |
| Amarillo | Nodo que aloja una táctica de un ADR |
| Borde punteado | Propuesta sin ADR que la respalde |
| Marco «Red interna de CCP» | Lo que corre dentro de la red de CCP. Los dispositivos, el balanceador y los externos quedan fuera |
| Nota | ADR, riesgo o propuesta anclada al nodo |
| Franja «Por dónde pasa cada ASR» | El recorrido de cada ASR, nodo por nodo, con su medida |

---

## DG-DEP-001 · Dónde corre cada componente y qué queda único

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Despliegue | ASR-1 a ASR-4 | ADR-001 a ADR-010 | propuesta |

![DG-DEP-001 · Despliegue de todo el sistema](png-v7/10-DG-DEP-001.png)

| Nodo | Instancias | Componentes que corren ahí | De dónde sale |
|---|---|---|---|
| Teléfono del vendedor | 1..N | App móvil, que calcula la huella del dispositivo. Lo suministra CCP (R-2, R-11) | contexto · ADR-007 |
| Teléfono del tendero | ×N | App móvil. Es del tendero (R-8, R-11) | contexto |
| Equipo del usuario interno | ×N | Cliente de consulta del perfil de solo consulta (S-8). Es el origen de la escritura indebida | contexto · S-8 |
| Consola del responsable del pedido escalado | ×N | Navegador con el que el Responsable del pedido escalado atiende la Bandeja (HU-14). El diagrama la rotula «soporte de CCP»; ver la [PREGUNTA] de la vista de componentes | **propuesta** |
| Balanceador de carga | ×1 | Termina TLS y reparte las peticiones entre las dos Puertas | **propuesta** |
| Puerta de entrada | ×2 | Puerta de entrada de la API | ADR-009 |
| Gestor de sesión | ×2 | Gestor de sesión | ADR-007 · ADR-009 |
| Verificador de dispositivo | ×2 | Verificador de dispositivo | ADR-007 |
| Notificador a seguridad | ×2 | Notificador a seguridad. La deduplicación por `idAlerta` es **propuesta** | ADR-007 · ADR-010 |
| Detector de escrituras indebidas | ×2 | Detector de escrituras indebidas | ADR-008 |
| Reacción ante acceso indebido | ×2 | Reacción ante acceso indebido | ADR-009 · ADR-010 |
| Pedidos | ×2 | Pedidos, con su relevo del outbox | ADR-008 · ADR-010 |
| Inventario | ×2 | Inventario, con su relevo del outbox. También es la etapa de descargue | ADR-005 · ADR-008 · ADR-010 |
| Facturación | ×2 | Facturación | ADR-005 |
| Validación de despacho | ×2 | Validación de despacho | ADR-005 |
| Coordinador de la cadena | ×1 | Coordinador de la cadena, con su Reanudador | ADR-002 · ADR-003 · ADR-006 |
| Bandeja de pedidos escalados | ×1 | Bandeja de pedidos escalados | ADR-006 |
| Monitor de la cadena | ×1 | Monitor de la cadena. Su esquema propio para `Senal` es **propuesta** | ADR-004 |
| Área de seguridad | — | Externo. Recibe los avisos; el canal está abierto (CN-12) | contexto |
| Sistema de logística | — | Externo. Desencola `pedido.listo` | contexto · S-2 |
| Redis | ×1 | Lista de revocación: claves `jti` e `idActor` que vencen con el token | ADR-009 · SUP-01 |
| RabbitMQ | ×1 | Bróker con dos vhosts. `/seguridad`: `sesion.abierta`, `escritura.realizada`, `alerta.seguridad`. `/cadena`: `etapa.ejecutar`, `etapa.completada`, `cadena.escalada`, `pedido.listo`, `cola.reintentos` y `cola.fallidos`. La separación en vhosts es **propuesta** | ADR-001 · ADR-006 |
| PostgreSQL | ×1 | Base transaccional con un esquema por servicio: `CadenaEtapa` en el del Coordinador, `EtapaProcesada` y el efecto en el de cada etapa, la bitácora y el outbox en los de Pedidos e Inventario, `Reaccion`, `DispositivoRegistrado`, `Senal` y el registro de eventos para medir (R-12) | ADR-001 · ADR-002 · ADR-005 · ADR-008 · ADR-010 |
| Observabilidad | ×1 | Prometheus y Grafana, con las métricas de cada JVM | **propuesta** · R-12 |

Las ×2 de los servicios son las mismas de DG-CON-002 y DG-CON-003; ningún ADR fija ese número. DG-CON-001 dibuja otra política de réplicas por grupo de procesos, que queda en «Diferencias por resolver».

| ID | Táctica (curso) | Nodo | ADR | Precio → cobra a |
|---|---|---|---|---|
| DIS-11 | Réplicas de servicios sin estado en memoria: cualquier instancia atiende | Los diez servicios ×2 · Balanceador delante de las Puertas | **propuesta** | El estado sale a la base, el bróker y la Lista, que quedan ×1 → disponibilidad de esos tres. Dos instancias pueden tomar el mismo trabajo → exige clave única en `Reaccion` (`idEscritura`) y en los avisos (`idAlerta`) |
| SEG-13 | La revocación vive fuera de las instancias de la Puerta, así que alcanza a las dos | Redis | ADR-009 | En el camino de cada petición → disponibilidad del borde (R-1, TO-009a) |
| INT-08 · DIS-15 | Orquestación con estado persistido: el estado sobrevive a la caída del Coordinador porque vive en la base | Coordinador ×1 · PostgreSQL | ADR-002 | Si el Coordinador cae, ninguna cadena avanza hasta que vuelva y nada lo reinicia → ASR-4 (R-002a) |
| DIS-04 · DIS-03 · DIS-01 | Monitor dedicado: barre los plazos vencidos por pedido y etapa, y sondea la salud de las tres etapas | Monitor ×1 · rutas hacia Facturación, Inventario y Validación de despacho · esquema `monitor` (**propuesta**) | ADR-004 | Si el Monitor cae, nadie detecta nada → ASR-3 (R-004a). Pide las vencidas al Coordinador (CN-33), así que queda ciego si este cae, y nadie vigila al Coordinador → ASR-3. Tráfico de sondeo cada 5 s → desempeño |
| DIS-17 · SEG-18 | Cada servicio escribe en su propio esquema; el efecto, la bitácora, el outbox y `EtapaProcesada` van en la misma transacción | PostgreSQL ×1 · doce esquemas | ADR-001 · ADR-005 · ADR-008 | Una o dos filas más por escritura → desempeño. La bitácora vive en la misma base que el actor escribió → SEG-18 se cumple solo en parte |
| MOD-04 · DIS-12 · DIS-14 | Colas durables; lo que la Cola de reintentos no entrega va a `cola.fallidos`, que consume la Bandeja | RabbitMQ · vhost `/cadena` | ADR-001 · ADR-006 | Pieza común de los cuatro caminos (R-001a) |


**Qué muestra:** los servicios sin estado en memoria corren con dos instancias, y todo su estado vive en tres piezas únicas: la base, el bróker y la Lista de revocación. El Coordinador, el Monitor y la Bandeja corren como instancia única. Es el precio que ADR-002 y ADR-004 aceptaron (R-002a, R-004a), y la nota del diagrama lo extiende a la Bandeja. El Sistema de logística aparece como externo que desencola `pedido.listo` por «AMQP», y la ruta «JDBC» del Monitor a su esquema es **propuesta**: ningún conector de los ADR la fija. · **Decisión que refleja:** ADR-001 (bróker y base), ADR-002 (Coordinador ×1), ADR-004 (Monitor ×1 y el sondeo), ADR-005 (la clave única en la base de cada etapa), ADR-006 (la Cola de reintentos y la Bandeja), ADR-008 (el outbox) y ADR-009 (la Lista consultada desde el borde). · **Qué no muestra:** la nube, el orquestador de contenedores y la redundancia de la base, el bróker y la Lista, porque S-3 deja las fallas de infraestructura fuera del alcance.

**Por qué no se dibuja redundancia en el Coordinador ni en el Monitor.** El catálogo del curso pide, para disponibilidad, un despliegue con la redundancia visible. Aquí la redundancia visible es la de los servicios ×2; la de las dos piezas centrales no existe todavía. ADR-004 deja abierta la opción de dos Monitores con un candado en la base (R-004a), y ningún ADR propone un segundo Coordinador. Cuando uno lo decida, este diagrama cambia.

## Diferencias por resolver

El texto de esta página describe el diagrama tal como está dibujado. Estas diferencias quedan abiertas hasta que el equipo decida en el draw.io o en el ADR que corresponda.

| Dónde | Qué dibuja el diagrama | Con qué choca |
|---|---|---|
| DG-DEP-001 | Seguridad ×2 por servicio; Coordinador, Monitor y Bandeja ×1 sin respaldo | DG-CON-001 dibuja seguridad y vigilancia con 1 activo + 1 en espera, el Gestor con N réplicas y la cadena con P réplicas ≤ particiones |
| DG-DEP-001 | El Monitor sondea la salud de Facturación, Inventario y Validación de despacho | DG-CMP-003 y DG-CON-003 sondean solo Facturación y Validación de despacho |
| Rótulos | «estadoy motivo», «dos en epera», «eleccion de lider» | Erratas: «estado y motivo», «dos en espera», «elección de líder» |

