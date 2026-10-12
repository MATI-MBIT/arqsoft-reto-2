-- Esquema del prototipo de los experimentos E01 y E02.
-- operacion: el estado que usan los micros. registro: la fuente del veredicto.

CREATE SCHEMA operacion;
CREATE SCHEMA registro;

-- E01 ---------------------------------------------------------------------
CREATE TABLE operacion.vendedor (
    id                     text PRIMARY KEY,
    password_hash          text        NOT NULL,
    dispositivo_registrado text        NOT NULL,
    registrado_en          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE operacion.sesion (
    id             text PRIMARY KEY,
    vendedor_id    text        NOT NULL,
    dispositivo_id text        NOT NULL,
    abierta_en     timestamptz NOT NULL
);

-- E02 ---------------------------------------------------------------------
CREATE TABLE operacion.pedido (
    id            text PRIMARY KEY,
    confirmado_en timestamptz NOT NULL,
    estado        text        NOT NULL          -- EN_CURSO | LISTO
);

-- El estado por pedido y etapa que guarda el Coordinador (EL-16, CN-41).
CREATE TABLE operacion.pedido_etapa (
    pedido_id     text        NOT NULL,
    etapa         text        NOT NULL,         -- facturacion | inventario | despacho
    estado        text        NOT NULL,         -- EN_CURSO | COMPLETADA
    enviado_en    timestamptz NOT NULL,
    completado_en timestamptz,
    PRIMARY KEY (pedido_id, etapa)
);
CREATE INDEX pedido_etapa_pendientes ON operacion.pedido_etapa (etapa) WHERE estado = 'EN_CURSO';

-- La señal del Monitor. La clave primaria es la idempotencia del encolado (NR-004a).
CREATE TABLE operacion.senal (
    pedido_id      text        NOT NULL,
    etapa          text        NOT NULL,
    intento        int         NOT NULL,
    detectada_en   timestamptz NOT NULL,
    confirmada_en  timestamptz,
    PRIMARY KEY (pedido_id, etapa, intento)
);

-- El recibo de cada etapa (ADR-005, receptor idempotente). La etapa lo guarda
-- antes de confirmar el mensaje al bróker: si el mensaje llega otra vez, el
-- recibo dice que ya lo tiene. El punto de salud lee de aquí los pedidos que la
-- etapa aceptó y no ha terminado, aunque el hilo que los trabajaba ya no exista.
CREATE TABLE operacion.recibo_etapa (
    pedido_id     text        NOT NULL,
    etapa         text        NOT NULL,
    estado        text        NOT NULL,         -- EN_CURSO | TERMINADA
    recibido_en   timestamptz NOT NULL,
    terminado_en  timestamptz,
    entregas      int         NOT NULL DEFAULT 1,
    PRIMARY KEY (pedido_id, etapa)
);
CREATE INDEX recibo_etapa_en_curso ON operacion.recibo_etapa (etapa, recibido_en) WHERE estado = 'EN_CURSO';

-- El efecto de la etapa: la factura, el descargue o la validación. Sin clave
-- única a propósito: si la idempotencia falla, el duplicado queda a la vista.
CREATE TABLE operacion.efecto_etapa (
    id          bigserial   PRIMARY KEY,
    pedido_id   text        NOT NULL,
    etapa       text        NOT NULL,
    aplicado_en timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- Registro ----------------------------------------------------------------
CREATE TABLE registro.evento (
    id         bigserial   PRIMARY KEY,
    ts         timestamptz NOT NULL,
    componente text        NOT NULL,
    tipo       text        NOT NULL,
    sesion_id  text,
    pedido_id  text,
    etapa      text,
    datos      jsonb       NOT NULL DEFAULT '{}'
);
CREATE INDEX evento_ts     ON registro.evento (ts);
CREATE INDEX evento_tipo   ON registro.evento (tipo, ts);
CREATE INDEX evento_sesion ON registro.evento (sesion_id) WHERE sesion_id IS NOT NULL;
CREATE INDEX evento_pedido ON registro.evento (pedido_id, etapa) WHERE pedido_id IS NOT NULL;

-- Una fila por corrida. inicio es el fin del calentamiento: lo anterior no entra a ningún criterio.
CREATE TABLE registro.corrida (
    id          text PRIMARY KEY,
    experimento text        NOT NULL,
    fase        text        NOT NULL,
    variables   jsonb       NOT NULL DEFAULT '{}',
    arranque    timestamptz NOT NULL,
    inicio      timestamptz,
    fin         timestamptz,
    -- Falsa si la máquina se congeló durante la corrida (suspensión del equipo u
    -- otra pausa): el orquestador la detecta por un hueco en la carga de fondo.
    valida      boolean     NOT NULL DEFAULT true,
    motivo      text
);
