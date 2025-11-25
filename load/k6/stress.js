/**
 * Stress Test - Trouver le point de rupture
 * 
 * Objectif: Identifier la capacité maximale de l'application et son comportement sous charge extrême.
 * 
 * Usage:
 *   k6 run load/k6/stress.js
 *   k6 run load/k6/stress.js --env BASE_URL=http://localhost --env TOKEN=your-jwt-token
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TOKEN = __ENV.TOKEN || '';
const SYMBOL = __ENV.SYMBOL || 'AAPL';

// Custom metrics
const responseTime = new Trend('response_time_ms');
const errorRate = new Rate('error_rate');
const requestsTotal = new Counter('requests_total');

export const options = {
    // Montée progressive jusqu'au point de rupture
    stages: [
        { duration: '2m', target: 50 },    // Warm-up
        { duration: '3m', target: 100 },   // Normal load
        { duration: '3m', target: 200 },   // High load
        { duration: '3m', target: 300 },   // Stress level
        { duration: '3m', target: 400 },   // Breaking point?
        { duration: '2m', target: 500 },   // Extreme stress
        { duration: '2m', target: 0 },     // Recovery
    ],
    thresholds: {
        // Thresholds plus permissifs pour stress test
        http_req_failed: ['rate<0.10'],           // <10% errors acceptable
        http_req_duration: ['p(95)<2000'],        // 95% under 2s
        error_rate: ['rate<0.15'],                // <15% error rate
    },
};

function authHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (TOKEN) headers['Authorization'] = `Bearer ${TOKEN}`;
    return headers;
}

export function setup() {
    console.log(`🔥 Stress test starting against ${BASE_URL}`);
    console.log('⚠️  This test will push the system to its limits');
    return { startTime: Date.now() };
}

export default function () {
    requestsTotal.add(1);

    // Mix of read and write operations (70% reads, 30% writes)
    const isRead = Math.random() < 0.7;

    if (isRead) {
        // Read operation
        const endpoint = Math.random() < 0.5 ? '/health' : '/api/v1/portfolio';
        const res = http.get(`${BASE_URL}${endpoint}`, { 
            headers: authHeaders(),
            timeout: '10s',
        });
        
        responseTime.add(res.timings.duration);
        const passed = check(res, { 
            'response ok': (r) => r.status < 500 
        });
        errorRate.add(!passed);
    } else if (TOKEN) {
        // Write operation
        const clientOrderId = `stress-${__VU}-${__ITER}-${Date.now()}`;
        const payload = JSON.stringify({
            order: {
                symbol: SYMBOL,
                order_type: 'limit',
                direction: Math.random() < 0.5 ? 'buy' : 'sell',
                quantity: 1,
                price: 100.0 + (Math.random() * 2 - 1),
                client_order_id: clientOrderId,
            },
        });

        const res = http.post(`${BASE_URL}/api/v1/orders`, payload, {
            headers: authHeaders(),
            timeout: '10s',
        });

        responseTime.add(res.timings.duration);
        const passed = check(res, {
            'order not server error': (r) => r.status < 500,
        });
        errorRate.add(!passed);
    }

    // Minimal sleep to maximize pressure
    sleep(0.1);
}

export function teardown(data) {
    const duration = (Date.now() - data.startTime) / 1000;
    console.log(`\n📊 Stress test completed in ${duration.toFixed(1)}s`);
    console.log('Check the results to identify:');
    console.log('  - At what VU count did errors start appearing?');
    console.log('  - At what VU count did latency degrade significantly?');
    console.log('  - Did the system recover after load decreased?');
}
