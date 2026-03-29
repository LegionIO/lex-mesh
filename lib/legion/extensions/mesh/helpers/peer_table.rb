# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Helpers
        class PeerTable
          DEFAULT_TTL = 90 # seconds: covers 3 missed gossip cycles (15s each) with buffer

          def initialize(ttl: DEFAULT_TTL)
            @ttl   = ttl
            @peers = {}
          end

          def upsert(node_name, seen_at: Time.now.utc)
            @peers[node_name] = { node: node_name, last_seen: seen_at }
          end

          def expire
            cutoff = Time.now.utc - @ttl
            expired = []
            @peers.each { |node, entry| expired << node if entry[:last_seen] < cutoff }
            expired.each { |node| @peers.delete(node) }
            expired
          end

          def known_nodes
            @peers.keys
          end

          def include?(node_name)
            @peers.key?(node_name)
          end

          def count
            @peers.size
          end
        end
      end
    end
  end
end
