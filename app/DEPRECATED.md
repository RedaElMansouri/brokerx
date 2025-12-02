# ⚠️ DEPRECATED - Monolith Architecture

> **Date de dépréciation**: 2 décembre 2025  
> **Remplacé par**: Architecture Microservices (`services/`)  
> **Statut**: Conservé pour rollback uniquement

## 🚨 Avertissement

Ce dossier `app/` contient le code du **monolithe BrokerX** qui est maintenant **DÉPRÉCIÉ**.

L'architecture active est désormais basée sur les **microservices** situés dans le dossier `services/`:
- `services/clients-service/` - Gestion des clients
- `services/portfolios-service/` - Gestion des portefeuilles  
- `services/orders-service/` - Gestion des ordres
- `services/gateway/` - Kong API Gateway

## 📋 Migration

| Ancien (Monolithe) | Nouveau (Microservices) |
|-------------------|------------------------|
| `app/domain/clients/` | `services/clients-service/` |
| `app/facades/portfolios_facade.rb` | `services/portfolios-service/` |
| `app/facades/orders_facade.rb` | `services/orders-service/` |
| `docker-compose.monolith.yml` | `docker-compose.yml` |

## 🔄 Rollback

Si vous devez revenir au monolithe:

```bash
# Option 1: Utiliser le script de rollback
./scripts/rollback_to_monolith.sh

# Option 2: Rollback manuel
git checkout main
docker compose -f docker-compose.monolith.yml up -d
```

## ⏳ Plan de suppression

Ce code sera supprimé définitivement après:
1. ✅ Validation complète des tests E2E microservices
2. ✅ Période de stabilisation de 30 jours en production
3. ✅ Confirmation de l'équipe

## 📞 Contact

Pour toute question concernant la migration, contactez l'équipe de développement.

---

> **Note**: Ne modifiez PAS ce code. Toute nouvelle fonctionnalité doit être implémentée dans les microservices.
