# ADR 006 : Observabilité avec Prometheus + Grafana

## Statut
Accepté — 2025-10-28

## Contexte
Nous devons démontrer la capacité opérationnelle via la collecte de métriques et des tableaux de bord. Les services exposent des métriques personnalisées ; nous avons besoin d’un collecteur et d’une UI.

## Décision
Déployer Prometheus (scrapant les endpoints `/metrics` des services et l’admin `/metrics` de Kong) et Grafana avec deux tableaux de bord :
- BrokerX Golden Signals : `docs/observability/grafana/brokerx-dashboard.json`
- Kong / Gateway : `docs/observability/grafana/kong-gateway-dashboard.json`

## Conséquences
- Avantages : open-source, rapide à mettre en place via Docker, écosystème riche.
- Inconvénients : s’assurer que Prometheus recharge bien la configuration et scrape tous les jobs (redémarrage si nécessaire).
- Opérations : vérifier `/targets` dans Prometheus ; capturer les captures d’écran pendant les runs k6 pour obtenir des graphiques renseignés.

## Alternatives considérées
- OpenTelemetry Collector + Tempo/Loki : plus complet, mais hors du périmètre de la démo.

## Liens
- Prometheus : `config/observability/prometheus.yml`
- Dashboards : `docs/observability/grafana/*.json`
