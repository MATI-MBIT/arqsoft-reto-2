package co.mati.reto2.monitor;

/**
 * La regla de H2 para una etapa: se declara detenida cuando no responde N
 * sondeos seguidos, y se declara recuperada con el primer sondeo que responde.
 * No es segura para hilos: solo la toca el ciclo de sondeo.
 */
final class CuentaDeSondeos {

    enum Cambio { NINGUNO, DECLARADA_DETENIDA, RECUPERADA }

    private final int n;
    private int fallidosSeguidos;
    private boolean detenida;

    CuentaDeSondeos(int n) {
        if (n < 1) {
            throw new IllegalArgumentException("N debe ser al menos 1");
        }
        this.n = n;
    }

    Cambio registrar(boolean respondio) {
        if (respondio) {
            fallidosSeguidos = 0;
            if (detenida) {
                detenida = false;
                return Cambio.RECUPERADA;
            }
            return Cambio.NINGUNO;
        }
        fallidosSeguidos++;
        if (!detenida && fallidosSeguidos >= n) {
            detenida = true;
            return Cambio.DECLARADA_DETENIDA;
        }
        return Cambio.NINGUNO;
    }

    boolean detenida() {
        return detenida;
    }

    int fallidosSeguidos() {
        return fallidosSeguidos;
    }
}
