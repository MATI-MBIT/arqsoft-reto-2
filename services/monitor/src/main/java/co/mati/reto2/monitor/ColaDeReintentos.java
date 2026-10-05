package co.mati.reto2.monitor;

import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Declarables;
import org.springframework.amqp.core.FanoutExchange;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * La cola de reintentos (EL-24) y su copia. El exchange fanout entrega cada
 * mensaje a las dos colas durables: reintentos, que nadie consume en este
 * prototipo, y reintentos.auditoria, que lee el auditor para contar perdidos y
 * duplicados sin tocar la primera.
 */
@Configuration
class ColaDeReintentos {

    @Bean
    Declarables topologia() {
        FanoutExchange exchange = new FanoutExchange(Encolador.EXCHANGE, true, false);
        Queue reintentos = QueueBuilder.durable("reintentos").build();
        Queue auditoria = QueueBuilder.durable("reintentos.auditoria").build();
        return new Declarables(exchange, reintentos, auditoria,
                BindingBuilder.bind(reintentos).to(exchange),
                BindingBuilder.bind(auditoria).to(exchange));
    }
}
