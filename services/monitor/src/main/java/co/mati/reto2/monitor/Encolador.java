package co.mati.reto2.monitor;

import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageBuilder;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * La reacción de H2: pide a ventas los pedidos pendientes en la etapa detenida y
 * envía cada uno a la cola de reintentos (EL-24) una sola vez.
 *
 * <p>Primero inserta la señal con la clave (pedido, etapa, intento); solo si la
 * inserción entra publica el mensaje, y da el pedido por encolado cuando el
 * bróker confirma (NR-004a de ADR-004). Si el bróker no confirma, borra la señal
 * para que el ciclo siguiente lo intente de nuevo: si la confirmación se perdió
 * pero el mensaje llegó, el auditor ve el duplicado y el veredicto lo cuenta.
 */
@Component
class Encolador {

    static final String EXCHANGE = "cadena.reintentos";
    private static final Logger log = LoggerFactory.getLogger(Encolador.class);
    private static final int INTENTO = 1;   // nadie consume la cola: el reintento es de ASR-4
    private static final long ESPERA_CONFIRMACION_MS = 5_000;

    record Pendiente(String pedidoId, Instant enviadoEn) {}

    private final RestClient ventas;
    private final JdbcTemplate jdbc;
    private final RabbitTemplate rabbit;
    private final ObjectMapper json;
    private final Registro registro;
    private final MeterRegistry metricas;

    Encolador(JdbcTemplate jdbc, RabbitTemplate rabbit, ObjectMapper json, Registro registro, MeterRegistry metricas,
              @Value("${VENTAS_URL:http://localhost:8090}") String ventas) {
        this.ventas = Http.cliente(ventas, Duration.ofSeconds(2));
        this.jdbc = jdbc;
        this.rabbit = rabbit;
        this.json = json;
        this.registro = registro;
        this.metricas = metricas;
    }

    void encolarPendientes(String etapa) {
        List<Pendiente> pendientes;
        try {
            pendientes = ventas.get().uri(b -> b.path("/pendientes").queryParam("etapa", etapa).build())
                    .retrieve().body(new ParameterizedTypeReference<>() {});
        } catch (RuntimeException ex) {
            log.warn("ventas no respondió los pendientes de {}: {}", etapa, ex.getMessage());
            return;
        }
        if (pendientes == null) {
            return;
        }
        for (Pendiente p : pendientes) {
            encolar(p, etapa);
        }
    }

    private void encolar(Pendiente p, String etapa) {
        Instant detectada = Instant.now();
        int nueva = jdbc.update("""
                INSERT INTO operacion.senal (pedido_id, etapa, intento, detectada_en) VALUES (?, ?, ?, ?)
                ON CONFLICT DO NOTHING""", p.pedidoId(), etapa, INTENTO, Timestamp.from(detectada));
        if (nueva == 0) {
            return;
        }
        String clave = p.pedidoId() + ":" + etapa + ":" + INTENTO;
        long transcurridoMs = Duration.between(p.enviadoEn(), detectada).toMillis();
        try {
            Message mensaje = MessageBuilder.withBody(json.writeValueAsBytes(Map.of(
                            "pedidoId", p.pedidoId(), "etapa", etapa, "intento", INTENTO,
                            "enviadoEn", p.enviadoEn().toString(), "detectadoEn", detectada.toString(),
                            "transcurridoMs", transcurridoMs)))
                    .setContentType("application/json")
                    .setMessageId(clave)
                    .setDeliveryMode(MessageDeliveryMode.PERSISTENT)
                    .build();
            CorrelationData correlacion = new CorrelationData(clave);
            rabbit.send(EXCHANGE, "", mensaje, correlacion);
            CorrelationData.Confirm confirmacion =
                    correlacion.getFuture().get(ESPERA_CONFIRMACION_MS, TimeUnit.MILLISECONDS);
            if (!confirmacion.isAck()) {
                throw new IllegalStateException("el bróker rechazó el mensaje: " + confirmacion.getReason());
            }
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException(ex);
        } catch (Exception ex) {
            log.warn("sin confirmación para {}, se reintenta en el próximo ciclo: {}", clave, ex.getMessage());
            jdbc.update("DELETE FROM operacion.senal WHERE pedido_id = ? AND etapa = ? AND intento = ?",
                    p.pedidoId(), etapa, INTENTO);
            return;
        }
        Instant confirmada = Instant.now();
        jdbc.update("UPDATE operacion.senal SET confirmada_en = ? WHERE pedido_id = ? AND etapa = ? AND intento = ?",
                Timestamp.from(confirmada), p.pedidoId(), etapa, INTENTO);
        // t1 de E02: el bróker confirmó el mensaje del pedido en la cola.
        registro.anotar(confirmada, "pedido.encolado", null, p.pedidoId(), etapa, Map.of(
                "intento", INTENTO, "transcurridoMs", Duration.between(p.enviadoEn(), confirmada).toMillis()));
        metricas.counter("monitor.pedidos.encolados", "etapa", etapa).increment();
    }
}
