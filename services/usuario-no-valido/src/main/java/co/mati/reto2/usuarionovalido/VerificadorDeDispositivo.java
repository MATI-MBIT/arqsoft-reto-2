package co.mati.reto2.usuarionovalido;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * El Verificador de dispositivo (EL-06, «usuario no válido» en el diagrama del
 * equipo): consume cada sesion.abierta, compara la huella con el dispositivo
 * registrado y, si no coincide, publica alerta.seguridad con el vendedor, el
 * dispositivo y la hora. Es la decisión de ADR-007 tal como la dibuja DG-CMP-004.
 *
 * <p>Lee el dispositivo registrado de la base en cada evento, sin caché, para que
 * un cambio legítimo recién registrado se vea de inmediato (fase S3).
 */
@Component
class VerificadorDeDispositivo {

    private final JdbcTemplate jdbc;
    private final RabbitTemplate bus;
    private final Registro registro;
    private final Timer comparacion;
    private final Counter noCoincide;

    VerificadorDeDispositivo(JdbcTemplate jdbc, RabbitTemplate bus, Registro registro, MeterRegistry metricas) {
        this.jdbc = jdbc;
        this.bus = bus;
        this.registro = registro;
        this.comparacion = Timer.builder("verificador.huella.comparacion").publishPercentileHistogram().register(metricas);
        this.noCoincide = metricas.counter("verificador.huella.no_coincide");
    }

    record SesionAbierta(String sesionId, String vendedorId, String dispositivoId, String abiertaEn) {}

    record AlertaSeguridad(String sesionId, String vendedorId, String dispositivoId, String hora) {}

    static boolean coincide(String registrado, String presentado) {
        return registrado != null && registrado.equals(presentado);
    }

    @RabbitListener(queues = Bus.COLA_VERIFICADOR, concurrency = "4")
    void verificar(SesionAbierta s) {
        Timer.Sample muestra = Timer.start();
        List<String> registrado = jdbc.queryForList(
                "SELECT dispositivo_registrado FROM operacion.vendedor WHERE id = ?", String.class, s.vendedorId());
        boolean ok = !registrado.isEmpty() && coincide(registrado.getFirst(), s.dispositivoId());
        muestra.stop(comparacion);
        registro.sesion("huella.comparada", s.sesionId(), Map.of("coincide", ok));
        if (ok) {
            return;
        }
        noCoincide.increment();
        bus.convertAndSend(Bus.SEGURIDAD, Bus.ALERTA_SEGURIDAD,
                new AlertaSeguridad(s.sesionId(), s.vendedorId(), s.dispositivoId(), s.abiertaEn()));
        registro.anotar(Instant.now(), "aviso.emitido", s.sesionId(), null, null, Map.of("vendedorId", s.vendedorId()));
    }
}
