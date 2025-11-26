# Plan de Présentation Orale - BrokerX (Phases 1, 2 & 3)
## Durée: 10 minutes (vidéo) + 5 min Q&A

---

## 🎯 Structure Recommandée (24 slides → 10 min)

| Section | Slides | Durée | Contenu |
|---------|--------|-------|---------|
| Intro | 1-2 | 30s | Titre + Vue d'ensemble |
| Architecture | 3 | 30s | Architecture globale |
| **Phase 1** | 4-7 | 2min | DDD, MFA, Repository |
| **Phase 2** | 8-12 | 2min | Gateway, WebSocket, Idempotence |
| **Phase 3** | 13-18 | 2min30 | Saga, Load Balancing, Observabilité |
| **DÉMO** | 19 | 2min | Scénario complet |
| Conclusion | 20-24 | 30s | Résultats + Conclusion |

**Total: ~10 minutes**

---

## ⏱️ TIMING DÉTAILLÉ

| Temps | Slide | Contenu |
|-------|-------|---------|
| 0:00-0:15 | 1 | Titre |
| 0:15-0:30 | 2 | Vue d'ensemble (3 phases) |
| 0:30-1:00 | 3 | Architecture globale |
| **1:00-3:00** | 4-7 | **PHASE 1** |
| **3:00-5:00** | 8-12 | **PHASE 2** |
| **5:00-7:30** | 13-18 | **PHASE 3** |
| **7:30-9:30** | 19 | **DÉMO LIVE** |
| 9:30-10:00 | 20-24 | Résultats + Conclusion |

---

## 📊 SLIDE 1 - Titre (15 sec)

**Contenu:**
```
🏦 BrokerX
Plateforme de Courtage en Ligne
Phases 1, 2 & 3 — Architecture Logicielle
```

**Script:**
> "Bonjour, je suis Reda El Mansouri. Je vais vous présenter BrokerX, une plateforme de courtage développée en 3 phases dans le cadre du cours LOG430."

---

## 📊 SLIDE 2 - Vue d'ensemble (15 sec)

**Contenu:**
```
8 Use Cases en 3 Phases:
- Phase 1: Fondations DDD (UC-01, UC-02, UC-05)
- Phase 2: Microservices & Temps réel (UC-03, UC-04, UC-06)
- Phase 3: Saga & Scalabilité (UC-07, UC-08)
```

**Script:**
> "On a implémenté 8 cas d'usage répartis en 3 phases. Phase 1 pose les fondations avec DDD, Phase 2 ajoute les microservices et le temps réel, Phase 3 apporte la résilience avec le Saga Pattern."

---

## 📊 SLIDE 3 - Architecture Globale (30 sec)

**Contenu:** Diagramme ASCII de l'architecture

**Script:**
> "Voici l'architecture finale. Kong en API Gateway, Nginx en load balancer devant 3 instances Rails, PostgreSQL et Redis pour la persistance, Prometheus et Grafana pour l'observabilité, et ActionCable pour le temps réel."

---

# 🔵 SECTION PHASE 1 (2 min)

## 📊 SLIDE 4 - Phase 1 Objectifs (20 sec)

**Script:**
> "Phase 1, c'était les fondations. On a implémenté l'inscription avec vérification email, l'authentification MFA en 2 étapes, et un prototype de placement d'ordre. L'approche choisie: Domain-Driven Design."

---

## 📊 SLIDE 5 - Architecture DDD (30 sec)

**Script:**
> "Pourquoi DDD? Pour séparer clairement le métier de la technique. Le dossier Domain contient les entités Client et Portfolio, les Value Objects comme Email et Money. Application contient les Use Cases. Et Infrastructure contient les implémentations concrètes avec ActiveRecord."

---

## 📊 SLIDE 6-7 - Authentification MFA (40 sec)

**Script:**
> "Pour l'authentification, on a implémenté un flux MFA en 2 étapes. L'utilisateur envoie son email et mot de passe, il reçoit un code MFA par email qui expire en 10 minutes. Il renvoie ce code, et seulement là il obtient son JWT. C'est plus sécurisé qu'un simple login/password."

---

# 🟢 SECTION PHASE 2 (2 min)

## 📊 SLIDE 8 - Phase 2 Objectifs (15 sec)

**Script:**
> "Phase 2, on a ajouté Kong comme API Gateway, ActionCable pour le temps réel, et le pattern d'idempotence pour les dépôts de fonds."

---

## 📊 SLIDE 9 - Kong API Gateway (30 sec)

**Script:**
> "Pourquoi une Gateway? Sans Gateway, chaque service doit gérer l'authentification, les CORS, le rate limiting. Avec Kong, tout est centralisé. Un seul point d'entrée, une seule config. On utilise le mode DB-less avec un fichier YAML déclaratif."

---

## 📊 SLIDE 10 - ActionCable WebSocket (30 sec)

**Script:**
> "Pour les données de marché en temps réel, plutôt que du polling, on utilise WebSocket avec ActionCable. Le serveur pousse les nouveaux prix toutes les secondes. Le client n'a plus besoin de faire des requêtes, il reçoit les updates automatiquement."

---

## 📊 SLIDE 11-12 - Idempotence (30 sec)

**Script:**
> "Le problème des dépôts: si le réseau coupe pendant une requête, le client va retry. Sans protection, le dépôt est dupliqué. Solution: l'Idempotency-Key. Le client envoie un ID unique, stocké dans Redis. Si la même clé revient, on retourne la même réponse sans retraiter."

---

# 🔴 SECTION PHASE 3 (2 min 30)

## 📊 SLIDE 13 - Phase 3 Objectifs (15 sec)

