# UC-05 - Placement d'un ordre (marché/limite) avec contrôles pré-trade

## Métadonnées
- **Identifiant**: UC-05
- **Version**: 1.0
- **Statut**: Must-Have
- **Priorité**: Critique

## Objectif
Permettre aux clients de soumettre des ordres d'achat ou de vente (marché ou limite), qui seront validés par des contrôles pré-trade et insérés dans le moteur d'appariement.

## Acteurs
- **Principal**: Client (authentifié, portefeuille financé)
- **Secondaire**: 
  - Moteur de Règles Pré-trade
  - Gestion des Risques
  - Service Portefeuilles
  - Moteur d'Appariement

## Déclencheur
Le Client soumet un ordre depuis l'interface de trading.

## Préconditions
- Session client valide (authentifié)
- Portefeuille existant avec solde suffisant (pour achat)
- Instrument actif et tradable

## Postconditions (Succès)
- Ordre accepté et accusé de réception (ACK)
- Ordre placé dans le carnet interne
- Portefeuille mis à jour (engagements)
- Journal d'audit créé

## Postconditions (Échec)
- Ordre rejeté avec raison spécifique
- Aucune modification du portefeuille
- Journal d'audit avec motif de rejet

## Flux Principal (Succès)

1. **Client** renseigne les paramètres de l'ordre :
   - Symbol (instrument) : "AAPL", "MSFT", etc.
   - Sens : Achat ou Vente
   - Type : Marché ou Limite
   - Quantité : nombre d'actions (> 0)
   - Prix : obligatoire pour limite, ignoré pour marché
  ## Objectif
  Permettre aux clients de soumettre des ordres d'achat ou de vente (marché ou limite), validés par des contrôles pré-trade, avec réservation de fonds pour les achats, persistance et envoi au moteur d'appariement.

  ## Postconditions (Succès)
  - Ordre accepté et accusé de réception (ACK) avec `order_id` et `lock_version`
  - Ordre persistant (statut `new`) et mis en file auprès du moteur d'appariement
  - Portefeuille mis à jour (réservation de fonds pour les achats)

3. **Système** exécute les contrôles pré-trade :
     - Durée : DAY (défaut), GTC, IOC, FOK
   ### 3.1 - Contrôle pouvoir d'achat/marge
  2. **Système** normalise :
     - Symbol en majuscules
     - Génération d'un `order_id`
     - Pas de tick size dans ce prototype (prix décimal accepté)
   ### 3.2 - Règles de prix
  3. **Système** exécute les contrôles pré-trade (implémentés) :
   - **Limite**: Prix dans les bandes autorisées (±5% dernier cours)
     ### 3.1 - Contrôle pouvoir d'achat
     - **Achat** : Solde disponible ≥ (quantité × prix) — pour Marché, un prix par défaut est utilisé (prototype)
   ### 3.3 - Restrictions trading
     ### 3.2 - Règles de prix
     - **Limite** : Prix dans la bande autorisée [1.00, 10 000.00]
     - Tick size non enforcé dans ce prototype
   - Heures de trading respectées
     ### 3.4 - Sanity checks
     - Quantité strictement > 0 (entier)
   ### 3.5 - Sanity checks
  4. **Si tous les contrôles OK** :
     - Réserver les fonds (ACHAT) via le Repository Portefeuille
     - Persister l'ordre (statut `new`, `reserved_amount` pour ACHAT)
     - Envoyer au moteur d'appariement interne (thread en mémoire)
     - Retourner ACK JSON incluant `order_id`, `lock_version`
   - Système attribue OrderID unique
  ### A3 - Idempotence (non implémentée pour UC‑05)
  - Idempotence des ordres n’est pas implémentée dans ce prototype.
  - L’idempotence existe pour les dépôts (UC‑03) via `Idempotency-Key`.
5. **Moteur d'appariement** prend le relais (UC-07)
  ### E2 - Violation bande de prix
    - Message "Price outside valid trading band"

  ### E4 - (Non implémenté) Limites utilisateur
  Non enforcé dans ce prototype.
  - Routage immédiat vers matching
  - Contrôle pouvoir d'achat avec prix marché courant
  - **Résultat attendu** :
    - Ordre accepté (ACK JSON) avec `order_id`, `lock_version`
    - `reserved_amount` = 1 000€
  - Exécute la quantité possible immédiatement
  - Annule le reste non exécuté
  - **Résultat attendu** :
    - Statut HTTP 422
    - `errors` contient "Insufficient funds"
  - Renvoie le résultat précédent
  - Évite les doublons
  - **Résultat attendu** :
    - Statut HTTP 422
    - `errors` contient "Price outside valid trading band"
