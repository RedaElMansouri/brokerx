module Infrastructure
  module Persistence
    module Repositories
      class ActiveRecordOrderRepository
        def create(order_hash)
          rec = Infrastructure::Persistence::ActiveRecord::OrderRecord.new(order_hash)
          rec.save!
          rec
        end

        def find(id)
          Infrastructure::Persistence::ActiveRecord::OrderRecord.find(id)
        end

        def update_status(id, status)
          rec = find(id)
          rec.update!(status: status)
          rec
        end
      end
    end
  end
end
