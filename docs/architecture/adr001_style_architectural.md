# ADR 001: Choix du style architectural - Hexagonal vs MVC

## Statut
**Proposé** | **Date**: 2025-09-02 | **Décideurs**: Architecte logiciel

## Contexte
Le projet BrokerX+ nécessite une architecture monolithique initiale qui doit évoluer vers des microservices. Nous devons choisir entre une architecture traditionnelle MVC Rails et une architecture hexagonale (ports/adapters) qui offre une meilleure séparation des concerns et prépare la migration future.

## Décision
**Nous choisissons l'architecture hexagonale** (ports and adapters) pour les raisons suivantes :

### Avantages de l'architecture hexagonale :
1. **Séparation claire domaine/infrastructure** : Le cœur métier est isolé des frameworks et technologies
2. **Testabilité améliorée** : Les tests unitaires du domaine ne dépendent d'aucune infrastructure
3. **Évolutivité vers microservices** : Les bounded contexts sont naturellement séparés
4. **Flexibilité technologique** : Changer de base de données ou de framework web est plus facile
5. **Alignement DDD** : Correspond parfaitement aux bounded contexts identifiés

### Inconvénients mitigés :
- **Courbe d'apprentissage** : Plus complexe que MVC traditionnel
- **Boilerplate code** : Plus de code d'infrastructure nécessaire
- **Solution** : Documentation détaillée et templates de code

## Conséquences
### Positives
- Le domaine métier reste pure et testable
- Préparation naturelle pour la migration microservices
- Meilleure maintenabilité à long terme
- Indépendance vis-à-vis de Rails

### Négatives (à mitiger)
- Complexité initiale plus élevée
- Temps de développement légèrement accru

## Alternatives considérées
### MVC Rails traditionnel
- **Avantages** : Simple, rapide à développer, bien documenté
- **Inconvénients** : Couplage fort au framework, difficile à tester unitairement, migration microservices complexe

### Architecture en couches
- **Avantages** : Séparation partielle des concerns
- **Inconvénients** : Moins flexible que l'hexagonal, dépendances non contrôlées

## Validation
Cette décision sera validée par :
- [ ] Prototype fonctionnel avec séparation domaine/infrastructure
- [ ] Tests unitaires du domaine sans dépendances infrastructure

## Références
- [LOG430 : Architecture Logicielle Architecture et Domain-Driven Design](https://ena.etsmtl.ca/pluginfile.php/2353589/mod_resource/content/3/ETS%20-%20LOG430%20-%20Architecture%20Logicielle%20-%202025_03%20-%20Cours%2004%20-%20Architecture%20et%20Domain-Driven%20Design.pdf)
- [Alistair Cockburn - Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Domain-Driven Design](https://domainlanguage.com/ddd/)