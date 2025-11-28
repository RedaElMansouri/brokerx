# Façades - Strangler Fig Pattern

Ce dossier contient les **façades** qui permettent au monolith de déléguer 
les appels vers les microservices extraits.

## Pattern Strangler Fig

```
┌─────────────────────────────────────────────────────────────────┐
│                         MONOLITH                                 │
│                                                                  │
│   Controller  ──────►  Façade  ──────►  HTTP Client             │
│                           │                   │                  │
│                           │                   ▼                  │
│                           │          ┌──────────────┐           │
│                           │          │ Microservice │           │
│                           │          └──────────────┘           │
│                           │                                      │
│                           └──► (fallback: code local legacy)    │
└─────────────────────────────────────────────────────────────────┘
```

## Façades disponibles

| Façade | Microservice | Port | Use Cases |
|--------|--------------|------|-----------|
| `ClientsFacade` | clients-service | 3001 | UC-01, UC-02 |
| `PortfoliosFacade` | portfolios-service | 3002 | UC-03 |
| `OrdersFacade` | orders-service | 3003 | UC-04 à UC-08 |

## Configuration

Les URLs des microservices sont configurées via variables d'environnement:

```ruby
ENV['CLIENTS_SERVICE_URL']    # default: http://localhost:3001
ENV['PORTFOLIOS_SERVICE_URL'] # default: http://localhost:3002
ENV['ORDERS_SERVICE_URL']     # default: http://localhost:3003
```

## Mode de fonctionnement

1. **Mode Microservices** (défaut): Les façades appellent les microservices
2. **Mode Legacy** (fallback): Si le microservice est down, utilise le code local

```ruby
# Exemple d'utilisation
facade = ClientsFacade.new
result = facade.register(email: "test@example.com", password: "secret", name: "Test")
```
