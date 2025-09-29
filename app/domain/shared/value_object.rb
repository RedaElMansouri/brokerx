module Domain
  module Shared
    class ValueObject
      def ==(other)
        self.class == other.class && state == other.state
      end

      protected

      def state
        instance_variables.sort.each_with_object({}) do |var, hash|
          hash[var] = instance_variable_get(var)
        end
      end
    end
  end
end
