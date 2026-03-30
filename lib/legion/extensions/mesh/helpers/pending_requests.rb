# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Helpers
        class PendingRequests
          def initialize(default_ttl: 5)
            @default_ttl = default_ttl
            @requests = {}
            @mutex = Mutex.new
          end

          def register(correlation_id:, callback:, ttl: nil)
            @mutex.synchronize do
              @requests[correlation_id] = {
                callback:      callback,
                registered_at: Time.now,
                ttl:           ttl || @default_ttl
              }
            end
          end

          def resolve(correlation_id:, result:)
            entry = @mutex.synchronize { @requests.delete(correlation_id) }
            return false unless entry

            entry[:callback]&.call(result)
            true
          end

          def pending?(correlation_id)
            @mutex.synchronize { @requests.key?(correlation_id) }
          end

          def pending_count
            @mutex.synchronize { @requests.size }
          end

          def expire
            now = Time.now
            expired = []
            @mutex.synchronize do
              @requests.each do |id, entry|
                next unless now - entry[:registered_at] >= entry[:ttl]

                expired << id
              end
              expired.each { |id| @requests.delete(id) }
            end
            expired
          end
        end
      end
    end
  end
end
