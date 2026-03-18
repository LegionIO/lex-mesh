# frozen_string_literal: true

require 'legion/extensions/actors/every'

module Legion
  module Extensions
    module Mesh
      module Actor
        class PendingExpiry < Legion::Extensions::Actors::Every
          def runner_class
            Legion::Extensions::Mesh::Runners::Preferences
          end

          def runner_function
            'expire_pending_requests'
          end

          def time
            30
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
        end
      end
    end
  end
end
