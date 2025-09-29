# Bounded Contexts - BrokerX+

## Overview
Décomposition du domaine métier en contextes délimités selon les principes DDD.

## 1. Client & Comptes (Account Management)

**Responsabilités principales** :
- Gestion du cycle de vie des clients (inscription → vérification → activation)
- Authentification et autorisation (MFA, gestion des sessions)
- Gestion des portefeuilles virtuels et soldes
- Traitement des dépôts virtuels et intégrité financière

**Sous-domaines critiques** :
- **Identity & Access Management** : Login, MFA, sessions, RBAC
- **Account Lifecycle** : KYC/AML, validation, états (Pending/Active/Rejected)
- **Portfolio Management** : Solde, transactions, positions, historiques

**Événements de domaine émis** :
- `ClientRegistered`, `AccountActivated`, `PortfolioCredited`


## 2. Ordres & Trading (Order Management)

**Responsabilités principales** :
- Réception, validation et traitement des ordres (marché/limite)
- Contrôles pré-trade (pouvoir d'achat, règles prix, short-selling)
- Gestion du cycle de vie des ordres (placement → modification → annulation)
- Appariement interne et génération des exécutions

**Sous-domaines critiques** :
- **Order Management** : Carnet d'ordres, états (New/Working/Filled/Cancelled)
- **Trade Execution** : Moteur d'appariement price-time priority
- **Risk Management** : Contrôles pré/post-trade, limites utilisateur

**Événements de domaine émis** :
- `OrderPlaced`, `OrderCancelled`, `TradeExecuted`

## 3. Marché & Données (Market Data)

**Responsabilités principales** :
- Réception et agrégation des données de marché simulées
- Diffusion en temps réel aux clients (WebSocket/SSE)
- Gestion des abonnements et quotas utilisateurs
- Référentiel des instruments financiers

**Sous-domaines critiques** :
- **Market Data Streaming** : Connexions temps réel, gestion de débit
- **Reference Data** : Instruments, horaires trading, métadonnées
- **Subscription Management** : Gestion des abonnements symboles

**Événements de domaine émis** :
- `MarketDataUpdated`, `SubscriptionCreated`