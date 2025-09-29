module Application
  module Services
    class OrderValidationService
      def initialize(portfolio_repository)
        @portfolio_repository = portfolio_repository
      end

      def validate_pre_trade(order_dto, client_id)
        errors = []

        # Vérifier le pouvoir d'achat pour les ordres d'achat
        if order_dto.direction == 'buy'
          portfolio = @portfolio_repository.find_by_account_id(client_id)
          total_cost = calculate_order_cost(order_dto)

          unless portfolio&.sufficient_funds?(total_cost)
            errors << "Insufficient funds"
          end
        end

        # Vérifier les règles de prix pour les ordres limites
        if order_dto.order_type == 'limit' && order_dto.price
          unless valid_price_band?(order_dto.price)
            errors << "Price outside valid trading band"
          end
        end

        # Vérifier la quantité
        unless order_dto.quantity > 0
          errors << "Quantity must be positive"
        end

        errors
      end

      private

      def calculate_order_cost(order_dto)
        # Pour le prototype, on utilise le prix de l'ordre limite
        # Pour les ordres marché, on devrait utiliser le prix courant du marché
        price = order_dto.price || 100.0 # Prix par défaut pour les tests
        order_dto.quantity * price
      end

      def valid_price_band?(price)
        # Règle métier : prix entre 1$ et 10,000$
        price >= 1.0 && price <= 10000.0
      end
    end
  end
end
