# frozen_string_literal: true

require 'legion/extensions/actors/subscription'

module Legion
  module Extensions
    module Mesh
      module Actor
        class GossipListener < Legion::Extensions::Actors::Subscription
          def runner_class
            Legion::Extensions::Mesh::Runners::Mesh
          end

          def runner_function
            'merge_gossip'
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def use_runner?
            true
          end

          def queue
            Legion::Extensions::Mesh::Transport::Queues::Gossip
          end

          def enabled?
            defined?(Legion::Extensions::Mesh::Runners::Mesh) &&
              defined?(Legion::Transport)
          rescue StandardError
            false
          end
        end
      end
    end
  end
end
