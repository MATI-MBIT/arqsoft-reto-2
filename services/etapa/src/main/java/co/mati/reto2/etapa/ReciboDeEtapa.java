package co.mati.reto2.etapa;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * El receptor idempotente de la etapa (ADR-005). Cada pedido deja un recibo con
 * la clave (pedido, etapa) antes de que el mensaje se confirme al bróker, y el
 * efecto de la etapa se aplica en la misma transacción que marca el recibo como
 * terminado, solo si seguía en curso. Así, un pedido que llega dos veces aplica
 * su efecto una sola vez.
 *
 * <p>El mismo recibo es lo que lee el punto de salud: los pedidos que la etapa
 * aceptó y no ha terminado, aunque el hilo que los trabajaba ya no exista.
 */
@Component
class ReciboDeEtapa {

    /** Lo que encontró el recibo al llegar el pedido. */
    enum Llegada {
        /** Primera entrega: hay que trabajarlo. */
        NUEVO,
        /** Ya estaba en curso: el intento anterior murió (el bróker lo devolvió). Se retoma. */
        RETOMADO,
        /** Ya estaba terminado: entrega repetida. No se repite el efecto. */
        REPETIDO
    }

    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    ReciboDeEtapa(JdbcTemplate jdbc, TransactionTemplate tx) {
        this.jdbc = jdbc;
        this.tx = tx;
    }

    /**
     * Guarda el recibo o cuenta la entrega repetida. Un pedido retomado vuelve a
     * contar su edad desde ahora: es un intento nuevo, no uno atascado.
     */
    Llegada recibir(String pedidoId, String etapa) {
        Map<String, Object> fila = jdbc.queryForMap("""
                INSERT INTO operacion.recibo_etapa (pedido_id, etapa, estado, recibido_en)
                VALUES (?, ?, 'EN_CURSO', clock_timestamp())
                ON CONFLICT (pedido_id, etapa) DO UPDATE
                   SET entregas = recibo_etapa.entregas + 1,
                       recibido_en = CASE WHEN recibo_etapa.estado = 'EN_CURSO'
                                          THEN clock_timestamp() ELSE recibo_etapa.recibido_en END
                RETURNING estado, (xmax = 0) AS nuevo""", pedidoId, etapa);
        if (Boolean.TRUE.equals(fila.get("nuevo"))) {
            return Llegada.NUEVO;
        }
        return "TERMINADA".equals(fila.get("estado")) ? Llegada.REPETIDO : Llegada.RETOMADO;
    }

    /**
     * Cierra el recibo y aplica el efecto en una sola transacción. Devuelve false
     * si otro intento ya lo había cerrado: entonces el efecto no se aplica.
     */
    boolean terminar(String pedidoId, String etapa) {
        return Boolean.TRUE.equals(tx.execute(s -> {
            int cerrado = jdbc.update("""
                    UPDATE operacion.recibo_etapa SET estado = 'TERMINADA', terminado_en = clock_timestamp()
                    WHERE pedido_id = ? AND etapa = ? AND estado = 'EN_CURSO'""", pedidoId, etapa);
            if (cerrado == 0) {
                return false;
            }
            jdbc.update("INSERT INTO operacion.efecto_etapa (pedido_id, etapa) VALUES (?, ?)", pedidoId, etapa);
            return true;
        }));
    }

    /** Los pedidos en curso de la etapa, del más viejo al más nuevo, con su edad en ms. */
    List<Map<String, Object>> enCurso(String etapa) {
        return jdbc.queryForList("""
                SELECT pedido_id AS "pedidoId",
                       round(extract(epoch FROM clock_timestamp() - recibido_en) * 1000)::bigint AS "edadMs"
                FROM operacion.recibo_etapa
                WHERE etapa = ? AND estado = 'EN_CURSO'
                ORDER BY recibido_en""", etapa);
    }
}
