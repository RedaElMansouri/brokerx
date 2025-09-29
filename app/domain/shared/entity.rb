module Domain
  module Shared
    class Entity
      attr_reader :id, :created_at, :updated_at
      attr_writer :id

      def initialize(id: nil, created_at: nil, updated_at: nil)
        @id = id || SecureRandom.uuid
        @created_at = created_at || Time.current
        @updated_at = updated_at || Time.current
      end

      def ==(other)
        self.class == other.class && id == other.id
      end

      def touch
        @updated_at = Time.current
      end
    end
  end
end
