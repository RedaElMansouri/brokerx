module Domain
  module Shared
    module Repository
      class Error < StandardError; end
      class RecordNotFound < Error; end

      class BaseRepository
      end
    end
  end
end
