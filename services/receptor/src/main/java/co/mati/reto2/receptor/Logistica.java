package co.mati.reto2.receptor;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.util.Map;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * ROL=logistica. Recibe pedido.listo del bróker de la cadena: el pedido con las
 * tres etapas cerradas. Un pedido que llega aquí poco después de su envío no
 * estuvo detenido: un mensaje suyo en la Dead-Letter-Queue es una falsa alarma.
 */
@Component
@ConditionalOnProperty(name = "ROL", havingValue = "logistica")
class Logistica {

    private final Registro registro;
    private final Counter recibidos;

    Logistica(Registro registro, MeterRegistry metricas) {
        this.registro = registro;
        this.recibidos = metricas.counter("logistica.pedidos.recibidos");
    }

    record PedidoListo(String pedidoId) {}

    @RabbitListener(queues = Bus.COLA_LOGISTICA, concurrency = "2")
    void recibir(PedidoListo p) {
        registro.pedido("pedido.en.logistica", p.pedidoId(), null, Map.of());
        recibidos.increment();
    }
}
