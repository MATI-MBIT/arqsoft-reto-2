package co.mati.reto2.ventas;

import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Micro de ventas en el papel del Coordinador de la cadena (EL-16): guarda el
 * estado de cada pedido por etapa (CN-41), envía el trabajo a las tres etapas y
 * le dice al Monitor qué pedidos tiene pendientes en cada una. No detecta ni
 * encola nada: eso es del Monitor (CN-36).
 */
@RestController
class PedidoController {

    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final Registro registro;
    private final Despachador despachador;
    private final Counter confirmados;
    private final Counter listos;

    PedidoController(JdbcTemplate jdbc, TransactionTemplate tx, Registro registro, Despachador despachador,
                     MeterRegistry metricas) {
        this.jdbc = jdbc;
        this.tx = tx;
        this.registro = registro;
        this.despachador = despachador;
        this.confirmados = metricas.counter("ventas.pedidos.confirmados");
        this.listos = metricas.counter("ventas.pedidos.listos");
    }

    record NuevoPedido(String pedidoId) {}

    record Pendiente(String pedidoId, Instant enviadoEn) {}

    @PostMapping("/pedidos")
    ResponseEntity<Map<String, String>> confirmar(@RequestBody NuevoPedido p) {
        Instant ahora = Instant.now();
        Timestamp ts = Timestamp.from(ahora);
        tx.executeWithoutResult(s -> {
            jdbc.update("INSERT INTO operacion.pedido (id, confirmado_en, estado) VALUES (?, ?, 'EN_CURSO')",
                    p.pedidoId(), ts);
            jdbc.batchUpdate("""
                    INSERT INTO operacion.pedido_etapa (pedido_id, etapa, estado, enviado_en)
                    VALUES (?, ?, 'EN_CURSO', ?)""", Etapas.TODAS, Etapas.TODAS.size(), (ps, etapa) -> {
                ps.setString(1, p.pedidoId());
                ps.setString(2, etapa);
                ps.setTimestamp(3, ts);
            });
        });
        registro.anotar(ahora, "pedido.confirmado", null, p.pedidoId(), null, Map.of());
        confirmados.increment();
        despachador.enviar(p.pedidoId());
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("pedidoId", p.pedidoId()));
    }

    @GetMapping("/pedidos/{pedidoId}")
    ResponseEntity<Map<String, Object>> consultar(@PathVariable String pedidoId) {
        List<Map<String, Object>> filas = jdbc.queryForList(
                "SELECT etapa, estado FROM operacion.pedido_etapa WHERE pedido_id = ?", pedidoId);
        if (filas.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of("pedidoId", pedidoId, "etapas", filas));
    }

    @PostMapping("/pedidos/{pedidoId}/etapas/{etapa}/completada")
    ResponseEntity<Void> completada(@PathVariable String pedidoId, @PathVariable String etapa) {
        int filas = jdbc.update("""
                UPDATE operacion.pedido_etapa SET estado = 'COMPLETADA', completado_en = now()
                WHERE pedido_id = ? AND etapa = ? AND estado = 'EN_CURSO'""", pedidoId, etapa);
        if (filas == 0) {
            return ResponseEntity.ok().build();
        }
        registro.pedido("etapa.completada", pedidoId, etapa, Map.of());
        // Solo una de las tres respuestas encuentra las tres etapas cerradas y cierra el pedido.
        int cerrado = jdbc.update("""
                UPDATE operacion.pedido SET estado = 'LISTO'
                WHERE id = ? AND estado = 'EN_CURSO'
                  AND NOT EXISTS (SELECT 1 FROM operacion.pedido_etapa
                                  WHERE pedido_id = ? AND estado <> 'COMPLETADA')""", pedidoId, pedidoId);
        if (cerrado == 1) {
            registro.pedido("pedido.listo", pedidoId, null, Map.of());
            listos.increment();
            despachador.aLogistica(pedidoId);
        }
        return ResponseEntity.ok().build();
    }

    /** Lo que el Monitor le pregunta cuando declara detenida una etapa. */
    @GetMapping("/pendientes")
    List<Pendiente> pendientes(@RequestParam String etapa) {
        return jdbc.query("""
                SELECT pedido_id, enviado_en FROM operacion.pedido_etapa
                WHERE etapa = ? AND estado = 'EN_CURSO' ORDER BY enviado_en""",
                (rs, i) -> new Pendiente(rs.getString(1), rs.getTimestamp(2).toInstant()), etapa);
    }
}
