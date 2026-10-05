package co.mati.reto2.receptor;

import co.mati.reto2.comun.Registro;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import java.io.IOException;
import java.util.Map;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.ExchangeTypes;
import org.springframework.amqp.rabbit.annotation.Exchange;
import org.springframework.amqp.rabbit.annotation.Queue;
import org.springframework.amqp.rabbit.annotation.QueueBinding;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * ROL=auditor-cola. Lee la copia de la cola de reintentos que el exchange fanout
 * deja en reintentos.auditoria. Así se cuentan perdidos y duplicados sin
 * consumir la cola de reintentos, que en este prototipo nadie atiende (ASR-4).
 */
@Component
@ConditionalOnProperty(name = "ROL", havingValue = "auditor-cola")
class AuditorDeCola {

    private final Registro registro;
    private final ObjectMapper json;
    private final MeterRegistry metricas;

    AuditorDeCola(Registro registro, ObjectMapper json, MeterRegistry metricas) {
        this.registro = registro;
        this.json = json;
        this.metricas = metricas;
    }

    @RabbitListener(bindings = @QueueBinding(
            value = @Queue(name = "reintentos.auditoria", durable = "true"),
            exchange = @Exchange(name = "cadena.reintentos", type = ExchangeTypes.FANOUT)))
    void leer(Message mensaje) throws IOException {
        JsonNode m = json.readTree(mensaje.getBody());
        String etapa = m.path("etapa").asText();
        registro.pedido("mensaje.en.cola", m.path("pedidoId").asText(), etapa, Map.of(
                "intento", m.path("intento").asInt(),
                "messageId", String.valueOf(mensaje.getMessageProperties().getMessageId())));
        metricas.counter("auditor.mensajes", "etapa", etapa).increment();
    }
}
