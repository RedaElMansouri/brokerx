import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

// Config via environment variables
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TOKEN = __ENV.TOKEN || '';
const SYMBOL = __ENV.SYMBOL || 'AAPL';

// Custom metrics
const orderCreateLatency = new Trend('order_create_latency_ms');
const depositsCreateLatency = new Trend('deposit_create_latency_ms');
const ordersAccepted = new Counter('orders_accepted');

export const options = {
    vus: Number(__ENV.VUS || 5),
    duration: __ENV.DURATION || '1m',
    thresholds: {
    http_req_duration: ['p(95)<500'],
    'order_create_latency_ms': ['p(95)<400'],
    'deposit_create_latency_ms': ['p(95)<400'],
    },
};

function authHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (TOKEN) headers['Authorization'] = `Bearer ${TOKEN}`;
    return headers;
}

export default function () {
  // Portfolio (GET)
    const portfolioRes = http.get(`${BASE_URL}/api/v1/portfolio`, { headers: authHeaders() });
    check(portfolioRes, {
    'portfolio 200/304/401': (r) => [200, 304, 401].includes(r.status),
    });

  // Deposits list (GET)
    const depListRes = http.get(`${BASE_URL}/api/v1/deposits`, { headers: authHeaders() });
    check(depListRes, {
    'deposits index ok/unauth': (r) => [200, 401].includes(r.status),
    });

  // Create deposit (POST) if token provided
    if (TOKEN) {
    const depositPayload = JSON.stringify({ deposit: { amount: 1000.0, currency: 'USD' } });
    const depRes = http.post(`${BASE_URL}/api/v1/deposits`, depositPayload, { headers: authHeaders() });
    depositsCreateLatency.add(depRes.timings.duration);
    check(depRes, { 'deposit created 201': (r) => r.status === 201 });
    }

  // Place a small order to exercise matching path (POST)
    if (TOKEN) {
    const clientOrderId = `k6-${__VU}-${Date.now()}`;
    const orderPayload = JSON.stringify({
        order: {
        symbol: SYMBOL,
        direction: 'buy',
        quantity: 1,
        price: 1.01,
        client_order_id: clientOrderId,
        },
    });
    const orderRes = http.post(`${BASE_URL}/api/v1/orders`, orderPayload, { headers: authHeaders() });
    orderCreateLatency.add(orderRes.timings.duration);
    if (orderRes.status === 201) ordersAccepted.add(1);
    check(orderRes, {
        'order accepted 201 or idempotent 200/409 or 422': (r) => [201, 200, 409, 422].includes(r.status),
    });
    }

  // Metrics scrape (GET /metrics)
    const metricsRes = http.get(`${BASE_URL}/metrics`);
    check(metricsRes, { 'metrics exposed': (r) => r.status === 200 });

    sleep(1);
}
