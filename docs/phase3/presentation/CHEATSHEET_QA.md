# Cheatsheet Q&A — BrokerX
## Questions Potentielles du Professeur

---

## PHASE 1 — DDD & Authentification

### Q1: Pourquoi avoir choisi DDD plutôt qu'une architecture MVC classique?

**Réponse:**
> "MVC mélange souvent logique métier et infrastructure. Avec DDD, on a une **séparation claire**:
> - Le **Domain** contient les règles métier pures, sans dépendance technique
> - L'**Application** orchestre les use cases
> - L'**Infrastructure** implémente les détails techniques (DB, HTTP)
>
> **Avantage concret:** Si on change de base de données (PostgreSQL → MongoDB), seule la couche Infrastructure change. Le Domain reste intact."

---

### Q2: C'est quoi un Value Object? Pourquoi l'utiliser pour Email et Money?

**Réponse:**
> "Un Value Object est un objet **immuable** défini par ses attributs, pas par une identité.
>
> - `Email`: On valide le format une seule fois à la création. Impossible d'avoir un email invalide dans le système.
> - `Money`: On encapsule montant + devise. On évite les erreurs comme additionner des USD avec des EUR.
>
> **Avantage:** La validation est centralisée, pas dispersée dans tout le code."

---

### Q3: Pourquoi MFA en 2 étapes? Un simple JWT après login ne suffirait pas?

**Réponse:**
> "Le MFA ajoute une **couche de sécurité supplémentaire**. Même si le mot de passe est compromis (phishing, fuite), l'attaquant a besoin d'accéder à l'email pour obtenir le code.
>
> C'est de la **défense en profondeur**: plusieurs barrières plutôt qu'une seule.
>
> Le code expire en **10 minutes** pour limiter la fenêtre d'attaque."

---

### Q4: Comment fonctionne le Repository Pattern dans votre projet?

**Réponse:**
> "Le Repository **abstrait la persistance**. Le Domain définit une interface:
> ```ruby
> # Interface (Domain)
> class ClientRepository
>   def find_by_id(id); end
>   def save(client); end
> end
> ```
>
> L'Infrastructure implémente:
> ```ruby
> # Implémentation (Infrastructure)
> class ActiveRecordClientRepository
>   def find_by_id(id)
>     ClientRecord.find(id)
>   end
> end
> ```
>
> **Avantage:** On peut tester le Domain avec un FakeRepository en mémoire, sans toucher à la DB."

---

## PHASE 2 — Gateway & Temps Réel

### Q5: Pourquoi Kong et pas juste Nginx comme reverse proxy?

**Réponse:**
> "Nginx fait du **routing basique**. Kong offre en plus:
> - **Authentification JWT** intégrée (plugin)
> - **Rate limiting** par IP ou par clé API
> - **Métriques Prometheus** out-of-the-box
> - **Plugins** extensibles (CORS, logging, etc.)
>
> Avec Kong, on centralise la sécurité. Sans Gateway, chaque service devrait implémenter l'auth, le rate limiting... c'est dupliqué et risqué."

---

### Q6: Pourquoi DB-less pour Kong? C'est pas limité?

**Réponse:**
> "En mode DB-less, toute la config est dans un **fichier YAML versionné** (kong.yml).
>
> **Avantages:**
> - Pas de base de données supplémentaire à maintenir
> - Config versionnée dans Git
> - Déploiement déclaratif (Infrastructure as Code)
>
> **Limitation:** Pas de modification dynamique à chaud. Mais pour notre cas, c'est suffisant."

---

### Q7: WebSocket vs Polling — Pourquoi ActionCable?

**Réponse:**
> "**Polling:** Le client demande les prix toutes les X secondes.
> - Beaucoup de requêtes inutiles
> - Latence = intervalle de polling
>
> **WebSocket:** Le serveur **push** les updates.
> - Une seule connexion persistante
> - Latence minimale (temps réel)
> - Moins de trafic réseau
>
> Pour des données de marché qui changent chaque seconde, WebSocket est clairement plus adapté."

---

### Q8: Comment fonctionne l'idempotence pour les dépôts?