**Script:**
> "Phase 3, c'est le cœur du projet: le Saga Pattern pour les transactions distribuées, et le Load Balancing pour la scalabilité."

---

## 📊 SLIDE 14-15 - Saga Pattern Justification (45 sec)

**Script:**
> "Quand un utilisateur place un ordre d'achat, on doit faire plusieurs opérations: valider l'ordre, réserver les fonds, créer l'ordre en base, le soumettre au matching. Si une étape échoue à mi-chemin, il faut annuler les précédentes. C'est exactement ce que fait le Saga Pattern.

> L'alternative serait un Two-Phase Commit, mais c'est bloquant et ça scale pas. Le Saga est asynchrone et permet la compensation automatique."

---

## 📊 SLIDE 16 - TradingSaga Flow (30 sec)

*Montrer le diagramme de séquence*

**Script:**
> "Voici le flux du TradingSaga. 4 étapes dans l'ordre, et si la dernière échoue, on compense dans l'ordre inverse: on annule l'ordre, puis on libère les fonds. Le client retrouve son argent, le système reste cohérent."

---

## 📊 SLIDE 17 - Load Balancing (30 sec)

**Script:**
> "Pour la scalabilité, Nginx distribue la charge entre 3 instances avec l'algorithme least-conn. Il envoie vers le serveur le moins chargé. On peut ajouter des instances sans toucher au code."

---

## 📊 SLIDE 18 - Observabilité (30 sec)

**Script:**
> "Prometheus collecte les métriques, Grafana visualise. On monitore les 4 Golden Signals: latence, trafic, erreurs, saturation. Avec ça, on détecte immédiatement si quelque chose va mal."

---

# 🎬 SECTION DÉMO (2 min)

## 📊 SLIDE 19 - DÉMO LIVE

### Scénario de démo (3 parties):

**Partie 1: Phase 1 - Login MFA (40 sec)**
```bash
# Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "apikey: brokerx-key-123" \
  -d '{"email":"alice@example.com","password":"password123"}'

# Verify MFA
curl -X POST http://localhost:8000/api/v1/auth/verify_mfa \
  -H "apikey: brokerx-key-123" \
  -d '{"email":"alice@example.com","mfa_code":"CODE"}'
```

**Script:**
> "Je commence par le login MFA. J'envoie mes identifiants, je reçois un code MFA, je le vérifie, et j'obtiens mon JWT."

---

**Partie 2: Phase 2 - Dépôt idempotent (30 sec)**
```bash
# Dépôt avec idempotency key
curl -X POST http://localhost:8000/api/v1/portfolios/1/deposit \
  -H "Authorization: Bearer JWT" \
  -H "Idempotency-Key: demo-123" \
  -d '{"amount":1000,"currency":"USD"}'
```

**Script:**
> "Maintenant un dépôt avec idempotency key. Si je renvoie exactement la même requête, le serveur me retourne la même réponse sans redéposer."

---

**Partie 3: Phase 3 - Ordre + Grafana (50 sec)**
```bash
# Placer un ordre (déclenche TradingSaga)
curl -X POST http://localhost:8000/api/v1/orders \
  -H "Authorization: Bearer JWT" \
  -d '{"order":{"symbol":"AAPL","side":"buy","quantity":10,"price":150}}'
```

**Script:**
> "Je place un ordre d'achat. Le TradingSaga s'exécute: validation, réservation, création, soumission. Et dans Grafana, on voit les métriques en temps réel."

*Ouvrir Grafana et montrer le dashboard*

---

## 📊 SLIDES 20-24 - Conclusion (30 sec)

**Script:**
> "En résumé, nos tests k6 montrent une latence p95 de 35ms et zéro erreur. On a produit 10 ADRs pour documenter chaque décision architecturale.

> En 3 phases, on est passé de fondations DDD simples à une architecture distribuée résiliente avec Saga Pattern, Load Balancing et observabilité complète.

> Merci pour votre attention, je suis prêt pour les questions."

---

## 📁 ASSETS DISPONIBLES

### Diagrammes:
```
docs/phase3/puml/
├── trading_saga_sequence.png      ← Phase 3
├── load_balancing_architecture.png ← Phase 3
├── observability_stack.png        ← Phase 2-3
└── outbox_event_flow.png          ← Phase 3

docs/architecture/4plus1_views/
├── diagram_architect.png          ← Architecture globale
└── placement_ordre_w_validation.png ← Phase 1
```

### Screenshots:
```
docs/phase3/screenshots/
├── grafana_golden_signals.png     
├── grafana_kong_gateway_1.png     
└── prometheus_targets.png         
```

---

## 🎤 QUESTIONS POTENTIELLES

### Phase 1:
1. **Pourquoi DDD et pas MVC classique?**
   > "DDD sépare le métier de l'infra. Si on change de DB, seule la couche Infrastructure change."

2. **Pourquoi MFA en 2 étapes?**
   > "Sécurité renforcée. Même si le mot de passe est compromis, il faut le code MFA."

### Phase 2:
3. **Pourquoi Kong et pas Nginx seul?**
   > "Kong offre rate limiting, auth plugins et monitoring intégrés. Nginx fait juste du routing."

4. **Comment gérez-vous l'idempotence?**
   > "Clé unique stockée en Redis avec TTL. Si la clé existe, on retourne la réponse cachée."

### Phase 3:
5. **Pourquoi Saga et pas 2PC?**
   > "2PC est bloquant et ne scale pas. Saga est asynchrone et permet la compensation."

6. **Que se passe-t-il si la compensation échoue?**
   > "On log l'erreur et on retry. En dernier recours, intervention manuelle."

7. **Pourquoi least_conn et pas round-robin?**
   > "Certaines requêtes trading sont plus longues. Least_conn est plus intelligent."
