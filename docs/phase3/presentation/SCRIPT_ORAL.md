# Script Oral - Présentation BrokerX (10 min)
## Phases 1, 2 & 3 — À lire/mémoriser pour la vidéo

---

## [0:00 - 0:15] SLIDE 1: Titre

> "Bonjour, je suis Reda El Mansouri. Je vais vous présenter BrokerX, une plateforme de courtage en ligne que j'ai développée en trois phases dans le cadre du cours LOG430 Architecture Logicielle."

---

## [0:15 - 0:30] SLIDE 2: Vue d'ensemble

> "Le projet implémente 8 cas d'usage répartis en 3 phases. 
> - Phase 1 pose les **fondations avec DDD**
> - Phase 2 ajoute l'**API Gateway et le temps réel**
> - Phase 3 apporte la **résilience avec le Saga Pattern et la scalabilité**"

---

## [0:30 - 1:00] SLIDE 3: Architecture Globale

*Pointer le diagramme*

> "Voici l'architecture finale du système. 
>
> En entrée, **Kong API Gateway** gère l'authentification JWT et le rate limiting.
> 
> **Nginx** en load balancer distribue les requêtes entre 3 instances Rails avec l'algorithme least-conn.
>
> **PostgreSQL** pour la persistance, **Redis** pour le cache et les sessions.
>
> **Prometheus et Grafana** pour l'observabilité.
>
> Et **ActionCable** pour les WebSockets temps réel."

---

# 🔵 PHASE 1 (1:00 - 3:00)

## [1:00 - 1:20] SLIDE 4: Phase 1 - Objectifs

> "Commençons par la Phase 1. L'objectif était de poser des **fondations solides**.
>
> On a implémenté l'**inscription avec vérification email**, l'**authentification MFA** en 2 étapes, et un **prototype de placement d'ordre**.
>
> L'approche choisie: **Domain-Driven Design**."

---

## [1:20 - 1:50] SLIDE 5: Architecture DDD

*Pointer la structure de dossiers*

> "**Pourquoi DDD?** Pour séparer clairement le métier de la technique.
>
> Le dossier **Domain** contient nos entités métier: Client, Portfolio, et les Value Objects comme Email et Money. C'est le cœur qui ne dépend de rien.
>
> Le dossier **Application** contient les Use Cases: RegisterClient, AuthenticateUser.
>
> Le dossier **Infrastructure** contient les implémentations concrètes: les repositories ActiveRecord, les controllers.
>
> L'avantage? Si demain on change de base de données, seule la couche Infrastructure change. Le Domain reste intact."

---

## [1:50 - 2:30] SLIDES 6-7: Authentification MFA

*Pointer le diagramme de séquence*

> "Pour l'authentification, on a implémenté un **flux MFA en 2 étapes**.
>
> **Étape 1:** L'utilisateur envoie son email et mot de passe. Le serveur génère un code MFA à 6 chiffres et l'envoie par email. Ce code **expire en 10 minutes**.
>
> **Étape 2:** L'utilisateur renvoie ce code. Le serveur le vérifie, et **seulement là** il génère le JWT.
>
> **Pourquoi 2 étapes?** Même si le mot de passe est compromis, l'attaquant a besoin d'accéder à l'email. C'est de la défense en profondeur."

---

## [2:30 - 3:00] Transition Phase 2

> "Avec ces fondations DDD solides, on pouvait passer à la Phase 2."

---

# 🟢 PHASE 2 (3:00 - 5:00)

## [3:00 - 3:15] SLIDE 8: Phase 2 - Objectifs

> "Phase 2, l'objectif était d'ajouter une **couche d'infrastructure moderne**.
>
> On a implémenté:
> - **Kong** comme API Gateway
> - **ActionCable** pour le temps réel
> - Le **pattern d'idempotence** pour les dépôts de fonds"

---

## [3:15 - 3:45] SLIDE 9: Kong API Gateway

*Pointer le tableau comparatif*

> "**Pourquoi une API Gateway?** 
>
> Sans Gateway, chaque service doit gérer l'authentification, les CORS, le rate limiting. C'est dupliqué et difficile à maintenir.
>
> Avec **Kong**, tout est **centralisé**. Un seul point d'entrée, une seule configuration. Kong valide le JWT, applique le rate limiting, gère les CORS, et route vers le bon service.
>
> On utilise le mode **DB-less**: toute la config est dans un fichier YAML versionné. Pas de base de données supplémentaire."

