# ADR 002: Stratégie de persistance - Repository Pattern avec ActiveRecord

## Statut
**Approuvé** | **Date**: 2025-09-15 | **Décideurs**: Architecte logiciel

## Contexte
Nous devons choisir une stratégie de persistance pour BrokerX+ qui respecte l'architecture hexagonale tout en tirant parti des avantages d'ActiveRecord. Le système doit garantir l'intégrité des données et permettre des migrations évolutives.

## Décision
**Nous utilisons le Repository Pattern avec ActiveRecord comme implémentation sous-jacente** :

### Architecture choisie :
Domain Layer (Entities, Value Objects)
↑
Repository Interfaces (Ports)
↑
Repository Implementations (Adapters) → ActiveRecord Models
↑
Database (PostgreSQL)


### Justification :
1. **Abstraction du domaine** : Les entités domaines ne connaissent pas ActiveRecord
2. **Flexibilité** : Possibilité de changer l'ORM sans affecter le domaine
3. **Testabilité** : Mock facile des repositories dans les tests unitaires
4. **Best of both worlds** : Bénéficie de la richesse d'ActiveRecord tout en maintenant la séparation

## Conséquences
### Positives
- Domaine pur sans dépendances base de données
- Tests unitaires rapides (mocks des repositories)
- Migration future vers autre ORM possible
- Utilisation des avantages ActiveRecord (migrations, validations)

### Négatives (à mitiger)
- Double mapping (Domain ↔ ActiveRecord)
- Boilerplate code pour les repositories
- **Solution** : Création de base classes et helpers

<!-- ## Implémentation
```ruby
# Domain Entity
class Order
  attr_reader :id, :symbol, :quantity, :price, :status
  
  def initialize(id:, symbol:, quantity:, price:, status:)
    # Validation des règles métier
  end
end

# Repository Interface (Port)
class OrderRepository
  def find(id)
    raise NotImplementedError
  end
  
  def save(order)
    raise NotImplementedError
  end
end

# ActiveRecord Model (Infrastructure)
class OrderRecord < ActiveRecord::Base
  # Validations techniques (presence, format, etc.)
end

# Repository Implementation (Adapter)
class ActiveRecordOrderRepository < OrderRepository
  def find(id)
    record = OrderRecord.find(id)
    to_entity(record)
  end
  
  def save(order)
    record = OrderRecord.find_or_initialize_by(id: order.id)
    record.assign_attributes(from_entity(order))
    record.save!
    order.id = record.id
    order
  end
end -->


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

### ActiveRecord seul
**Avantages** : Simple, rapide

**Inconvénients** : Couplage fort domaine/infrastructure, difficile à tester

### Repository + Raw SQL
**Avantages** : Performance maximale

**Inconvénients** : Perte des avantages ActiveRecord, complexité accrue

## Validation

CRUD complet sur les agrégats principaux

Tests unitaires du domaine sans DB

Tests d'intégration des repositories