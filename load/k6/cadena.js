// Carga de fondo del Ambiente A (S-4): 1 pedido y 10 consultas por segundo
// contra ventas, durante toda la corrida de E01 o E02.
//
// Un solo escenario a 11 llegadas por segundo: cada llegada es pedido con
// probabilidad 1/11 y consulta en el resto. El sorteo hace aleatorio el arribo
// de los dos tipos sin perder la tasa media. Las consultas preguntan por
// pedidos que este mismo VU creó.
//
// Uso: k6 run -e CORRIDA=<id> -e DURACION=2h cadena.js
import http from 'k6/http';
import { check } from 'k6';
import exec from 'k6/execution';
import { CORRIDA, VENTAS, postJson } from './comun.js';

const PEDIDOS_S = Number(__ENV.PEDIDOS_S || 1);
const CONSULTAS_S = Number(__ENV.CONSULTAS_S || 10);
const TASA = PEDIDOS_S + CONSULTAS_S;

export const options = {
  scenarios: {
    ambiente_a: {
      executor: 'constant-arrival-rate',
      rate: TASA,
      timeUnit: '1s',
      duration: __ENV.DURACION || '24h',
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
  },
  summaryTrendStats: ['med', 'p(95)', 'p(99)', 'max'],
};

const propios = [];
let n = 0;

export default function () {
  if (propios.length === 0 || Math.random() < PEDIDOS_S / TASA) {
    const pedidoId = `${CORRIDA}-P${exec.vu.idInTest}-${n++}`;
    const r = postJson(`${VENTAS}/pedidos`, { pedidoId }, { tipo: 'pedido' });
    check(r, { 'pedido confirmado': (x) => x.status === 201 });
    propios.push(pedidoId);
    if (propios.length > 50) propios.shift();
  } else {
    const id = propios[Math.floor(Math.random() * propios.length)];
    http.get(`${VENTAS}/pedidos/${id}`, { tags: { tipo: 'consulta', name: 'consulta' } });
  }
}
