package co.mati.reto2.receptor;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.MeterRegistry;
import java.util.Map;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Component;

/**
 * ROL=auditor-cola. Lee la copia de la Dead-Letter-Queue: el bróker entrega cada
 * pedido.detenido a las dos colas. Así se cuentan perdidos y duplicados sin
 * consumir la Dead-Letter-Queue, que en este prototipo nadie atiende (ASR-4).
 */
@Component
@ConditionalOnProperty(name = "ROL", havingValue = "auditor-cola")
class AuditorDeCola {

    private final Registro registro;
    private final MeterRegistry metricas;

    AuditorDeCola(Registro registro, MeterRegistry metricas) {
        this.registro = registro;
        this.metricas = metricas;
    }

    record PedidoDetenido(String pedidoId, String etapa, int intento) {}

    @RabbitListener(queues = Bus.DLQ_AUDITORIA)
    void leer(PedidoDetenido p, @Header(name = AmqpHeaders.MESSAGE_ID, required = false) String messageId) {
        registro.pedido("mensaje.en.cola", p.pedidoId(), p.etapa(), Map.of(
                "intento", p.intento(), "messageId", String.valueOf(messageId)));
        metricas.counter("auditor.mensajes", "etapa", p.etapa()).increment();
    }
}
