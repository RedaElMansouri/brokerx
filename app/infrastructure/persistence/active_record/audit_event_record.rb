module Infrastructure
  module Persistence
    module ActiveRecord
      class AuditEventRecord < ::ApplicationRecord
        self.table_name = 'audit_events'
      end
    end
  end
end
