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
   - Durée : DAY (valide journée), IOC (immédiat ou annulé)

2. **Système** normalise et horodate l'ordre :
   - Timestamp système en UTC (nanosecondes)
   - Génération OrderID unique
   - Normalisation format prix (arrondi tick size)

3. **Système** exécute les contrôles pré-trade :

   ### 3.1 - Contrôle pouvoir d'achat/marge
   - **Achat**: Solde disponible ≥ (quantité × prix limite) OU prix marché courant
   - **Vente**: Quantité disponible en portefeuille ≥ quantité ordre

   ### 3.2 - Règles de prix
   - **Limite**: Prix dans les bandes autorisées (±5% dernier cours)
   - **Tick size**: Prix multiple de 0.01€

   ### 3.3 - Restrictions trading
   - Instrument actif et tradable
   - Pas d'interdiction de short-selling (sauf autorisé)
   - Heures de trading respectées

   ### 3.4 - Limites utilisateur
   - Taille max par ordre : 10 000€
   - Nombre max d'ordres simultanés : 10

   ### 3.5 - Sanity checks
   - Quantité > 0 et multiple de 1
   - Symbol existe et valide

4. **Si tous les contrôles OK** :
   - Système attribue OrderID unique
   - Persiste l'ordre en statut "NEW"
   - Achemine vers le moteur d'appariement interne
   - Retourne ACK au client

5. **Moteur d'appariement** prend le relais (UC-07)

## Flux Alternatifs

### A1 - Ordre au marché
- **Condition**: Type = "MARCHÉ"
- **Traitement**:
  - Prix non requis (utilise meilleur prix disponible)
  - Routage immédiat vers matching
  - Contrôle pouvoir d'achat avec prix marché courant

### A2 - Ordre IOC/FOK
- **Condition**: Durée = "IOC" (Immediate Or Cancel)
- **Traitement**:
  - Exécute la quantité possible immédiatement
  - Annule le reste non exécuté

### A3 - Idempotence
- **Condition**: clientOrderId déjà traité
- **Traitement**:
  - Renvoie le résultat précédent
  - Évite les doublons

## Exceptions

### E1 - Pouvoir d'achat insuffisant
- **Condition**: Solde < montant ordre
- **Traitement**:
  - Rejet immédiat
  - Message "Solde insuffisant"
  - Code erreur : INSUFFICIENT_FUNDS

### E2 - Violation bande de prix
- **Condition**: Prix limite hors bandes autorisées
- **Traitement**:
  - Rejet immédiat
  - Message "Prix hors limites"
  - Suggestion de prix valide

### E3 - Instrument non tradable
- **Condition**: Symbol inactif ou inexistant
- **Traitement**:
  - Rejet immédiat
  - Message "Instrument non disponible"

### E4 - Limite utilisateur dépassée
- **Condition**: Nombre max d'ordres atteint
- **Traitement**:
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