package co.mati.reto2.comun;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.concurrent.Executors;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/** Clientes HTTP con tiempos de espera explícitos: sin ellos, una etapa congelada cuelga a quien la llama. */
public final class Http {

    private Http() {}

    public static RestClient cliente(String baseUrl, Duration espera) {
        HttpClient http = HttpClient.newBuilder()
                .connectTimeout(espera)
                .executor(Executors.newVirtualThreadPerTaskExecutor())
                .build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(espera);
        return RestClient.builder().baseUrl(baseUrl).requestFactory(fabrica).build();
    }
}
