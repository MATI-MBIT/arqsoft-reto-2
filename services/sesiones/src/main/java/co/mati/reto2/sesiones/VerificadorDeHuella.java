package co.mati.reto2.sesiones;

import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * H1: compara la huella del dispositivo apenas se abre la sesión, sin bloquear la
 * apertura (ADR-007). Lee el dispositivo registrado de la base en cada apertura,
 * sin caché, para que un cambio legítimo recién registrado se vea de inmediato
 * (fase S3).
 */
@Component
class VerificadorDeHuella {

    private static final Logger log = LoggerFactory.getLogger(VerificadorDeHuella.class);

    private final JdbcTemplate jdbc;
    private final Registro registro;
    private final RestClient usuarioNoValido;
    private final ExecutorService ejecutor = Executors.newVirtualThreadPerTaskExecutor();
    private final Timer comparacion;
    private final Counter noCoincide;

    VerificadorDeHuella(JdbcTemplate jdbc, Registro registro, MeterRegistry metricas,
                        @Value("${USUARIO_NO_VALIDO_URL:http://localhost:8082}") String url) {
        this.jdbc = jdbc;
        this.registro = registro;
        this.usuarioNoValido = Http.cliente(url, Duration.ofSeconds(2));
        this.comparacion = Timer.builder("sesiones.huella.comparacion").publishPercentileHistogram().register(metricas);
        this.noCoincide = metricas.counter("sesiones.huella.no_coincide");
    }

    void verificarDespues(SesionAbierta s) {
        ejecutor.submit(() -> verificar(s));
    }

    static boolean coincide(String registrado, String presentado) {
        return registrado != null && registrado.equals(presentado);
    }

    private void verificar(SesionAbierta s) {
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
        try {
            usuarioNoValido.post().uri("/sospechas")
                    .body(Map.of("sesionId", s.sesionId(), "vendedorId", s.vendedorId(),
                            "dispositivoId", s.dispositivoId(), "abiertaEn", s.abiertaEn().toString()))
                    .retrieve().toBodilessEntity();
        } catch (RuntimeException ex) {
            log.warn("no se pudo entregar la sospecha de {}: {}", s.sesionId(), ex.getMessage());
        }
    }
}