**Réponse:**
> "Le client génère un **Idempotency-Key** unique (ex: UUID) et l'envoie dans le header.
>
> **Flux:**
> 1. Requête arrive avec `Idempotency-Key: abc123`
> 2. On vérifie dans **Redis** si cette clé existe
> 3. Si non: on traite, on stocke la réponse dans Redis avec TTL 24h
> 4. Si oui: on retourne la **réponse cachée** sans retraiter
>
> **Résultat:** Même si le client retry 10 fois, le dépôt n'est fait qu'une seule fois."

---

## PHASE 3 — Saga & Scalabilité

### Q9: Pourquoi Saga Pattern et pas Two-Phase Commit (2PC)?

**Réponse:**
> "**2PC est bloquant:** Tous les participants doivent répondre avant de commit. Si un service est lent ou down, tout est bloqué.
>
> **Saga est asynchrone:** Chaque étape commit indépendamment. En cas d'échec, on exécute des **compensations** pour annuler les étapes précédentes.
>
> **Scalabilité:** 2PC ne scale pas dans un système distribué. Saga oui."

---

### Q10: Que se passe-t-il si une compensation échoue?

**Réponse:**
> "C'est un cas rare mais critique. Notre stratégie:
>
> 1. **Retry automatique** avec backoff exponentiel
> 2. **Dead Letter Queue** si les retries échouent
> 3. **Alerting** pour intervention manuelle
> 4. **Logs d'audit** pour tracer l'état de chaque étape
>
> En production, on ajouterait un **circuit breaker** pour éviter les cascades d'échecs."

---

### Q11: Expliquez le flux du TradingSaga

**Réponse:**
> "Quand un utilisateur place un ordre d'achat de 10 AAPL à 150$:
>
> 1. **Validate:** Vérifier que AAPL existe, quantité > 0
> 2. **Reserve Funds:** Bloquer 1500$ sur le portfolio (pas débité)
> 3. **Create Order:** Persister l'ordre en DB avec status 'pending'
> 4. **Submit to Matching:** Envoyer au moteur d'appariement
>
> **Si étape 4 échoue:**
> - Compensation 3: Annuler l'ordre (status → 'cancelled')
> - Compensation 2: Libérer les 1500$ réservés
>
> Le client retrouve ses fonds, le système reste cohérent."

---

### Q12: Pourquoi least_conn et pas round-robin pour le load balancing?

**Réponse:**
> "**Round-robin** distribue aveuglément: requête 1 → serveur A, requête 2 → serveur B, etc.
>
> **Problème:** Si une requête est longue (ex: rapport complexe), le serveur A est surchargé mais continue de recevoir des requêtes.
>
> **Least_conn** envoie vers le serveur avec le **moins de connexions actives**. C'est plus intelligent pour des requêtes de durées variables, typique en trading."

---

### Q13: C'est quoi le Outbox Pattern? Pourquoi l'utiliser?

**Réponse:**
> "**Problème:** On veut créer un ordre ET publier un événement. Si l'événement échoue après le commit DB, on a une incohérence.
>
> **Solution Outbox:**
> 1. Dans la **même transaction**, on insère l'ordre ET l'événement dans une table `outbox_events`
> 2. Un **worker** lit les événements `pending` et les publie
> 3. Une fois publié, on marque l'événement comme `processed`
>
> **Garantie:** L'ordre et l'événement sont atomiques. Pas de message perdu."

---

## OBSERVABILITÉ

### Q14: C'est quoi les Golden Signals?

**Réponse:**
> "4 métriques définies par **Google SRE** pour monitorer n'importe quel service:
>
> | Signal | Question |
> |--------|----------|
> | **Latency** | Combien de temps pour répondre? |
> | **Traffic** | Combien de requêtes/sec? |
> | **Errors** | Quel % d'erreurs? |
> | **Saturation** | Les ressources sont-elles épuisées? |
>
> Avec ces 4 métriques, on détecte **95% des problèmes** en production."

---

### Q15: Pourquoi Prometheus + Grafana et pas un autre stack?

