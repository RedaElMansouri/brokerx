import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.TOKEN || '';
const APIKEY = __ENV.APIKEY || 'brokerx-key-123';
const SYMBOL = __ENV.SYMBOL || 'AAPL';

// Treat certain business-valid non-2xx statuses as expected to avoid inflating http_req_failed
// Orders can return 409/422; portfolio may return 401 if token missing/invalid; deposits 200/201
http.setResponseCallback(http.expectedStatuses(200, 201, 204, 401, 409, 422));

export const options = {
    vus: Number(__ENV.VUS || 5),
    duration: __ENV.DURATION || '45s',
    thresholds: {
    http_req_duration: ['p(95)<600'],
    http_req_failed: ['rate<0.05']
    }
};

function headers() {
    const h = { 'Content-Type': 'application/json', 'apikey': APIKEY };
    if (TOKEN) h['Authorization'] = `Bearer ${TOKEN}`;
    return h;
}

export default function () {
  // Portfolio via gateway
    const p = http.get(`${BASE_URL}/api/v1/portfolios`, { headers: headers() });
    check(p, { 'portfolio 200/401': (r) => [200,401].includes(r.status) });

  // One-time deposit per VU to ensure buys succeed
    if (TOKEN && __ITER === 0) {
    const dep = http.post(`${BASE_URL}/api/v1/deposits`, JSON.stringify({ amount: 1000.0, currency: 'USD' }), { headers: Object.assign({}, headers(), { 'Idempotency-Key': `gw-dep-${__VU}` }) });
    check(dep, { 'deposit 200/201': (r) => [200,201].includes(r.status) });
    }

  // Orders via gateway (alternate buy/sell)
    if (TOKEN) {
    const side = (__ITER % 2 === 0) ? 'buy' : 'sell';
    const price = side === 'buy' ? 101.0 : 99.0;
    const order = http.post(`${BASE_URL}/api/v1/orders`, JSON.stringify({ order: { symbol: SYMBOL, order_type: 'limit', direction: side, quantity: 1, price, client_order_id: `gw-${__VU}-${__ITER}` } }), { headers: headers() });
    check(order, { 'order ok': (r) => [200,201,409,422].includes(r.status) });
    // Observe LB distribution
    if (order.headers['X-Instance']) {
      // no-op: you can aggregate by X-Instance if sending to Influx, here we just ensure header exists
        check(order, { 'has X-Instance': (r) => !!r.headers['X-Instance'] });
    }
    }

    sleep(0.5);
}
