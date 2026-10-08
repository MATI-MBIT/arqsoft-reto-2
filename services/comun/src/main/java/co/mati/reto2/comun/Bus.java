package co.mati.reto2.comun;

import java.util.ArrayList;
import java.util.List;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Declarable;
import org.springframework.amqp.core.Declarables;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * La topología del bróker, en un solo lugar: cada micro la declara al conectarse
 * y RabbitMQ ignora lo que ya existe. Sigue DG-CMP-004 (E01) y DG-CMP-005 (E02).
 *
 * <p>E01, exchange {@code seguridad}: el Gestor de sesión publica
 * {@code sesion.abierta}, el Verificador de dispositivo la consume y publica
 * {@code alerta.seguridad}, y el Notificador a seguridad la entrega.
 *
 * <p>E02, exchange {@code cadena} (el Broker de Eventos de la cadena, T8): el
 * Coordinador (micro de ventas) publica {@code etapa.ejecutar.<etapa>}, cada
 * etapa publica {@code etapa.completada}, el Coordinador publica
 * {@code pedido.listo} para logística y {@code pedido.detenido} para la
 * Dead-Letter-Queue (T11). Esa cola no la consume nadie (ASR-4); su copia de
 * auditoría la lee el auditor para contar perdidos y duplicados.
 *
 * <p>Todas las colas son durables y los mensajes persistentes: el trabajo de una
 * etapa caída espera en su cola y se procesa cuando la etapa vuelve.
 */
@Configuration
public class Bus {

    public static final String SEGURIDAD = "seguridad";
    public static final String SESION_ABIERTA = "sesion.abierta";
    public static final String ALERTA_SEGURIDAD = "alerta.seguridad";
    public static final String COLA_VERIFICADOR = "verificador.sesiones";
    public static final String COLA_NOTIFICADOR = "notificador.alertas";

    public static final String CADENA = "cadena";
    public static final String ETAPA_EJECUTAR = "etapa.ejecutar.";
    public static final String ETAPA_COMPLETADA = "etapa.completada";
    public static final String PEDIDO_LISTO = "pedido.listo";
    public static final String PEDIDO_DETENIDO = "pedido.detenido";
    public static final String COLA_COMPLETADAS = "ventas.completadas";
    public static final String COLA_LOGISTICA = "logistica.pedidos";
    public static final String DEAD_LETTER_QUEUE = "dead-letter-queue";
    public static final String DLQ_AUDITORIA = "dead-letter-queue.auditoria";

    public static final String[] ETAPAS = {"facturacion", "inventario", "despacho"};

    public static String colaEtapa(String etapa) {
        return "etapa." + etapa;
    }

    @Bean
    public MessageConverter conversorJson() {
        // Cada micro declara sus propios registros para los mensajes: el tipo sale
        // del parámetro del listener, no de la clase que usó quien publicó.
        Jackson2JsonMessageConverter conversor = new Jackson2JsonMessageConverter();
        conversor.setAlwaysConvertToInferredType(true);
        return conversor;
    }

    @Bean
    public Declarables topologia() {
        TopicExchange seguridad = new TopicExchange(SEGURIDAD, true, false);
        TopicExchange cadena = new TopicExchange(CADENA, true, false);
        Queue verificador = durable(COLA_VERIFICADOR);
        Queue notificador = durable(COLA_NOTIFICADOR);
        Queue completadas = durable(COLA_COMPLETADAS);
        Queue logistica = durable(COLA_LOGISTICA);
        Queue dlq = durable(DEAD_LETTER_QUEUE);
        Queue auditoria = durable(DLQ_AUDITORIA);

        List<Declarable> todo = new ArrayList<>(List.of(
                seguridad, cadena, verificador, notificador, completadas, logistica, dlq, auditoria,
                enlace(verificador, seguridad, SESION_ABIERTA),
                enlace(notificador, seguridad, ALERTA_SEGURIDAD),
                enlace(completadas, cadena, ETAPA_COMPLETADA),
                enlace(logistica, cadena, PEDIDO_LISTO),
                enlace(dlq, cadena, PEDIDO_DETENIDO),
                enlace(auditoria, cadena, PEDIDO_DETENIDO)));
        for (String etapa : ETAPAS) {
            Queue cola = durable(colaEtapa(etapa));
            todo.add(cola);
            todo.add(enlace(cola, cadena, ETAPA_EJECUTAR + etapa));
        }
        return new Declarables(todo);
    }

    private static Queue durable(String nombre) {
        return QueueBuilder.durable(nombre).build();
    }

    private static Binding enlace(Queue cola, TopicExchange exchange, String clave) {
        return BindingBuilder.bind(cola).to(exchange).with(clave);
    }
}