**Réponse:**
> "**Prometheus:**
> - Pull-based (scrape les métriques)
> - Format standard (OpenMetrics)
> - Alerting intégré
> - Gratuit et open-source
>
> **Grafana:**
> - Dashboards flexibles
> - Supporte plusieurs datasources
> - Alerting visuel
>
> C'est le **standard de l'industrie** pour l'observabilité cloud-native. Kubernetes l'utilise par défaut."

---

## QUESTIONS GÉNÉRALES

### Q16: Quels sont les points faibles de votre architecture?

**Réponse honnête:**
> "Plusieurs points à améliorer en production:
>
> 1. **Base de données unique:** Tous les services partagent PostgreSQL. En vrai microservices, chaque service aurait sa DB.
>
> 2. **Matching Engine in-process:** Pour du vrai trading, il faudrait un service dédié avec queue (Kafka).
>
> 3. **Pas de circuit breaker:** Si un service est down, les autres pourraient être impactés.
>
> 4. **JWT sans refresh token:** En prod, on ajouterait des refresh tokens pour la rotation."

---

### Q17: Comment testez-vous le Saga Pattern?

**Réponse:**
> "On a **6 tests unitaires** pour le TradingSaga:
>
> 1. Test du happy path (toutes étapes OK)
> 2. Test échec validation → pas de réservation
> 3. Test échec réservation → pas d'ordre créé
> 4. Test échec création ordre → fonds libérés
> 5. Test échec matching → ordre annulé + fonds libérés
> 6. Test compensation complète
>
> Chaque test vérifie que la compensation est bien appelée et que l'état final est cohérent."

---

### Q18: Si vous deviez refaire le projet, que changeriez-vous?

**Réponse:**
> "Quelques améliorations:
>
> 1. **Event Sourcing** au lieu de CRUD pour l'audit complet
> 2. **Kafka** pour les événements au lieu de l'Outbox table
> 3. **GraphQL** pour l'API client (moins de requêtes)
> 4. **Kubernetes** pour l'orchestration au lieu de Docker Compose
>
> Mais pour une démo académique, l'architecture actuelle est suffisante et démontre bien les concepts."

---

### Q19: Comment gérez-vous la sécurité?

**Réponse:**
> "Plusieurs couches:
>
> | Couche | Mécanisme |
> |--------|-----------|
> | Gateway | API Key + JWT validation |
> | Auth | MFA 2 étapes |
> | Transport | HTTPS (en prod) |
> | Passwords | bcrypt hash |
> | Rate Limiting | Kong plugin |
> | CORS | Whitelist origines |
>
> On pourrait ajouter: WAF, audit logs, rotation des secrets."

---

### Q20: Votre architecture est-elle scalable?

**Réponse:**
> "**Horizontalement:** Oui
> - Load Balancer devant N instances Rails
> - Redis pour les sessions (stateless)
> - PostgreSQL avec read replicas possible
>
> **Verticalement:** Limitée
> - Le Matching Engine est in-process
> - La DB est un point de contention
>
> **Pour vraiment scaler:** Extraire le Matching en microservice, ajouter Kafka, sharding DB par client."

---

## MÉMO RAPIDE

| Concept | Définition en 1 phrase |
|---------|------------------------|
| **DDD** | Séparer métier et technique en couches |
| **Repository** | Abstraire l'accès aux données |
| **Value Object** | Objet immuable défini par ses attributs |
| **API Gateway** | Point d'entrée unique qui centralise auth/routing |
| **Saga** | Transaction distribuée avec compensation |
| **Outbox** | Garantir atomicité événement + DB |
| **Idempotence** | Même requête = même résultat |
| **Golden Signals** | 4 métriques pour monitorer un service |
| **least_conn** | Load balancing vers le serveur le moins chargé |

---

## TIPS POUR L'ORAL

1. **Si tu ne sais pas:** "C'est une bonne question, je n'ai pas exploré ce point en détail, mais je pense que..."

2. **Si tu te trompes:** Corrige-toi calmement, c'est normal

3. **Sois concis:** Réponds en 30-60 secondes max par question

4. **Utilise des exemples concrets:** "Par exemple, quand un utilisateur dépose 1000$..."

5. **Admets les limites:** "En production, on ajouterait..." montre ta maturité
