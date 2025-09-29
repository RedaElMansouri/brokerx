# Documentation Arc42 - BrokerX+

## 1. Introduction et Buts

### 1.1 Vue d'ensemble
BrokerX+ est une plateforme de courtage en ligne permettant aux investisseurs particuliers d'effectuer des opérations de trading sur marchés simulés.

### 1.2 Objectifs
- Fournir une expérience trading sécurisée et performante
- Respecter les exigences réglementaires (KYC/AML)
- Préparer l'évolution vers une architecture microservices

## 2. Contraintes Architecturelles

### 2.1 Contraintes Techniques
- **Langages**: Ruby on Rails (contrainte pédagogique)
- **Base de données**: PostgreSQL
- **Performance**: Latence < 500ms, débit > 300 ordres/sec
- **Disponibilité**: 90% en Phase 1

### 2.2 Contraintes Métier
- Conformité financière (pré-trade controls)
- Audit trail complet
- Sécurité des données clients

## 3. Contexte et Étendue du Système

### 3.1 Diagramme de Contexte
[Voir diagramme dans la vue logique]

### 3.2 Interfaces Externes
- Clients (web/mobile)
- Fournisseurs données marché (simulés)
- Back-office (supervision)

## 4. Solution Strategy

### 4.1 Principes Architecturaux
- Architecture hexagonale (ports/adapters)
- Domain-Driven Design
- Séparation stricte domaine/infrastructure

### 4.2 Decisions Techniques
- [ADR 001] Architecture hexagonale vs MVC
- [ADR 002] Repository pattern avec ActiveRecord
- [ADR 003] Stratégie de gestion des erreurs

## 5. Building Block View

### 5.1 Vue Niveau 1 - Composants Principaux
```
BrokerX+ System
├── Client & Comptes Context
├── Ordres & Trading Context
└── Marché & Données Context
```
