/**
 * Maximum Load Test - Remplir tous les dashboards Grafana
 * 
 * Test intensif pour :
 * - BrokerX Microservices Dashboard
 * - Golden Signals Dashboard  
 * - Kong Gateway Dashboard
 * 
 * Usage:
 *   k6 run load/k6/max_load_test.js
 *   k6 run load/k6/max_load_test.js --env DURATION=10m
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Configuration
const KONG_URL = __ENV.KONG_URL || 'http://localhost:8080';
const CLIENTS_URL = __ENV.CLIENTS_URL || 'http://localhost:3001';
const PORTFOLIOS_URL = __ENV.PORTFOLIOS_URL || 'http://localhost:3002';
const ORDERS_URL = __ENV.ORDERS_URL || 'http://localhost:3003';
const APIKEY = __ENV.APIKEY || 'brokerx-key-123';
const DURATION = __ENV.DURATION || '5m';

// Custom metrics
const kongLatency = new Trend('kong_latency_ms');
const microserviceLatency = new Trend('microservice_latency_ms');
const ordersCreated = new Counter('orders_created');
const ordersMatched = new Counter('orders_matched');
const errorRate = new Rate('error_rate');

// Accept various HTTP codes for business logic
http.setResponseCallback(
    http.expectedStatuses(200, 201, 204, 400, 401, 404, 409, 422, 500, 502, 503)
);

export const options = {
    scenarios: {
        // 1. Kong Gateway - Heavy traffic via API Gateway
        kong_health: {
            executor: 'constant-arrival-rate',
            rate: 100,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 50,
            maxVUs: 200,
            exec: 'kongHealth',
        },
        kong_portfolio: {
            executor: 'constant-arrival-rate',
            rate: 50,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 30,
            maxVUs: 150,
            exec: 'kongPortfolio',
        },
        kong_orders: {
            executor: 'ramping-arrival-rate',
            startRate: 10,
            timeUnit: '1s',
            preAllocatedVUs: 50,
            maxVUs: 200,
            stages: [
                { duration: '1m', target: 30 },
                { duration: '2m', target: 80 },
                { duration: '1m', target: 120 },
                { duration: '1m', target: 50 },
            ],
            exec: 'kongOrders',
        },
        
        // 2. Direct Microservices - Bypass Kong for service metrics
        clients_direct: {
            executor: 'constant-arrival-rate',
            rate: 30,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 20,
            maxVUs: 80,
            exec: 'clientsDirect',
        },
        portfolios_direct: {
            executor: 'constant-arrival-rate',
            rate: 40,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 25,
            maxVUs: 100,
            exec: 'portfoliosDirect',
        },
        orders_direct: {
            executor: 'constant-arrival-rate',
            rate: 30,
            timeUnit: '1s',
            duration: DURATION,
            preAllocatedVUs: 20,
            maxVUs: 80,
            exec: 'ordersDirect',
        },
        
        // 3. Stress spike - Push to limits
        stress_spike: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 50 },
                { duration: '1m', target: 150 },
                { duration: '30s', target: 300 },
                { duration: '1m', target: 100 },
                { duration: '30s', target: 0 },
            ],
            exec: 'stressTest',
            startTime: '1m',
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.20'],      // <20% failures (stress test)
        http_req_duration: ['p(95)<3000'],   // 95% under 3s
        kong_latency_ms: ['p(95)<1000'],
        microservice_latency_ms: ['p(95)<500'],
    },
};

function kongHeaders() {
    return { 
        'Content-Type': 'application/json', 
        'apikey': APIKEY,
    };
}

function directHeaders() {
    return { 'Content-Type': 'application/json' };
}

// ============ KONG GATEWAY SCENARIOS ============

export function kongHealth() {
    const res = http.get(`${KONG_URL}/health`, { headers: kongHeaders() });
    kongLatency.add(res.timings.duration);
    check(res, { 'kong health ok': (r) => r.status === 200 });
}

export function kongPortfolio() {
    const endpoints = [
        '/api/v1/portfolio',
        '/api/v1/portfolio/positions',
        '/api/v1/portfolio/transactions',
    ];
    const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
    
    const res = http.get(`${KONG_URL}${endpoint}`, { headers: kongHeaders() });
    kongLatency.add(res.timings.duration);
    check(res, { 'kong portfolio accessible': (r) => r.status < 500 });
    sleep(0.05);
}

export function kongOrders() {
    // Mix GET/POST
    if (Math.random() < 0.6) {
        // GET orders
        const res = http.get(`${KONG_URL}/api/v1/orders`, { headers: kongHeaders() });
        kongLatency.add(res.timings.duration);
        check(res, { 'kong get orders': (r) => r.status < 500 });
    } else {
        // POST order
        const buy = Math.random() < 0.5;
        const symbols = ['AAPL', 'GOOGL', 'MSFT', 'TSLA', 'AMZN'];
        const symbol = symbols[Math.floor(Math.random() * symbols.length)];
        
        const payload = JSON.stringify({
            order: {
                symbol: symbol,
                order_type: 'limit',
                direction: buy ? 'buy' : 'sell',
                quantity: Math.floor(Math.random() * 10) + 1,
                price: buy ? 100 + Math.random() * 10 : 95 + Math.random() * 10,
                time_in_force: 'DAY',
                client_order_id: `load-${__VU}-${__ITER}-${Date.now()}`,
            },
        });
        
        const res = http.post(`${KONG_URL}/api/v1/orders`, payload, { headers: kongHeaders() });
        kongLatency.add(res.timings.duration);
        
        if (res.status === 201) {
            ordersCreated.add(1);
        }
        check(res, { 'kong post order': (r) => r.status < 500 });
    }
    sleep(0.02);
}

// ============ DIRECT MICROSERVICES SCENARIOS ============

export function clientsDirect() {
    const endpoints = ['/health', '/metrics'];
    const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
    
    const res = http.get(`${CLIENTS_URL}${endpoint}`, { headers: directHeaders() });
    microserviceLatency.add(res.timings.duration);
    check(res, { 'clients direct ok': (r) => r.status < 500 });
    sleep(0.02);
}

export function portfoliosDirect() {
    const endpoints = ['/health', '/metrics'];
    const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
    
    const res = http.get(`${PORTFOLIOS_URL}${endpoint}`, { headers: directHeaders() });
    microserviceLatency.add(res.timings.duration);
    check(res, { 'portfolios direct ok': (r) => r.status < 500 });
    sleep(0.02);
}

export function ordersDirect() {
    const endpoints = ['/health', '/metrics'];
    const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
    
    const res = http.get(`${ORDERS_URL}${endpoint}`, { headers: directHeaders() });
    microserviceLatency.add(res.timings.duration);
    check(res, { 'orders direct ok': (r) => r.status < 500 });
    sleep(0.02);
}

// ============ STRESS TEST SCENARIO ============

export function stressTest() {
    // Random endpoint selection
    const targets = [
        { url: `${KONG_URL}/health`, name: 'kong-health' },
        { url: `${KONG_URL}/api/v1/portfolio`, name: 'kong-portfolio' },
        { url: `${KONG_URL}/api/v1/orders`, name: 'kong-orders' },
        { url: `${CLIENTS_URL}/health`, name: 'clients' },
        { url: `${PORTFOLIOS_URL}/health`, name: 'portfolios' },
        { url: `${ORDERS_URL}/health`, name: 'orders' },
    ];
    
    const target = targets[Math.floor(Math.random() * targets.length)];
    const res = http.get(target.url, { headers: kongHeaders() });
    
    const passed = check(res, { [`${target.name} stress ok`]: (r) => r.status < 500 });
    errorRate.add(!passed);
    
    // Minimal sleep for maximum pressure
    sleep(0.01);
}

export function setup() {
    console.log('🚀 Maximum Load Test Starting');
    console.log(`   Kong Gateway: ${KONG_URL}`);
    console.log(`   Clients Service: ${CLIENTS_URL}`);
    console.log(`   Portfolios Service: ${PORTFOLIOS_URL}`);
    console.log(`   Orders Service: ${ORDERS_URL}`);
    console.log(`   Duration: ${DURATION}`);
    console.log('');
    console.log('📊 Dashboards to fill:');
    console.log('   - BrokerX Microservices');
    console.log('   - Golden Signals');
    console.log('   - Kong Gateway');
    console.log('');
    
    // Verify services are up
    const checks = [
        { name: 'Kong', url: `${KONG_URL}/health` },
        { name: 'Clients', url: `${CLIENTS_URL}/health` },
        { name: 'Portfolios', url: `${PORTFOLIOS_URL}/health` },
        { name: 'Orders', url: `${ORDERS_URL}/health` },
    ];
    
    for (const c of checks) {
        const res = http.get(c.url, { timeout: '5s' });
        console.log(`   ${c.name}: ${res.status === 200 ? '✅' : '❌'} (${res.status})`);
    }
    
    return { startTime: Date.now() };
}

export function teardown(data) {
    const duration = (Date.now() - data.startTime) / 1000;
    console.log('');
    console.log('🏁 Test Complete');
    console.log(`   Total duration: ${duration.toFixed(1)}s`);
    console.log('');
    console.log('📈 Check Grafana dashboards at: http://localhost:3100');
}

// Default function (required by k6)
export default function() {
    // This is a placeholder - actual work is done by scenario executors
    stressTest();
}
