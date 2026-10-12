-- 2 000 vendedores, cada uno con el dispositivo que CCP le suministró (S-6).
-- La credencial es 'clave-<id>'; el dispositivo registrado, 'D-<id>-1'.

CREATE FUNCTION operacion.sembrar_vendedores() RETURNS void LANGUAGE sql AS $$
    INSERT INTO operacion.vendedor (id, password_hash, dispositivo_registrado)
    SELECT v, encode(sha256(convert_to('clave-' || v, 'UTF8')), 'hex'), 'D-' || v || '-1'
    FROM (SELECT 'V' || lpad(n::text, 4, '0') AS v FROM generate_series(1, 2000) n) s
    ON CONFLICT (id) DO UPDATE
        SET dispositivo_registrado = EXCLUDED.dispositivo_registrado,
            registrado_en = now();
$$;

-- Deja la operación como recién sembrada. El orquestador la llama antes de cada
-- corrida, para que los pedidos detenidos de una no aparezcan como pendientes de
-- la siguiente. El registro de eventos no se toca: es la evidencia.
-- Cada experimento reinicia solo lo suyo, para que E01 y E02 puedan correr a la vez.
CREATE OR REPLACE FUNCTION operacion.reiniciar_e01() RETURNS void LANGUAGE sql AS $$
    TRUNCATE operacion.sesion;
    SELECT operacion.sembrar_vendedores();
$$;

CREATE OR REPLACE FUNCTION operacion.reiniciar_e02() RETURNS void LANGUAGE sql AS $$
    TRUNCATE operacion.pedido, operacion.pedido_etapa, operacion.senal,
             operacion.recibo_etapa, operacion.efecto_etapa;
$$;

CREATE OR REPLACE FUNCTION operacion.reiniciar() RETURNS void LANGUAGE sql AS $$
    SELECT operacion.reiniciar_e01();
    SELECT operacion.reiniciar_e02();
$$;

SELECT operacion.sembrar_vendedores();
