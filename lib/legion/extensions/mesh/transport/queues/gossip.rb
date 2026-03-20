# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Queues
          class Gossip < Legion::Transport::Queue
            def queue_name
              'mesh.gossip'
            end

            def exchange
              Legion::Transport::Exchanges::Node
            end

            def routing_key
              'mesh.gossip'
            end
          end
        end
      end
    end
  end
end
