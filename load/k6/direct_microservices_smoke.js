import http from 'k6/http';
import { check, sleep } from 'k6';

// Separate base URLs to hit microservices directly
const PORTFOLIOS_URL = __ENV.PORTFOLIOS_URL || 'http://localhost:3003';
const ORDERS_URL = __ENV.ORDERS_URL || 'http://localhost:3001';
const TOKEN = __ENV.TOKEN || '';
const APIKEY = __ENV.APIKEY || ''; // not used direct
const SYMBOL = __ENV.SYMBOL || 'AAPL';

// Align expected statuses with business rules
http.setResponseCallback(http.expectedStatuses(200, 201, 204, 401, 409, 422));

export const options = {
    vus: Number(__ENV.VUS || 5),
    duration: __ENV.DURATION || '45s',
    thresholds: {
    http_req_duration: ['p(95)<600'],
    http_req_failed: ['rate<0.05']
    }
};

function authHeaders() {
    const h = { 'Content-Type': 'application/json' };
    if (TOKEN) h['Authorization'] = `Bearer ${TOKEN}`;
    return h;
}

export default function () {
  // Portfolio via portfolios service
    const p = http.get(`${PORTFOLIOS_URL}/api/v1/portfolio`, { headers: authHeaders() });
    check(p, { 'portfolio 200/401': (r) => [200,401].includes(r.status) });

  // One-time deposit per VU to ensure buys succeed
    if (TOKEN && __ITER === 0) {
    const dep = http.post(
        `${PORTFOLIOS_URL}/api/v1/deposits`,
        JSON.stringify({ amount: 1000.0, currency: 'USD' }),
        { headers: Object.assign({}, authHeaders(), { 'Idempotency-Key': `dir-dep-${__VU}` }) }
    );
    check(dep, { 'deposit 200/201': (r) => [200,201].includes(r.status) });
    }

  // Orders via orders service (alternate buy/sell)
    if (TOKEN) {
    const side = (__ITER % 2 === 0) ? 'buy' : 'sell';
    const price = side === 'buy' ? 101.0 : 99.0;
    const order = http.post(
        `${ORDERS_URL}/api/v1/orders`,
        JSON.stringify({ order: { symbol: SYMBOL, order_type: 'limit', direction: side, quantity: 1, price, client_order_id: `dir-${__VU}-${__ITER}` } }),
        { headers: authHeaders() }
    );
    check(order, { 'order ok': (r) => [200,201,409,422].includes(r.status) });
    }

    sleep(0.5);
}
