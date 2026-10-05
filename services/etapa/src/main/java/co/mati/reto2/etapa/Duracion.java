package co.mati.reto2.etapa;

import java.util.concurrent.ThreadLocalRandom;

/**
 * Duración de la etapa, lognormal (supuesto S-11). Con mediana de 2 s y sigma
 * 0,5, el p99,9 queda cerca de 9,4 s: variación normal que el Monitor tiene que
 * tolerar sin falsas alarmas, y por debajo de los 25 s de SUP-03.
 */
final class Duracion {

    private static final long TOPE_MS = 25_000;

    private final long medianaMs;
    private final double sigma;

    Duracion(long medianaMs, double sigma) {
        this.medianaMs = medianaMs;
        this.sigma = sigma;
    }

    long siguienteMs() {
        double z = ThreadLocalRandom.current().nextGaussian();
        return Math.min(TOPE_MS, Math.round(medianaMs * Math.exp(sigma * z)));
    }
}
