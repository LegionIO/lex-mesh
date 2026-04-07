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
              Legion::Extensions::Mesh::Transport::Exchanges::Fanout
            end
          end
        end
      end
    end
  end
end
