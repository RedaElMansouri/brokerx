# Couche Application (`Application::`)

Objectif : coordonner les cas d’usage et orchestrer les opérations du domaine ; définir les entrées/sorties du système indépendamment du transport/UI.

Dossiers :
- `use_cases/` → une classe par cas d’usage (Application::UseCases::*)
- `dtos/` → objets de transfert de données (commandes/réponses) (Application::Dtos::*)
- `services/` → services applicatifs transverses (ex : validation, ordonnanceurs, orchestrateurs)

Principes :
- Dépend des abstractions du Domaine ; ne pas référencer ActiveRecord.
- Accepte des types simples ou des DTOs ; retourne des DTOs/types simples.
- Injecte des interfaces de repository (ou des adaptateurs via DI depuis les contrôleurs).
