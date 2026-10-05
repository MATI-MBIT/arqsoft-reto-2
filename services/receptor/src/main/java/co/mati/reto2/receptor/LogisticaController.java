package co.mati.reto2.receptor;

import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * ROL=logistica. Recibe el pedido con las tres etapas cerradas. Lo que llega
 * aquí no puede estar detenido: un mensaje en la cola de reintentos por un
 * pedido que llegó a logística es una falsa alarma.
 */
@RestController
@ConditionalOnProperty(name = "ROL", havingValue = "logistica")
class LogisticaController {

    private final Registro registro;
    private final Counter recibidos;

    LogisticaController(Registro registro, MeterRegistry metricas) {
        this.registro = registro;
        this.recibidos = metricas.counter("logistica.pedidos.recibidos");
    }

    record PedidoListo(String pedidoId) {}

    @PostMapping("/pedidos")
    ResponseEntity<Void> recibir(@RequestBody PedidoListo p) {
        registro.pedido("pedido.en.logistica", p.pedidoId(), null, Map.of());
        recibidos.increment();
        return ResponseEntity.accepted().build();
    }
}