---

## [3:45 - 4:15] SLIDE 10: ActionCable WebSocket

> "Pour les **données de marché en temps réel**, UC-04, on avait le choix entre polling et WebSocket.
>
> Le **polling**, c'est le client qui demande les prix toutes les X secondes. Inefficace: beaucoup de requêtes, même quand rien n'a changé.
>
> Avec **ActionCable et WebSocket**, c'est le **serveur qui pousse** les nouveaux prix. Le client s'abonne une fois, et il reçoit les updates automatiquement.
>
> Résultat: latence minimale, moins de trafic réseau."

---

## [4:15 - 5:00] SLIDES 11-12: Idempotence

*Pointer le code HTTP*

> "UC-03, le **dépôt de fonds**. Un problème classique: le client fait un dépôt de 1000$, le réseau coupe, il retry. Sans protection, **le dépôt est dupliqué**: 2000$ au lieu de 1000$.
>
> La solution: l'**Idempotency-Key**. Le client génère un ID unique et l'envoie dans le header. Le serveur stocke cette clé dans **Redis**.
>
> Si la même clé revient, le serveur **retourne la réponse mise en cache** sans retraiter. Le dépôt n'est fait qu'une seule fois.
>
> C'est un pattern standard utilisé par Stripe et tous les systèmes de paiement."

---

# 🔴 PHASE 3 (5:00 - 7:30)

## [5:00 - 5:15] SLIDE 13: Phase 3 - Objectifs

> "Phase 3, c'est le **cœur technique du projet**.
>
> On a implémenté:
> - Le **Saga Pattern** pour les transactions distribuées
> - Le **Load Balancing** pour la scalabilité
> - Et l'**observabilité complète** avec Prometheus et Grafana"

---

## [5:15 - 6:00] SLIDES 14-15: Saga Pattern - Justification

> "**Le problème**: quand un utilisateur place un ordre d'achat, on doit faire **plusieurs opérations**:
> 1. Valider l'ordre
> 2. Réserver les fonds du client
> 3. Créer l'ordre en base de données
> 4. Le soumettre au moteur d'appariement
>
> Si l'**étape 4 échoue**, qu'est-ce qu'on fait? Les fonds sont déjà réservés, l'ordre est en base. Il faut **annuler les étapes précédentes**.
>
> C'est exactement ce que fait le **Saga Pattern**: une séquence d'étapes avec **compensation automatique** en cas d'échec.
>
> **Pourquoi pas un Two-Phase Commit?** Le 2PC est bloquant: tous les participants attendent que les autres répondent. Ça ne scale pas. Le Saga est **asynchrone** et permet la compensation indépendante."

---

## [6:00 - 6:30] SLIDE 16: TradingSaga Flow

*Pointer le diagramme de séquence*

> "Voici le flux de notre **TradingSaga**.
>
> 4 étapes dans l'ordre: validate, reserve_funds, create_order, submit_to_matching.
>
> Si l'étape 4 échoue, on **compense dans l'ordre inverse**: d'abord on annule l'ordre, puis on libère les fonds réservés.
>
> Le client retrouve son argent, le système reste **cohérent**. C'est ce qu'on appelle la **cohérence éventuelle**."

---

## [6:30 - 7:00] SLIDE 17: Load Balancing

*Pointer le diagramme*

> "Pour la **scalabilité horizontale**, on utilise Nginx comme load balancer devant 3 instances Rails.
>
> L'algorithme choisi: **least_conn**. Pourquoi pas round-robin? Dans une app de trading, certaines requêtes sont rapides, d'autres plus longues. Least_conn envoie chaque nouvelle requête vers le **serveur le moins chargé**.
>
> L'avantage: on peut **ajouter des instances** sans toucher au code. On scale horizontalement juste en modifiant le docker-compose."

---

## [7:00 - 7:30] SLIDE 18: Observabilité

*Pointer le dashboard Grafana*

> "L'observabilité est **critique** pour opérer un système en production.
>
> **Prometheus** collecte les métriques: latence, throughput, erreurs, utilisation CPU.
>
> **Grafana** visualise tout ça. On monitore les **4 Golden Signals** définis par Google SRE: Latency, Traffic, Errors, Saturation.
>
> Avec ces 4 métriques, on peut **détecter n'importe quel problème** en quelques secondes."

