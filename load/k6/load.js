/**
 * Load Test - Charge soutenue
 * 
 * Objectif: Valider que l'application supporte une charge normale pendant une durée prolongée.
 * 
 * Usage:
 *   k6 run load/k6/load.js
 *   k6 run load/k6/load.js --env BASE_URL=http://localhost --env TOKEN=your-jwt-token
 *   k6 run load/k6/load.js --env VUS=50 --env DURATION=10m
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TOKEN = __ENV.TOKEN || '';
const SYMBOL = __ENV.SYMBOL || 'AAPL';

// Custom metrics
const orderLatency = new Trend('order_create_latency_ms');
const portfolioLatency = new Trend('portfolio_get_latency_ms');
const ordersCreated = new Counter('orders_created_total');
const orderErrors = new Counter('order_errors_total');
const successRate = new Rate('success_rate');

export const options = {
    // Montée progressive puis charge soutenue
    stages: [
        { duration: '1m', target: 20 },   // Ramp-up to 20 users
        { duration: '5m', target: 50 },   // Stay at 50 users (main load)
        { duration: '2m', target: 50 },   // Continue at 50
        { duration: '1m', target: 0 },    // Ramp-down
    ],
    thresholds: {
        http_req_failed: ['rate<0.01'],           // <1% errors
        http_req_duration: ['p(95)<500'],         // 95% under 500ms
        'order_create_latency_ms': ['p(95)<400'], // Orders fast
        'portfolio_get_latency_ms': ['p(95)<200'], // Reads very fast
        success_rate: ['rate>0.95'],              // >95% success
    },
};

function authHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (TOKEN) headers['Authorization'] = `Bearer ${TOKEN}`;
    return headers;
}

export function setup() {
    // Verify connectivity
    const healthRes = http.get(`${BASE_URL}/health`);
    if (healthRes.status !== 200) {
        throw new Error(`Health check failed: ${healthRes.status}`);
    }
    console.log(`Load test starting against ${BASE_URL}`);
    return { startTime: Date.now() };
}

export default function (data) {
    group('Read Operations', function () {
        // Health check
        const healthRes = http.get(`${BASE_URL}/health`);
        check(healthRes, { 'health ok': (r) => r.status === 200 });

        // Portfolio read
        const portfolioRes = http.get(`${BASE_URL}/api/v1/portfolio`, { 
            headers: authHeaders() 
        });
        portfolioLatency.add(portfolioRes.timings.duration);
        const portfolioOk = check(portfolioRes, { 
            'portfolio 200/401': (r) => [200, 401].includes(r.status) 
        });
        successRate.add(portfolioOk);
    });

    group('Write Operations', function () {
        if (!TOKEN) {
            sleep(0.5);
            return;
        }

        // Create order
        const clientOrderId = `load-${__VU}-${__ITER}-${Date.now()}`;
        const isBuy = __ITER % 2 === 0;
        const payload = JSON.stringify({
            order: {
                symbol: SYMBOL,
                order_type: 'limit',
                direction: isBuy ? 'buy' : 'sell',
                quantity: 1,
                price: isBuy ? 100.5 : 99.5,
                client_order_id: clientOrderId,
            },
        });

        const orderRes = http.post(`${BASE_URL}/api/v1/orders`, payload, {
            headers: authHeaders(),
        });

        orderLatency.add(orderRes.timings.duration);

        const orderOk = check(orderRes, {
            'order created': (r) => [200, 201].includes(r.status),
            'order response valid': (r) => {
                if (r.status === 201 || r.status === 200) {
                    const body = JSON.parse(r.body);
                    return body.success === true || body.order_id !== undefined;
                }
                return true; // Accept 409/422 as business valid
            },
        });

        if (orderRes.status === 201) {
            ordersCreated.add(1);
        } else if (orderRes.status >= 500) {
            orderErrors.add(1);
        }

        successRate.add(orderOk);
    });

    sleep(Math.random() * 2 + 0.5); // 0.5-2.5s between iterations
}

export function teardown(data) {
    const duration = (Date.now() - data.startTime) / 1000;
    console.log(`Load test completed in ${duration.toFixed(1)}s`);
}
