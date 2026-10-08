package co.mati.reto2.ventas;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.MeterRegistry;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * La reacción de H2 (DG-CMP-005): el Monitor le notifica al Coordinador que una
 * etapa cayó, y el Coordinador publica en el bróker (T8) cada pedido que tiene
 * pendiente en ella, con la clave pedido.detenido. El bróker lo deja en la
 * Dead-Letter-Queue (T11), que en este prototipo nadie consume (ASR-4).
 *
 * <p>Cada pedido entra una sola vez: primero se inserta la señal con la clave
 * (pedido, etapa, intento); solo si entra se publica, y el pedido se da por
 * enviado cuando el bróker confirma (NR-004a de ADR-004). Si el bróker no
 * confirma, se borra la señal y el aviso siguiente lo intenta de nuevo.
 */
@RestController
class EnvioALaDeadLetterQueue {

    private static final Logger log = LoggerFactory.getLogger(EnvioALaDeadLetterQueue.class);
    private static final int INTENTO = 1;   // nadie consume la cola: el reintento es de ASR-4
    private static final long ESPERA_CONFIRMACION_MS = 5_000;

    private final JdbcTemplate jdbc;
    private final RabbitTemplate bus;
    private final Registro registro;
    private final MeterRegistry metricas;
    private final ExecutorService trabajo = Executors.newVirtualThreadPerTaskExecutor();
    private final Map<String, AtomicBoolean> enviando = new ConcurrentHashMap<>();

    EnvioALaDeadLetterQueue(JdbcTemplate jdbc, RabbitTemplate bus, Registro registro, MeterRegistry metricas) {
        this.jdbc = jdbc;
        this.bus = bus;
        this.registro = registro;
        this.metricas = metricas;
    }

    record FallaDeEtapa(String etapa) {}

    record PedidoDetenido(String pedidoId, String etapa, int intento, String enviadoEn, String detectadoEn,
                          long transcurridoMs) {}

    /**
     * El aviso del Monitor llega en cada ciclo mientras la etapa siga caída: así
     * también salen los pedidos que ventas le envió después del primer aviso. Si
     * el aviso anterior aún está enviando, este no lanza otro.
     */
    @PostMapping("/fallas/etapa")
    ResponseEntity<Void> etapaCaida(@RequestBody FallaDeEtapa f) {
        AtomicBoolean ocupado = enviando.computeIfAbsent(f.etapa(), e -> new AtomicBoolean());
        if (ocupado.compareAndSet(false, true)) {
            trabajo.submit(() -> {
                try {
                    enviarPendientes(f.etapa());
                } finally {
                    ocupado.set(false);
                }
            });
        }
        return ResponseEntity.accepted().build();
    }

    private void enviarPendientes(String etapa) {
        List<Map<String, Object>> pendientes = jdbc.queryForList("""
                SELECT pedido_id, enviado_en FROM operacion.pedido_etapa
                WHERE etapa = ? AND estado = 'EN_CURSO' ORDER BY enviado_en""", etapa);
        for (Map<String, Object> p : pendientes) {
            enviar((String) p.get("pedido_id"), ((Timestamp) p.get("enviado_en")).toInstant(), etapa);
        }
    }

    private void enviar(String pedidoId, Instant enviadoEn, String etapa) {
        Instant detectado = Instant.now();
        int nueva = jdbc.update("""
                INSERT INTO operacion.senal (pedido_id, etapa, intento, detectada_en) VALUES (?, ?, ?, ?)
                ON CONFLICT DO NOTHING""", pedidoId, etapa, INTENTO, Timestamp.from(detectado));
        if (nueva == 0) {
            return;
        }
        String clave = pedidoId + ":" + etapa + ":" + INTENTO;
        try {
            CorrelationData correlacion = new CorrelationData(clave);
            bus.convertAndSend(Bus.CADENA, Bus.PEDIDO_DETENIDO,
                    new PedidoDetenido(pedidoId, etapa, INTENTO, enviadoEn.toString(), detectado.toString(),
                            Duration.between(enviadoEn, detectado).toMillis()),
                    m -> {
                        m.getMessageProperties().setMessageId(clave);
                        m.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                        return m;
                    },
                    correlacion);
            CorrelationData.Confirm confirmacion =
                    correlacion.getFuture().get(ESPERA_CONFIRMACION_MS, TimeUnit.MILLISECONDS);
            if (!confirmacion.isAck()) {
                throw new IllegalStateException("el bróker rechazó el mensaje: " + confirmacion.getReason());
            }
        } catch (Exception ex) {
            log.warn("sin confirmación para {}, se reintenta en el próximo aviso: {}", clave, ex.getMessage());
            jdbc.update("DELETE FROM operacion.senal WHERE pedido_id = ? AND etapa = ? AND intento = ?",
                    pedidoId, etapa, INTENTO);
            return;
        }
        Instant confirmada = Instant.now();
        jdbc.update("UPDATE operacion.senal SET confirmada_en = ? WHERE pedido_id = ? AND etapa = ? AND intento = ?",
                Timestamp.from(confirmada), pedidoId, etapa, INTENTO);
        // t1 de E02: el bróker confirmó el pedido detenido en la Dead-Letter-Queue.
        registro.anotar(confirmada, "pedido.encolado", null, pedidoId, etapa, Map.of(
                "intento", INTENTO, "transcurridoMs", Duration.between(enviadoEn, confirmada).toMillis()));
        metricas.counter("ventas.pedidos.encolados", "etapa", etapa).increment();
    }
}
