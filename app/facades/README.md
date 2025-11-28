# Façades - Strangler Fig Pattern

Ce dossier contient les **façades** qui permettent au monolith de déléguer 
les appels vers les microservices extraits.

## Pattern Strangler Fig

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                       MONOLITH                          │
Client Request ───► │                                                         │
                    │   Proxy Controller ───► Façade ───► HTTP Client         │
                    │          │                              │               │
                    │          │                              ▼               │
                    │          │                    ┌──────────────┐          │
                    │          │                    │ Microservice │          │
                    │          │                    │  (port 300X) │          │
                    │          │                    └──────────────┘          │
                    │          │                                              │
                    │          └──► (STRANGLER_FIG_ENABLED=false)            │
                    │                 uses local controller                   │
                    └─────────────────────────────────────────────────────────┘
```

## Architecture

### 1. Proxy Controllers (`app/infrastructure/web/controllers/api/v1/*_proxy_controller.rb`)

Les proxy controllers interceptent les requêtes et décident de:
- **Mode Microservices** (`STRANGLER_FIG_ENABLED=true`): Délègue à la Façade
- **Mode Monolith** (`STRANGLER_FIG_ENABLED=false`): Utilise le contrôleur local

### 2. Façades (`app/facades/*_facade.rb`)

Les façades encapsulent les appels HTTP vers les microservices:

| Façade | Microservice | Port | Use Cases |
|--------|--------------|------|-----------|
| `ClientsFacade` | clients-service | 3001 | UC-01, UC-02 |
| `PortfoliosFacade` | portfolios-service | 3002 | UC-03 |
| `OrdersFacade` | orders-service | 3003 | UC-04 à UC-08 |

## Configuration

### Variables d'environnement

```bash
# Activer le mode microservices (Strangler Fig)
STRANGLER_FIG_ENABLED=true

# Activer/désactiver chaque service individuellement
CLIENTS_SERVICE_ENABLED=true
PORTFOLIOS_SERVICE_ENABLED=true
ORDERS_SERVICE_ENABLED=true

# URLs des microservices
CLIENTS_SERVICE_URL=http://clients-service:3001
PORTFOLIOS_SERVICE_URL=http://portfolios-service:3002
ORDERS_SERVICE_URL=http://orders-service:3003
```

### Mode Monolith (défaut)

```bash
# docker-compose.yml - Le monolith fonctionne normalement
docker compose up -d
```

### Mode Microservices

```bash
# 1. Démarrer les microservices
docker compose -f docker-compose.microservices.yml up -d

# 2. OU configurer manuellement
export STRANGLER_FIG_ENABLED=true
export CLIENTS_SERVICE_ENABLED=true
export PORTFOLIOS_SERVICE_ENABLED=true
export ORDERS_SERVICE_ENABLED=true
```

## Flux de données

```
┌─────────────────────────────────────────────────────────────────────────┐
│ POST /api/v1/clients/register                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  routes.rb                                                              │
│     └── api/v1/clients_proxy#create                                     │
│              │                                                          │
│              ▼                                                          │
│  ClientsProxyController.create                                          │
│     │                                                                   │
│     ├── [STRANGLER_FIG_ENABLED=true]                                    │
│     │      └── ClientsFacade.register(...)                              │
│     │              └── HTTP POST http://clients-service:3001/...        │
│     │                                                                   │
│     └── [STRANGLER_FIG_ENABLED=false]                                   │
│            └── Api::V1::ClientsController.create (local)                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Fallback automatique

Si un microservice est indisponible, le proxy controller peut fallback vers le code local:

```ruby
def delegate_to_microservice(action)
  # ... appel au microservice
rescue BaseFacade::ServiceUnavailableError => e
  Rails.logger.warn("[StranglerFig] Microservice unavailable, falling back to local")
  delegate_to_local(action)
end
```

## Avantages du Pattern Strangler Fig

1. **Migration incrémentale**: Migrer un service à la fois
2. **Rollback facile**: Désactiver un service = utiliser le code local
3. **Zero downtime**: Le monolith reste fonctionnel pendant la migration
4. **Test en production**: Activer un service pour un % d'utilisateurs
