# Questions Réelles de l'Oral — BrokerX
## Basé sur le retour d'un collègue

---

## Q1: Pourquoi utiliser une image seed dans le déploiement?

**Réponse:**
> "L'image seed pré-charge des **données de test** dans la base de données au démarrage. 
>
> Pourquoi? Pour la **démo**: on a besoin de clients existants (Alice, Bob), de portfolios avec des fonds, et de symboles de marché (AAPL, GOOGL) pour montrer les use cases.
>
> Sans seed, je devrais créer manuellement chaque entité avant de démontrer. Le seed automatise ça et garantit un **environnement reproductible**.
>
> **Commande:** `docker compose exec web rails db:seed`"

---

## Q1b: Explique ton déploiement Docker

**Réponse:**
> "J'utilise **Docker Compose** avec plusieurs fichiers overlay:
>
> | Fichier | Services | Rôle |
> |---------|----------|------|
> | `docker-compose.yml` | web, postgres, redis | Base de l'app |
> | `docker-compose.gateway.yml` | kong | API Gateway |
> | `docker-compose.lb.yml` | nginx, web1-3 | Load Balancing |
> | `docker-compose.observability.yml` | prometheus, grafana | Monitoring |
>
> **Pourquoi plusieurs fichiers?** Séparation des préoccupations. Je peux lancer juste la base pour dev, ou tout pour la démo.
>
> **Commande complète:**
> ```bash
> docker compose -f docker-compose.yml \
>   -f docker-compose.gateway.yml \
>   -f docker-compose.lb.yml \
>   -f docker-compose.observability.yml up -d
> ```
>
> **Réseau:** Tous les services sont sur le même réseau Docker `brokerx_default`."

---

## Q2: As-tu implémenté tous les Use Cases?

**Réponse:**
> "Oui, les **8 Use Cases** sont implémentés:
>
> | UC | Description | Status |
> |----|-------------|--------|
> | UC-01 | Inscription & Vérification email | Fait |
> | UC-02 | Authentification MFA | Fait |
> | UC-03 | Dépôt de fonds (idempotent) | Fait |
> | UC-04 | Données marché temps réel | Fait |
> | UC-05 | Placement d'ordre | Fait |
> | UC-06 | Modifier/Annuler ordre | Fait |
> | UC-07 | Appariement d'ordres | Fait |
> | UC-08 | Confirmations & Notifications | Fait |
>
> Chaque UC est testable via l'API et documenté dans Swagger."

---

## Q3: Parle-moi de ta couverture de test

**Réponse:**
> "On a plusieurs niveaux de tests:
>
> - **Tests unitaires:** Pour le TradingSaga (6 tests), les Value Objects, les Use Cases
> - **Tests d'intégration:** Pour les repositories, les controllers API
> - **Tests de charge:** k6 avec 3 scripts (smoke, gateway, direct)
>
> La couverture n'est pas à 100%, mais les **chemins critiques** sont couverts: le Saga avec ses compensations, l'authentification MFA, les dépôts idempotents.
>
> En prod, on ajouterait des tests end-to-end avec Cypress ou Playwright."

---

## Q4: Explique ton Load Balancing

**Réponse:**
> "On utilise **Nginx** comme load balancer devant 3 instances Rails.
>
> **Configuration:**
> ```nginx
> upstream brokerx {
>     least_conn;
>     server web1:3000;
>     server web2:3000;
>     server web3:3000;
> }
> ```
>
> **Algorithme least_conn:** Envoie chaque requête vers le serveur avec le **moins de connexions actives**. C'est mieux que round-robin pour des requêtes de durées variables.
>
> **Scalabilité:** On peut ajouter web4, web5... sans toucher au code, juste la config Nginx."

---

## Q5: Explique ton API Gateway

**Réponse:**
> "On utilise **Kong** en mode DB-less comme API Gateway.
>
> **Rôle de Kong:**
> - **Authentification:** Valide le JWT et l'API key
> - **Rate Limiting:** 100 req/min par IP
> - **Routing:** /api/v1/orders → service orders
> - **CORS:** Gère les origines autorisées
> - **Métriques:** Expose /metrics pour Prometheus
>
> **Pourquoi Kong?** Centralise la sécurité. Sans Gateway, chaque service devrait implémenter l'auth, le rate limiting... c'est dupliqué et source d'erreurs.
>
> **DB-less:** Toute la config est dans `kong.yml`, versionné dans Git. Pas de base de données supplémentaire."

---

## Q6: C'est quoi la différence entre les deux types de Saga?

**Réponse:**
> "Il existe **2 types de Saga**:
>
> | Type | Orchestration | Chorégraphie |
> |------|---------------|--------------|
> | **Coordination** | Un orchestrateur central | Chaque service réagit aux événements |
> | **Couplage** | Services découplés de l'orchestrateur | Services couplés entre eux |
> | **Complexité** | Logique centralisée | Logique distribuée |
> | **Debugging** | Facile (un seul point) | Difficile (flux distribué) |
>
> **Mon choix: Orchestration** avec TradingSaga.
>
> **Pourquoi?** 
> - Plus facile à comprendre et debugger
> - La logique de compensation est centralisée
> - Meilleur pour un projet académique
>
> En production avec beaucoup de services, la **chorégraphie** avec Kafka serait plus scalable."

