import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TOKEN = __ENV.TOKEN || '';
const SYMBOL = __ENV.SYMBOL || 'AAPL';

export const options = {
    stages: [
    { duration: '20s', target: 5 },   // warm-up
    { duration: '10s', target: 50 },  // spike up
    { duration: '20s', target: 50 },  // hold
    { duration: '20s', target: 5 },   // scale down
    ],
    thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<600'],
    },
};

function authHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (TOKEN) headers['Authorization'] = `Bearer ${TOKEN}`;
    return headers;
}

export default function () {
  // Read endpoints
    const p = http.get(`${BASE_URL}/api/v1/portfolio`, { headers: authHeaders() });
    const d = http.get(`${BASE_URL}/api/v1/deposits`, { headers: authHeaders() });
    check(p, { 'portfolio ok/unauth': (r) => [200, 401].includes(r.status) });
    check(d, { 'deposits ok/unauth': (r) => [200, 401].includes(r.status) });

  // Top-up funds once per VU to avoid 422 on buys (requires TOKEN)
    if (TOKEN && __ITER === 0) {
      const idempo = `k6-deposit-${__VU}-${Date.now()}`;
      const depHeaders = Object.assign({}, authHeaders(), { 'Idempotency-Key': idempo });
      const depRes = http.post(
        `${BASE_URL}/api/v1/deposits`,
        JSON.stringify({ amount: 5000.0, currency: 'USD' }),
        { headers: depHeaders },
      );
      check(depRes, { 'deposit 201/200': (r) => [200, 201].includes(r.status) });
    }

  // Write endpoint (orders) only when token provided
    if (TOKEN) {
      const isBuy = (__ITER % 2 === 0);
      const price = isBuy ? 101.0 : 99.0;
      const side = isBuy ? 'buy' : 'sell';
      const clientOrderId = `spike-${__VU}-${__ITER}-${Date.now()}`;
      const payload = { order: { symbol: SYMBOL, order_type: 'limit', direction: side, quantity: 1, price, client_order_id: clientOrderId } };
      const orderRes = http.post(
        `${BASE_URL}/api/v1/orders`,
        JSON.stringify(payload),
        { headers: authHeaders() },
      );
      check(orderRes, { 'order 201/200/409/422': (r) => [201, 200, 409, 422].includes(r.status) });
    }

    sleep(0.3);
}
