# ADR 003: Stratégie de gestion des erreurs

## Statut
**Proposé** | **Date**: 2025-01-15 | **Décideurs**: Architecte logiciel

## Contexte
Dans un système de trading, la gestion des erreurs est critique pour la fiabilité et l'auditabilité. Nous devons définir une stratégie cohérente pour la gestion des erreurs métier, techniques et d'infrastructure.

## Décision
**Implémentation d'une hiérarchie d'erreurs structurée avec gestion centralisée** :

### Hiérarchie des erreurs :
```
BrokerError (base)
├── DomainError (erreurs métier)
│ ├── InsufficientFundsError
│ ├── InvalidOrderError
│ └── AccountNotActiveError
├── ApplicationError (erreurs use case)
│ ├── ValidationError
│ └── AuthenticationError
└── InfrastructureError (erreurs techniques)
├── DatabaseError
├── ExternalServiceError
└── NetworkError
```

### Principes :
1. **Erreurs métier explicites** : Chaque règle métier violée a son propre type d'erreur
2. **No silent failures** : Toutes les erreurs sont journalisées
3. **Graceful degradation** : Le système reste opérationnel malgré les erreurs partielles
4. **Audit trail** : Toutes les erreurs sont tracées avec contexte

## Conséquences
### Positives
- Code plus robuste et maintenable
- Meilleure expérience utilisateur (messages d'erreur précis)
- Meilleure débuggabilité (stack traces enrichies)
- Conformité audit réglementaire

### Négatives (à mitiger)
- Complexité accrue de la gestion d'erreurs
- Courbe d'apprentissage pour l'équipe
- **Solution** : Documentation et helpers partagés

<!-- ## Implémentation
```ruby
# Domain Error
class InsufficientFundsError < DomainError
  def initialize(account_id, amount, balance)
    super("Insufficient funds for account #{account_id}: tried to spend #{amount}, balance: #{balance}")
    @account_id = account_id
    @amount = amount
    @balance = balance
  end
end

# Use Case avec gestion d'erreurs
class PlaceOrderService
  def execute(command)
    # Validation métier
    raise InsufficientFundsError.new(account.id, order_amount, account.balance) unless sufficient_funds?
    
    # Logique métier...
  rescue DomainError => e
    # Journalisation métier
    Rails.logger.warn("Domain error in PlaceOrderService: #{e.message}")
    raise # Re-lance pour être attrapé par le contrôleur
  end
end

# Contrôleur avec gestion centralisée
class OrdersController < ApplicationController
  rescue_from DomainError, with: :handle_domain_error
  rescue_from ApplicationError, with: :handle_application_error
  
  private
  
  def handle_domain_error(error)
    render json: { 
      error: error.class.name.demodulize,
      message: error.message,
      details: error.try(:details) 
    }, status: :unprocessable_entity
  end
end -->

## Alternatives considérées
### Exceptions standard Ruby
**Avantages** : Simple

**Inconvénients** : Pas de sémantique métier, difficile à gérer spécifiquement

### Monads (Result pattern)
**Avantages** : Programmation fonctionnelle, chaînage élégant

**Inconvénients** : Moins idiomatique en Ruby, courbe d'apprentissage

## Validation
Tous les use cases gèrent les erreurs métier

Journalisation complète des erreurs

Tests des scénarios d'erreur