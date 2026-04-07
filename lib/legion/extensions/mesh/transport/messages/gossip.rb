# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Messages
          class Gossip < Legion::Transport::Message
            def exchange
              Legion::Extensions::Mesh::Transport::Exchanges::Fanout
            end

            def routing_key
              'mesh.gossip'
            end

            def message
              {
                type:         'mesh_gossip',
                sender:       @options[:sender],
                gossip_round: @options[:gossip_round] || 0,
                peers:        @options[:peers] || []
              }
            end

            def type
              'mesh_gossip'
            end

            def encrypt?
              false
            end
          end
        end
      end
    end
  end
end
