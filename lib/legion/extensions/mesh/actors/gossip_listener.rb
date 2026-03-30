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
            'dispatch_gossip_message'
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def use_runner?
            false
          end

          def queue
            Legion::Extensions::Mesh::Transport::Queues::Gossip
          end

          def enabled? # rubocop:disable Legion/Extension/ActorEnabledSideEffects
            defined?(Legion::Extensions::Mesh::Runners::Mesh) &&
              Legion.const_defined?(:Transport, false)
          rescue StandardError => _e
            false
          end
        end
      end
    end
  end
end
