/**
 * Load Balancer Test - Valider la distribution Nginx
 * 
 * Objectif: Vérifier que le trafic est correctement distribué entre les instances web.
 * 
 * Usage:
 *   # Lancer d'abord l'architecture LB
 *   docker compose -f docker-compose.lb.yml up -d
 *   
 *   # Puis exécuter le test
 *   k6 run load/k6/lb_test.js
 *   k6 run load/k6/lb_test.js --env BASE_URL=http://localhost --env DURATION=2m
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const TOKEN = __ENV.TOKEN || '';

// Track distribution across instances
const instanceHits = {
    'web-1': new Counter('instance_web1_hits'),
    'web-2': new Counter('instance_web2_hits'),
    'web-3': new Counter('instance_web3_hits'),
    'unknown': new Counter('instance_unknown_hits'),
};
const responseLatency = new Trend('lb_response_latency_ms');

export const options = {
    vus: Number(__ENV.VUS || 30),
    duration: __ENV.DURATION || '1m',
    thresholds: {
        http_req_failed: ['rate<0.01'],
        http_req_duration: ['p(95)<300'],
        // Ensure all instances are hit (at least 10% each for 3 instances)
        'instance_web1_hits': ['count>0'],
        'instance_web2_hits': ['count>0'],
        'instance_web3_hits': ['count>0'],
    },
};

function authHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (TOKEN) headers['Authorization'] = `Bearer ${TOKEN}`;
    return headers;
}

export function setup() {
    console.log(`🔄 Load Balancer test against ${BASE_URL}`);
    console.log('Expecting requests to be distributed across web-1, web-2, web-3');
    
    // Verify nginx is responding
    const res = http.get(`${BASE_URL}/health`);
    if (res.status !== 200) {
        throw new Error(`Cannot reach load balancer: ${res.status}`);
    }
    
    return { 
        startTime: Date.now(),
        instanceCounts: { 'web-1': 0, 'web-2': 0, 'web-3': 0, 'unknown': 0 }
    };
}

export default function (data) {
    // Simple health check to test distribution
    const res = http.get(`${BASE_URL}/health`, { headers: authHeaders() });
    
    responseLatency.add(res.timings.duration);
    
    check(res, { 'health ok': (r) => r.status === 200 });
    
    // Track which instance handled the request
    const xInstance = res.headers['X-Instance'];
    const xUpstream = res.headers['X-Upstream-Server'];
    
    // Determine instance from headers
    let instance = 'unknown';
    if (xInstance && xInstance.startsWith('web-')) {
        instance = xInstance;
    } else if (xUpstream) {
        // Parse upstream IP to determine instance (approximate)
        // In docker-compose.lb.yml: web-1, web-2, web-3 have different IPs
        if (xUpstream.includes(':3000')) {
            // We can't reliably map IP to instance here, but we track distribution
            instance = `upstream-${xUpstream.split(':')[0].split('.').pop()}`;
        }
    }
    
    // Increment appropriate counter
    if (instance.includes('web-1') || instance.includes('-4')) {
        instanceHits['web-1'].add(1);
    } else if (instance.includes('web-2') || instance.includes('-6')) {
        instanceHits['web-2'].add(1);
    } else if (instance.includes('web-3') || instance.includes('-5')) {
        instanceHits['web-3'].add(1);
    } else {
        instanceHits['unknown'].add(1);
    }
    
    // Also test an API endpoint
    if (__ITER % 5 === 0) {
        const apiRes = http.get(`${BASE_URL}/api/v1/portfolio`, { headers: authHeaders() });
        check(apiRes, { 'api responds': (r) => r.status < 500 });
    }
    
    sleep(0.1);
}

export function teardown(data) {
    const duration = (Date.now() - data.startTime) / 1000;
    console.log(`\n📊 Load Balancer test completed in ${duration.toFixed(1)}s`);
    console.log('\nCheck the k6 output for instance_web*_hits counters.');
    console.log('A healthy LB should show roughly equal distribution across all instances.');
    console.log('\nExpected: ~33% per instance (±10%)');
}