- **Condition**: Solde < montant ordre
- **Traitement**:
  ### CA-05.04 - (Non implémenté) Idempotence ordre
  Voir UC‑03 pour l’idempotence des dépôts.
- **Traitement**:
  ## Métriques
  - Latence ordre → ACK (observable via logs)
  - Taux de rejet par type (insufficient funds, price band, quantity)

  ## Aspects Sécurité
  - Authentification par JWT (header Authorization)
  - Validation côté serveur
  - Journalisation
  - Rejet immédiat
  ## Règles Métier (implémentées dans le prototype)
  - Prix limite dans [1.00, 10 000.00]
  - Quantité > 0 (entier)
  - Engagement immédiat des fonds (ACHAT)

  ---

  ## API — Placement d’ordre (implémentation actuelle)

  Endpoint : `POST /api/v1/orders`

  Headers : `Authorization: Bearer <token>`, `Content-Type: application/json`

  Body :
  ```json
  {
    "order": {
      "symbol": "AAPL",
      "order_type": "limit",
      "direction": "buy",
      "quantity": 10,
      "price": 100.0,
      "time_in_force": "DAY"
    }
  }
  ```

  Réponse 200 :
  ```json
  { "success": true, "order_id": 123, "lock_version": 0, "message": "Order accepted and queued for matching" }
  ```

  Réponse 422 (exemples) :
  ```json
  { "success": false, "errors": ["Insufficient funds"] }
  ```

  Voir aussi : UC‑06 pour modifier/annuler un ordre existant (optimistic locking).
  - Rejet immédiat
  - Message "Limite d'ordres simultanés atteinte"

## Critères d'Acceptation

### CA-05.01 - Ordre limite achat accepté
**Scenario**: Client avec solde suffisant
- **Précondition**: Solde portefeuille = 10 000€
- **Action**: Ordre achat 10 AAPL @ 100€ (total 1 000€)
- **Résultat attendu**:
  - Ordre accepté (ACK)
  - OrderID unique généré
  - Engagement de 1 000€ sur le portefeuille

### CA-05.02 - Ordre marché rejeté (solde insuffisant)
**Scenario**: Client avec solde insuffisant
- **Précondition**: Solde portefeuille = 500€
- **Action**: Ordre achat marché 10 AAPL (prix courant 100€ = 1 000€)
- **Résultat attendu**:
  - Ordre rejeté
  - Message "Solde insuffisant"
  - Code erreur INSUFFICIENT_FUNDS

### CA-05.03 - Ordre limite prix invalide
**Scenario**: Prix hors bandes
- **Précondition**: Dernier cours AAPL = 100€
- **Action**: Ordre achat 10 AAPL @ 50€ (50% below)
- **Résultat attendu**:
  - Ordre rejeté
  - Message "Prix hors limites autorisées"
  - Suggestion de bande valide : 95€-105€

### CA-05.04 - Idempotence ordre
**Scenario**: Double soumission même clientOrderId
- **Précondition**: Ordre déjà soumis avec clientOrderId="123"
- **Action**: Resoumission avec clientOrderId="123"
- **Résultat attendu**:
  - Renvoi du résultat original (ACK)
  - Pas de nouvel ordre créé
  - Journal d'idempotence

## Métriques
- Temps de traitement pré-trade (P95 < 100ms)
- Taux de rejet par type de violation
- Latence ordre → ACK

## Aspects Sécurité
- Validation côté serveur de tous les paramètres
- Journalisation immuable de toutes les décisions
- Idempotence pour éviter les doublons

## Règles Métier
- **RB-09**: Bande de prix = ±5% dernier cours
- **RB-10**: Tick size = 0.01€ pour tous les instruments
- **RB-11**: Ordre DAY expire en fin de session (18h00)
- **RB-12**: Short-selling interdit sauf autorisation explicite
- **RB-13**: Engagement immédiat des fonds à la soumission