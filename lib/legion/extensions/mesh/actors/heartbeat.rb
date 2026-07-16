# frozen_string_literal: true

require 'legion/extensions/actors/every'

module Legion
  module Extensions
    module Mesh
      module Actor
        class Heartbeat < Legion::Extensions::Actors::Every
          def runner_class
            Legion::Extensions::Mesh::Runners::Mesh
          end

          def runner_function
            'heartbeat'
          end

          def time
            10
          end

          def run_now?
            true
          end

          def use_runner?
            false
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end

          def args
            { agent_id: Legion::Settings[:client][:name] }
          end
        end
      end
    end
  end
end