---

# 🎬 DÉMO LIVE (7:30 - 9:30)

## [7:30 - 9:30] DÉMO SUR L'INTERFACE WEB

> "Passons à la démo. Je vais vous montrer le **flux complet** directement sur l'interface web."

---

### Partie 1: Création de compte + MFA (50 sec)

*Ouvrir le navigateur sur http://localhost:3000*

> "Voici la page d'accueil de BrokerX."

*Cliquer sur "Créer un compte" (bouton vert)*

> "Je crée un nouveau client. Prénom, nom, email, date de naissance, mot de passe."

*Remplir le formulaire et soumettre*

> "Le compte est créé. Un **code de vérification** a été envoyé par email."

*Entrer le code dans le prompt (visible dans les logs Docker)*

> "Je vérifie mon email... le compte est maintenant **activé**."

*Cliquer sur "Se connecter"*

> "Je me connecte avec mes identifiants... le serveur m'envoie un **code MFA**."

*Entrer le code MFA dans le prompt*

> "Je saisis le code... et me voilà **authentifié**. Phase 1 validée: inscription et MFA fonctionnels."

---

### Partie 2: Portfolio + Dépôt (30 sec)

*On est redirigé vers /orders, cliquer sur "Mon portefeuille" dans le header*

> "Je suis maintenant sur mon **portfolio**. On voit mon solde: disponible, réservé, total."

*Entrer 10000 dans le champ montant et cliquer "Déposer"*

> "Je fais un **dépôt virtuel** de 10 000$... Le solde est mis à jour instantanément."

> "Notez que l'**idempotence** est gérée côté serveur: si je rechargeais la page et renvoyais le même dépôt, il ne serait pas dupliqué."

---

### Partie 3: Placement d'ordre + Temps réel (40 sec)

*Cliquer sur "Passer un ordre" dans le header*

> "Voici l'interface de trading. On voit le **Market Panel** avec les prix en temps réel via **WebSocket**."

*Montrer les quotes qui bougent dans le Market Panel*

> "Les prix se mettent à jour automatiquement grâce à **ActionCable**. Pas de polling, c'est le serveur qui **pousse** les données."

*Remplir: AAPL, Type: limit, Direction: buy, Quantité: 100, Prix: 150*

> "Je place un **ordre limite** d'achat: 100 actions Apple à 150$."

*Cliquer "Envoyer l'ordre"*

> "L'ordre est créé! Derrière, le **TradingSaga** s'est exécuté: validation, réservation des fonds, création, soumission au matching engine."

*Montrer le tableau des ordres avec le nouvel ordre*

> "L'ordre apparaît dans mon tableau avec son statut."

---

### Partie 4: Modification + Annulation (30 sec)

*Dans le tableau, modifier la quantité de l'ordre (changer 100 → 50)*

> "Je peux **modifier** mon ordre. Je change la quantité de 100 à 50 actions."

*Cliquer "Modifier"*

> "La modification est validée. Le **lock_version** a changé: c'est le **contrôle de concurrence optimiste**."

*Cliquer "Annuler" sur l'ordre*

> "Et je peux **annuler** l'ordre. Les fonds réservés sont **libérés** automatiquement par compensation."

---

### Partie 5: Observabilité Grafana (20 sec)

*Ouvrir un nouvel onglet: http://localhost:3001*

> "Enfin, **Grafana** pour l'observabilité."

*Montrer le dashboard avec les métriques*

> "On voit les **4 Golden Signals**: latence, trafic, erreurs, saturation. Toutes mes actions sont tracées. Zéro erreur."

---

# CONCLUSION (9:30 - 10:00)

## [9:30 - 9:45] SLIDE 20: Résultats k6

> "Nos tests de charge **k6** confirment les bonnes performances: latence p95 de 35 millisecondes, zéro erreur HTTP."

---

## [9:45 - 10:00] SLIDES 21-24: Conclusion

> "En résumé, en **3 phases**, on est passé de fondations DDD simples à une architecture distribuée résiliente.
>
> - Phase 1: **DDD et Repository Pattern**
> - Phase 2: **API Gateway et temps réel**
> - Phase 3: **Saga Pattern et Load Balancing**
>
> 10 ADRs documentent chaque décision architecturale.
>
> **Merci** pour votre attention. Je suis prêt pour vos questions."

