# frozen_string_literal: true

require 'legion/extensions/actors/every'

module Legion
  module Extensions
    module Mesh
      module Actor
        class Gossip < Legion::Extensions::Actors::Every # rubocop:disable Legion/Extension/EveryActorRequiresTime
          def runner_class
            Legion::Extensions::Mesh::Runners::Mesh
          end

          def runner_function
            :publish_gossip
          end

          def time
            15
          end

          def use_runner?
            true
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def args
            {}
          end
        end
      end
    end
  end
end
