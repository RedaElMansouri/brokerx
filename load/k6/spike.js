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

  // Write endpoint (orders) only when token provided
    if (TOKEN) {
    const clientOrderId = `spike-${__VU}-${Date.now()}`;
    const orderRes = http.post(
        `${BASE_URL}/api/v1/orders`,
        JSON.stringify({ order: { symbol: SYMBOL, direction: 'buy', quantity: 1, price: 1.05, client_order_id: clientOrderId } }),
        { headers: authHeaders() },
    );
    check(orderRes, { 'order 201/200/409/422': (r) => [201, 200, 409, 422].includes(r.status) });
    }

    sleep(0.3);
}
