package co.mati.reto2.ventas;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * Micro de ventas en el papel del Coordinador de la cadena (EL-16, T6 en
 * DG-CMP-005): guarda el estado de cada pedido por etapa (CN-41), envía el
 * trabajo a las tres etapas por el bróker y recibe su cierre. No detecta nada:
 * cuando el Monitor le avisa que una etapa cayó, envía sus pedidos pendientes a
 * la Dead-Letter-Queue (ver EnvioALaDeadLetterQueue).
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

    record EtapaCompletada(String pedidoId, String etapa) {}

    @RabbitListener(queues = Bus.COLA_COMPLETADAS, concurrency = "4")
    void completada(EtapaCompletada c) {
        int filas = jdbc.update("""
                UPDATE operacion.pedido_etapa SET estado = 'COMPLETADA', completado_en = now()
                WHERE pedido_id = ? AND etapa = ? AND estado = 'EN_CURSO'""", c.pedidoId(), c.etapa());
        if (filas == 0) {
            return;
        }
        registro.pedido("etapa.completada", c.pedidoId(), c.etapa(), Map.of());
        // Solo uno de los tres cierres encuentra las tres etapas cerradas y cierra el pedido.
        int cerrado = jdbc.update("""
                UPDATE operacion.pedido SET estado = 'LISTO'
                WHERE id = ? AND estado = 'EN_CURSO'
                  AND NOT EXISTS (SELECT 1 FROM operacion.pedido_etapa
                                  WHERE pedido_id = ? AND estado <> 'COMPLETADA')""", c.pedidoId(), c.pedidoId());
        if (cerrado == 1) {
            registro.pedido("pedido.listo", c.pedidoId(), null, Map.of());
            listos.increment();
            despachador.aLogistica(c.pedidoId());
        }
    }
}