---

## 📝 CHECKLIST AVANT ENREGISTREMENT

```bash
# 1. Démarrer l'environnement complet
cd /Users/redaelmansouri/Documents/ETS/A25/LOG430/brokerx
docker compose -f docker-compose.yml \
  -f docker-compose.gateway.yml \
  -f docker-compose.lb.yml \
  -f docker-compose.observability.yml up -d --scale app=3

# 2. Vérifier que tout est UP
docker compose ps

# 3. Attendre que tout soit prêt (~30 sec)
sleep 30
```

---

## 🌐 ONGLETS À PRÉPARER

| Onglet | URL | Usage |
|--------|-----|-------|
| 1. BrokerX | http://localhost:3000 | Page d'accueil (démo principale) |
| 2. Grafana | http://localhost:3001 | Dashboard observabilité |
| 3. Terminal | - | Voir les logs/codes MFA |

---

## 🔐 RÉCUPÉRER LES CODES (MFA / Vérification)

Les codes sont visibles dans les logs Docker:

```bash
# Voir les logs en temps réel (pour récupérer les codes)
docker compose logs -f web | grep -E "(MFA|verification|code)"
```

**Astuce:** Garder ce terminal visible sur un 2e écran ou en split-screen pendant l'enregistrement.

---

## 🎬 FLOW DE DÉMO DÉTAILLÉ

### Préparation (avant d'enregistrer)
1. ✅ Docker compose up avec les 3 instances
2. ✅ Ouvrir http://localhost:3000 dans Chrome
3. ✅ Ouvrir http://localhost:3001 (Grafana) dans un 2e onglet
4. ✅ Terminal avec `docker compose logs -f web` visible
5. ✅ Vider le localStorage du navigateur (F12 → Application → Clear)

### Étapes de la démo

| Étape | Action | Ce qu'on montre |
|-------|--------|-----------------|
| 1 | Page d'accueil | Architecture visible, boutons Créer/Connecter |
| 2 | Créer un compte | Formulaire d'inscription |
| 3 | Code vérification | Lire dans les logs Docker |
| 4 | Se connecter | Login + MFA |
| 5 | Code MFA | Lire dans les logs Docker |
| 6 | Portfolio | Solde initial, formulaire dépôt |
| 7 | Dépôt 10 000$ | Mise à jour instantanée du solde |
| 8 | Page Ordres | Market Panel temps réel |
| 9 | Placer ordre LIMIT | Formulaire + soumission |
| 10 | Voir ordre dans tableau | Statut, version |
| 11 | Modifier quantité | Bouton Modifier |
| 12 | Annuler ordre | Bouton Annuler |
| 13 | Grafana | Dashboard métriques |

---

## ⏱️ TIMING DÉMO (2 min total)

| Temps | Action |
|-------|--------|
| 7:30 | Ouvrir navigateur, page d'accueil |
| 7:40 | Créer compte (formulaire) |
| 8:00 | Vérification email + Login MFA |
| 8:20 | Portfolio + Dépôt |
| 8:40 | Page Ordres + Temps réel |
| 9:00 | Placer ordre LIMIT |
| 9:15 | Modifier + Annuler ordre |
| 9:30 | Grafana → Conclusion |

---

## 🚨 EN CAS DE PROBLÈME

| Problème | Solution |
|----------|----------|
| Code MFA pas visible | `docker compose logs web \| tail -50` |
| WebSocket déconnecté | Rafraîchir la page |
| Erreur 401 | Vider localStorage, se reconnecter |
| Grafana vide | Attendre 30 sec, les métriques arrivent |
| Rate limit 429 | Attendre 60 sec ou restart |

---

## ⏱️ POINTS DE CONTRÔLE PRÉSENTATION

| Temps | Tu dois être à... |
|-------|-------------------|
| 1:00 | Début Phase 1 |
| 3:00 | Début Phase 2 |
| 5:00 | Début Phase 3 |
| 7:30 | Début DÉMO WEB |
| 9:30 | Conclusion |

**Si en retard:** Skip la modification d'ordre, passe directement à l'annulation
**Si en avance:** Montre plus de détails dans le Market Panel WebSocket
