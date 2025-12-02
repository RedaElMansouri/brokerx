# Vue Logique - 4+1 Views

## Objectif
Décrire l'organisation statique du système en termes de classes, packages et relations.

## Éléments Principaux

### Packages du Domaine (Bounded Contexts)

#### Package: `domain.clients`
  ![domain.clients](../assets/logical_view/domain_clients.png)
#### Package: `domain.trading`
  ![domain.trading](../assets/logical_view/domain.trading.png)
#### Package: `domain.market_data`
  ![domain.market_data](../assets/logical_view/domain_market_data.png)
#### Relations entre Packages
  ![Relations_Packages](../assets/logical_view/relation_packages.png)

### Principes de Conception
- **Encapsulation forte** : Les entités protègent leur invariant

- **Immutabilité** : Les Value Objects sont immuables

- **Responsabilité unique** : Chaque classe a une raison de changer

- **Dépendances explicites** : Les relations sont clairement définies