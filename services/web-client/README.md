# BrokerX Web Client (Microservices)

Client web Rails pour BrokerX qui se connecte aux microservices via Kong Gateway.

## Architecture

```
web-client/
├── Dockerfile
├── Gemfile
├── config/
│   ├── routes.rb           # Routes: /, /portfolio, /orders + API proxy
│   └── application.rb      # Configuration Kong Gateway URL
├── app/
│   ├── controllers/
│   │   ├── static_controller.rb      # Page d'accueil
│   │   ├── portfolios_controller.rb  # Page portfolio
│   │   ├── orders_controller.rb      # Page ordres
│   │   └── api/v1/proxy_controller.rb # Proxy vers Kong Gateway
│   ├── views/
│   │   ├── layouts/application.html.erb
│   │   ├── static/index.html.erb     # Landing page (copie du monolith)
│   │   ├── portfolios/show.html.erb  # Portfolio (copie du monolith)
│   │   └── orders/                   # Ordres (copie du monolith)
│   └── assets/
│       └── stylesheets/              # CSS (copie du monolith)
└── public/
    └── js/orders.js                  # JavaScript ordres
```

## Routes

| Route | Description |
|-------|-------------|
| `/` | Landing page avec login/register |
| `/portfolio` | Page portfolio (auth requise) |
| `/orders` | Page ordres (auth requise) |
| `/api/v1/*` | Proxy vers Kong Gateway |

## Configuration

Variables d'environnement:
- `KONG_GATEWAY_URL` - URL du Kong Gateway (défaut: `http://localhost:8080`)
- `SECRET_KEY_BASE` - Clé secrète Rails

## Développement

```bash
cd services/web-client
bundle install
bundle exec rails server -p 3000
```

## Docker

```bash
# Build
docker build -t brokerx-web-client .

# Run
docker run -p 8888:3000 \
  -e KONG_GATEWAY_URL=http://kong:8000 \
  brokerx-web-client
```

## Différences avec le Monolith

- Les appels API passent par le proxy `/api/v1/*` → Kong Gateway
- WebSocket se connecte directement à Orders Service (port 3003)
- Indication visuelle "(Microservices)" dans l'interface
