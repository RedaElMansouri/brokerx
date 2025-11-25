# ADR 008: Redis comme Cache Distribué et Session Store

## Statut
**Approuvé** | **Date**: 2025-11-25 | **Décideurs**: Équipe Architecture

## Contexte
Dans une architecture avec plusieurs instances de l'application (load balancing), nous avons besoin d'un cache partagé pour :
- Maintenir la cohérence des sessions entre les instances
- Améliorer les performances via la mise en cache des données fréquemment accédées
- Supporter ActionCable (WebSockets) en mode multi-instances

## Décision
**Nous adoptons Redis comme cache distribué et session store.**

### Configuration implémentée :

```ruby
# config/initializers/cache_store.rb
if redis_url.present?
  Rails.application.config.cache_store = :redis_cache_store, {
    url: redis_url,
    error_handler: ->(method:, _returning:, exception:) {
      Rails.logger.warn("RedisCacheStore error: #{exception.message}")
    }
  }
end
```

```yaml
# docker-compose.yml
redis:
  image: redis:7-alpine
  command: ["redis-server", "--appendonly", "no"]
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
```

### Caractéristiques :
1. **Fallback gracieux** : Si Redis n'est pas disponible, l'application fonctionne avec le cache mémoire
2. **Healthcheck Docker** : Vérification de santé intégrée
3. **Mode non-persistant** : `appendonly no` pour les performances (cache = données volatiles)

## Conséquences

### Positives
- Sessions partagées entre toutes les instances web
- ActionCable fonctionne en mode distribué
- Cache cohérent même avec scale horizontal
- Performances améliorées pour les requêtes répétitives

### Négatives (mitigées)
- Dépendance supplémentaire (Redis)
- Point de défaillance potentiel → mitigé par le fallback gracieux
- Latence réseau ajoutée → négligeable (<1ms en local)

## Alternatives considérées

### Memcached
- **Avantages** : Simple, performant
- **Inconvénients** : Pas de pub/sub (requis pour ActionCable), pas de persistance

### Cache en mémoire (Rails.cache)
- **Avantages** : Aucune dépendance externe
- **Inconvénients** : Non partagé entre instances, perte au redémarrage

## Validation
- [x] Configuration Redis dans docker-compose.yml
- [x] Initializer cache_store.rb avec fallback
- [x] Test avec load balancing (3 instances)
- [x] Healthcheck fonctionnel
