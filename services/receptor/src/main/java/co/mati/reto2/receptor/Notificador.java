package co.mati.reto2.receptor;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Duration;
import java.util.Map;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * ROL=notificador. El Notificador a seguridad (EL-13): consume alerta.seguridad y
 * entrega el aviso al área de seguridad, que en el prototipo es el receptor
 * simulado del SMS (ROL=sms). Un SMS real sumaría la demora del proveedor, que
 * ningún componente del diseño controla.
 */
@Component
@ConditionalOnProperty(name = "ROL", havingValue = "notificador")
class Notificador {

    private final Registro registro;
    private final RestClient receptor;
    private final Counter entregados;

    Notificador(Registro registro, MeterRegistry metricas,
                @Value("${RECEPTOR_SMS_URL:http://localhost:8083}") String receptor) {
        this.registro = registro;
        this.receptor = Http.cliente(receptor, Duration.ofSeconds(2));
        this.entregados = metricas.counter("notificador.avisos.entregados");
    }

    record AlertaSeguridad(String sesionId, String vendedorId, String dispositivoId, String hora) {}

    @RabbitListener(queues = Bus.COLA_NOTIFICADOR, concurrency = "4")
    void notificar(AlertaSeguridad a) {
        registro.sesion("alerta.notificada", a.sesionId(), Map.of());
        receptor.post().uri("/avisos")
                .body(Map.of("sesionId", a.sesionId(), "vendedorId", a.vendedorId(),
                        "dispositivoId", a.dispositivoId(), "hora", a.hora()))
                .retrieve().toBodilessEntity();
        entregados.increment();
    }
}
