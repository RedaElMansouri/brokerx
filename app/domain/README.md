# Couche Domaine (`Domain::`)

Objectif : exprimer les concepts et règles métier sans dépendance au framework/à la base de données.

Structure :
- `shared/` abstractions de base (`Entity`, `ValueObject`, `Repository`)
- `<bounded_context>/entities/` entités du domaine
- `<bounded_context>/value_objects/` types immuables
- `<bounded_context>/repositories/` interfaces de repository (ports)

Principes :
- Aucune dépendance à ActiveRecord ou Rails.
- Valider les invariants dans les constructeurs/méthodes de fabrique.
- Préférer des erreurs métier explicites.
- Conserver des limites d’agrégat claires ; les interfaces de repository opèrent sur des agrégats.
