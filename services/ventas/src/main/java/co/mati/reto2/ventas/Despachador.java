package co.mati.reto2.ventas;

import co.mati.reto2.comun.Bus;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

/**
 * Publica el trabajo de las tres etapas y el pedido listo en el bróker de la
 * cadena (T8), como lo dibuja DG-CMP-005. Las etapas corren en paralelo, como en
 * el diagrama del equipo. Si una etapa está caída, su trabajo espera en su cola:
 * ventas no recibe ningún error, el pedido simplemente no vuelve, que es la falla
 * que describe ASR-3.
 */
@Component
class Despachador {

    private final RabbitTemplate bus;

    Despachador(RabbitTemplate bus) {
        this.bus = bus;
    }

    record Trabajo(String pedidoId, String etapa) {}

    record PedidoListo(String pedidoId) {}

    void enviar(String pedidoId) {
        for (String etapa : Etapas.TODAS) {
            bus.convertAndSend(Bus.CADENA, Bus.ETAPA_EJECUTAR + etapa, new Trabajo(pedidoId, etapa));
        }
    }

    void aLogistica(String pedidoId) {
        bus.convertAndSend(Bus.CADENA, Bus.PEDIDO_LISTO, new PedidoListo(pedidoId));
    }
}