---

## Q7: Parle-moi de Kafka (même si tu ne l'utilises pas)

**Réponse:**
> "Je n'utilise **pas Kafka** dans ce projet, mais je connais son rôle.
>
> **Kafka** est un **message broker** distribué pour:
> - Communication asynchrone entre services
> - Event streaming
> - Découplage producteur/consommateur
>
> **Dans mon projet:** J'utilise le **Outbox Pattern** avec une table PostgreSQL pour stocker les événements. Un worker les lit et les traite.
>
> **Pourquoi pas Kafka?**
> - Complexité supplémentaire pour une démo
> - L'Outbox Pattern suffit pour montrer le concept
>
> **En production:** Kafka remplacerait l'Outbox pour plus de scalabilité et de résilience."

---

## Q8: Si j'annule un ordre, est-ce qu'il y a un rollback?

**Réponse:**
> "Oui! C'est exactement le **Saga Pattern avec compensation**.
>
> **Scénario:** Un ordre est créé, les fonds sont réservés, puis quelque chose échoue.
>
> **Rollback (Compensation):**
> 1. On annule l'ordre → status passe à 'cancelled'
> 2. On libère les fonds réservés → retour au portfolio
>
> **Code:**
> ```ruby
> def compensate!
>   @completed_steps.reverse.each do |step|
>     case step
>     when :create_order
>       cancel_order!
>     when :reserve_funds
>       release_funds!
>     end
>   end
> end
> ```
>
> **Important:** La compensation s'exécute dans l'**ordre inverse** des étapes complétées. C'est ça qui garantit la cohérence."

---

## Q9: Explique-moi les métriques

**Réponse:**
> "On collecte des métriques avec **Prometheus** et on visualise avec **Grafana**.
>
> **Métriques principales (Golden Signals):**
>
> | Métrique | Ce qu'on mesure | Exemple |
> |----------|-----------------|---------|
> | **Latency** | Temps de réponse | p95 = 35ms |
> | **Traffic** | Requêtes/seconde | 50 req/s |
> | **Errors** | Taux d'erreurs | 0% |
> | **Saturation** | Utilisation ressources | CPU < 80% |
>
> **Métriques custom:**
> - `http_requests_total` — Compteur de requêtes par endpoint
> - `http_request_duration_seconds` — Histogramme des latences
> - `websocket_connections` — Gauge des connexions WS actives
>
> **Pourquoi ces métriques?** Avec les 4 Golden Signals, on détecte 95% des problèmes en production."

---

## Q10: Montre-moi ton Dashboard Grafana

**Réponse (à montrer en live):**
> "Voici mon dashboard Grafana avec les Golden Signals.
>
> *Ouvrir http://localhost:3001*
>
> **Ce qu'on voit:**
> - **Panneau Latency:** p50, p95, p99 des temps de réponse
> - **Panneau Traffic:** Requêtes par seconde
> - **Panneau Errors:** Taux d'erreurs HTTP 5xx
> - **Panneau par Service:** Métriques Kong, Rails, PostgreSQL
>
> **Résultats des tests k6:**
> - Latence p95: 35ms (objectif < 100ms)
> - Erreurs: 0%
> - Throughput: ~50 req/s
>
> Le dashboard se rafraîchit toutes les 5 secondes pour du monitoring temps réel."

---

## RÉSUMÉ RAPIDE (Mémo)

| Question | Réponse en 1 phrase |
|----------|---------------------|
| **Seed** | Données de test pré-chargées pour la démo |
| **Use Cases** | 8 UC implémentés (UC-01 à UC-08) |
| **Tests** | Unitaires + intégration + charge k6 |
| **Load Balancing** | Nginx least_conn devant 3 instances |
| **API Gateway** | Kong DB-less centralise auth/routing |
| **Saga types** | Orchestration (centralisé) vs Chorégraphie (événements) |
| **Kafka** | Pas utilisé, Outbox Pattern à la place |
| **Rollback** | Compensation dans l'ordre inverse |
| **Métriques** | Golden Signals: Latency, Traffic, Errors, Saturation |
| **Grafana** | Dashboard temps réel avec panels par service |

---

## CONSEIL

Ton collègue dit que ça a duré **30 min au lieu de 5 min**. Ça veut dire que le prof creuse en profondeur.

**Stratégie:**
1. Réponds **concis** d'abord (30 sec)
2. Attends qu'il demande plus de détails
3. Ne te perds pas dans les explications trop longues
4. Si tu ne sais pas: "Je n'ai pas exploré ce point, mais je pense que..."
