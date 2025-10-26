# Load testing (k6)

This folder contains simple k6 scenarios to validate performance and capture metrics exposed at `/metrics`.

## Prereqs
- App running locally at http://localhost:3000
- An access token (JWT) if you want to exercise authenticated endpoints
  - You can obtain one via Postman: Login → Verify MFA (token TTL: 24h)

Export environment variables for k6:
- BASE_URL: API base (default `http://localhost:3000`)
- TOKEN: Bearer JWT to hit authenticated endpoints
- SYMBOL: Market symbol used by orders (default `AAPL`)
- VUS/DURATION (for smoke.js) or use stages in spike.js

## Scenarios
- load/k6/smoke.js
  - Small constant load; hits:
    - GET /api/v1/portfolio (auth)
    - GET /api/v1/deposits (auth)
    - POST /api/v1/deposits (auth)
    - POST /api/v1/orders (auth, idempotent)
    - GET /metrics (unauth)
- load/k6/spike.js
  - Spike/soak-like sequence; mostly GETs, plus order creation when TOKEN is provided

## Notes
- The order POST includes a unique `client_order_id` per VU to ensure idempotency.
- If TOKEN is omitted, scripts will still run but skip POSTs (write paths).
- Metrics to watch in Prometheus/Grafana:
  - http_requests_total{code}
  - histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))
  - orders_accepted_total
  - trades_executed_total
  - orders_enqueued_total, orders_matched_total
  - matching_queue_size (gauge)
  - cable_connections (gauge)

## Optional: running Prometheus + Grafana
- See `docker-compose.observability.yml` and `config/observability/prometheus.yml`
- Prometheus scrapes `http://host.docker.internal:3000/metrics` (Docker Desktop on macOS)
- Import `docs/observability/grafana/brokerx-dashboard.json` in Grafana to visualize key signals
