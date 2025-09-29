# Phase 1 — Synthèse

## Portée livrée
- Authentification en 2 étapes avec MFA (login + verify_mfa) menant à l’émission d’un JWT.
- Inscription client avec création automatique de portefeuille et prise en charge d’un solde initial.
- Architecture Domain-Driven Design (Domaine, Application, Infrastructure) avec pattern Repository.
- Persistance via modèles ActiveRecord et repositories pour Clients et Portefeuilles.
- Scénario de placement d’ordre documenté en PlantUML (diagramme de séquence).
- Documentation initiale :
  - Description du Repository Pattern adaptée au code
  - Schéma de base de données (PUML + rendus PNG)

## Vue d’architecture
- Domaine : entités (`Client`, `Portfolio`), value objects (`Email`, `Money`), interfaces de repository.
- Application : use cases (`AuthenticateUserUseCase`, `RegisterClientUseCase`), services (validation d’ordres, ébauche de matching engine).
- Infrastructure : modèles ActiveRecord et repositories concrets, adaptateurs web (controllers), mailers.
- Sécurité : génération de JWT (prototype) via `secret_key_base`; codes MFA persistés, expiration 10 minutes.

## Implémentations clés
- `Api::V1::AuthenticationController` :
  - `login` génère un code MFA et le persiste dans `ClientRecord`.
  - `verify_mfa` valide le code + fenêtre temporelle et retourne le JWT.
- `Application::UseCases::AuthenticateUserUseCase` :
  - Valide l’existence et le statut actif du client, retourne un token (vérification de mot de passe en prototype).
- `Application::UseCases::RegisterClientUseCase` :
  - Enregistre un client et crée un portefeuille par défaut (USD) avec soldes à zéro.
- Repositories :
  - `ActiveRecordClientRepository` avec mapping entité-domaine et sauvegarde transactionnelle.
  - `ActiveRecordPortfolioRepository` fournissant `find_by_account_id`, `reserve_funds`, `release_funds` avec verrouillage.

## Tests & couverture
- Squelette de tests présent (Minitest), gems RSpec incluses mais specs minimales.
- Migrations appliquées en base de test ; SimpleCov envisagé mais non conservé pour l’instant.

## Problèmes identifiés / résolus
- Erreur « superclass mismatch for class ClientRecord » due à une double définition :
  - `app/models/client_record.rb`
  - `app/infrastructure/persistence/active_record/client_record.rb`
  Reco : ne garder que la version sous infrastructure et supprimer le doublon sous `app/models`.
- Rendu PlantUML : usage de l’encodage deflate + GET pour obtenir un SVG/PNG propre (évite un payload HTML inattendu).

## Diagrammes & docs
- Diagramme de séquence (réservation de fonds) : `docs/architecture/4plus1_views/puml/placement_ordre_w_validation.puml`.
- Repository Pattern : `docs/persistance/repository_pattern.md` mis à jour selon le code.
- ERD : `docs/persistance/diagramme_entity-relation.puml` (rendus SVG/PNG).

## Prochaines étapes (Phase 2)
- Durcir l’authentification : hash/vérif. du mot de passe, throttling, mailer réel.
- Supprimer le doublon `ClientRecord`, redémarrer le serveur et ajouter un smoke test `/api/v1/auth/login`.
- Ajouter des tests d’intégration repository et réintroduire SimpleCov pour la couverture.
- Implémenter le placement d’ordre de bout en bout : controller, service et persistance des ordres, avec réservation de portefeuille dans une seule transaction.
- Mettre en place une CI pour lancer tests et lint à chaque push (badge couverture optionnel).

## Annexe : traçabilité
- Controllers : `app/controllers/api/v1/authentication_controller.rb`, `app/controllers/orders_controller.rb`.
- Use cases : `app/application/use_cases/authenticate_user_use_case.rb`, `app/application/use_cases/register_client_use_case.rb`.
- Repositories : `app/infrastructure/persistence/repositories/active_record_client_repository.rb`, `.../active_record_portfolio_repository.rb`.
- Modèles : `app/infrastructure/persistence/active_record/client_record.rb`, `.../portfolio_record.rb`.
- Domaine : `app/domain/clients/entities`, `app/domain/clients/value_objects`, `app/domain/clients/repositories`, `app/domain/shared`.
