# ADR 005 : Adopter Kong (DB-less) comme API Gateway

## Statut
Accepté — 2025-10-28

## Contexte
Nous avons besoin d’une passerelle simple et reproductible pour exposer les microservices, fournir le routage, CORS, key-auth et un équilibrage de charge basique pour la démonstration, avec exposition de métriques Prometheus.

## Décision
Utiliser Kong OSS 3.x en mode DB-less avec un fichier déclaratif `gateway/kong.yml` pour définir services, routes et plugins globaux (prometheus, cors, key-auth). Exposer l’admin `/metrics` pour le scraping par Prometheus.

## Conséquences
- Avantages : démarrage rapide, reproductible, pas de datastore additionnel, support de l’équilibrage entre `orders-a`/`orders-b`.
- Inconvénients : granularité des métriques par service limitée selon l’image/version de Kong ; l’API admin reste exposée en local uniquement.
- Opérations : inclure un job `kong` dans Prometheus ; importer un tableau de bord Grafana axé sur les séries nginx/global (RPS, connexions, bande passante).

## Alternatives considérées
- Traefik : simple, bon support Docker, mais moins d’exemples orientés métriques Kong existants dans le projet.
- Nginx direct : léger, mais nécessite plus de configuration manuelle pour l’authentification et les métriques.

## Liens
- `gateway/kong.yml`
- Tableau de bord : `docs/observability/grafana/kong-gateway-dashboard.json`
