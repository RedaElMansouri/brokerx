import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.TOKEN || '';
const APIKEY = __ENV.APIKEY || 'brokerx-key-123';
const SYMBOL = __ENV.SYMBOL || 'AAPL';

// Emit expected non-2xx as non-failures for business flows
http.setResponseCallback(
    http.expectedStatuses(200, 201, 204, 401, 409, 422)
);

export const options = {
    scenarios: {
    // Sustain reads to populate per-service rates and latency histograms
    portfolio_reads: {
            executor: 'constant-arrival-rate',
      rate: Number(__ENV.PORTFOLIO_RPS || 20), // requests per second
        timeUnit: '1s',
        duration: __ENV.DURATION || '5m',
        preAllocatedVUs: Number(__ENV.PRE_VUS || 20),
        maxVUs: Number(__ENV.MAX_VUS || 100),
        exec: 'portfolio',
    },
    // Mix of buys/sells to exercise orders-a/b (load balancer)
    orders_flow: {
        executor: 'constant-arrival-rate',
        rate: Number(__ENV.ORDERS_RPS || 10),
        timeUnit: '1s',
        duration: __ENV.DURATION || '5m',
        preAllocatedVUs: Number(__ENV.PRE_VUS || 20),
        maxVUs: Number(__ENV.MAX_VUS || 100),
        exec: 'orders',
        startTime: '0s',
    },
    // Occasional deposits to keep balances sufficient and exercise POST
    deposits_flow: {
        executor: 'constant-arrival-rate',
        rate: Number(__ENV.DEPOSIT_RPS || 2),
        timeUnit: '1s',
        duration: __ENV.DURATION || '5m',
        preAllocatedVUs: Number(__ENV.PRE_VUS || 10),
        maxVUs: Number(__ENV.MAX_VUS || 50),
        exec: 'deposits',
        startTime: '0s',
    },
    },
    thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<800'],
    },
};

function headers(extra = {}) {
    const h = { 'Content-Type': 'application/json', apikey: APIKEY, ...extra };
    if (TOKEN) h['Authorization'] = `Bearer ${TOKEN}`;
    return h;
}

export function portfolio() {
    const res = http.get(`${BASE_URL}/api/v1/portfolio`, { headers: headers() });
    check(res, { 'portfolio 200/401': (r) => [200, 401].includes(r.status) });
    sleep(0.1);
}

export function deposits() {
    if (!TOKEN) {
    // no auth → do nothing to avoid 401 flood; keep a small sleep
    sleep(0.2);
    return;
    }
    const idempo = `bench-dep-${__VU}-${Date.now()}`;
    const res = http.post(
    `${BASE_URL}/api/v1/deposits`,
    JSON.stringify({ amount: 250.0, currency: 'USD' }),
    { headers: headers({ 'Idempotency-Key': idempo }) },
    );
    check(res, { 'deposit 200/201': (r) => [200, 201].includes(r.status) });
    sleep(0.2);
}

export function orders() {
    if (!TOKEN) {
    sleep(0.2);
    return;
    }
    const buy = __ITER % 2 === 0;
    const price = buy ? 101.0 : 99.0;
    const clientOrderId = `bench-${__VU}-${__ITER}-${Date.now()}`;
    const payload = {
    order: {
        symbol: SYMBOL,
        order_type: 'limit',
        direction: buy ? 'buy' : 'sell',
        quantity: 1,
        price,
        time_in_force: 'DAY',
        client_order_id: clientOrderId,
    },
    };

    const res = http.post(`${BASE_URL}/api/v1/orders`, JSON.stringify(payload), {
    headers: headers(),
    });
    check(res, {
    'order 201/200/409/422': (r) => [201, 200, 409, 422].includes(r.status),
    'has X-Instance': (r) => !!r.headers['X-Instance'],
    });
    sleep(0.1);
}
