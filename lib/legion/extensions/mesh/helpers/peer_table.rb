# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Helpers
        class PeerTable
          DEFAULT_TTL = 60 # seconds

          def initialize(ttl: DEFAULT_TTL)
            @ttl = ttl
            @peers = {}
            @mutex = Mutex.new
          end

          def upsert(agent_id, data = {})
            @mutex.synchronize do
              @peers[agent_id] = data.merge(last_seen_at: Time.now.utc)
            end
          end

          def get(agent_id)
            @mutex.synchronize { @peers[agent_id] }
          end

          def all
            @mutex.synchronize { @peers.dup }
          end

          def expire
            cutoff = Time.now.utc - @ttl
            expired = []
            @mutex.synchronize do
              @peers.each do |id, entry|
                next unless entry[:last_seen_at] < cutoff

                expired << id
              end
              expired.each { |id| @peers.delete(id) }
            end
            expired
          end

          def count
            @mutex.synchronize { @peers.size }
          end

          def remove(agent_id)
            @mutex.synchronize { @peers.delete(agent_id) }
          end
        end
      end
    end
  end
end
