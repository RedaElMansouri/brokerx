# ADR 007 : ActionCable pour les notifications temps réel

## Statut
Accepté — 2025-10-28

## Contexte
Les utilisateurs bénéficient de mises à jour en temps réel (statut des ordres, transactions). Nous voulons une solution WebSocket simple, native à Rails et intégrée aux métriques.

## Décision
Exposer ActionCable sur `/cable`, authentifier les connexions via JWT HS256 et exposer les jauges/compteurs (`cable_connections`, `cable_connections_total`). Fournir un script k6 WebSocket pour maintenir des connexions pendant la prise de captures.

## Conséquences
- Avantages : intégration minimale, réutilise la pile Rails existante, mesurable via Prometheus.
- Inconvénients : la jauge est transitoire (non nulle uniquement quand des sessions sont actives) ; nécessite un run WS lors des captures.
- Opérations : exécuter `load/k6/cable_connect.js` (via Docker) pour maintenir l’activité ; autoriser les origines locales en `production.rb` pour la démo.

## Alternatives considérées
- AnyCable / Phoenix Channels : plus performants, mais ajout de complexité et hors périmètre de la démo.

## Liens
- Scripts k6 : `load/k6/cable_connect.js`
- Métriques : endpoint `/metrics` des services
