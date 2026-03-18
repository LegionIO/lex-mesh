# frozen_string_literal: true

require 'legion/extensions/actors/subscription'

module Legion
  module Extensions
    module Mesh
      module Actor
        class PreferenceListener < Legion::Extensions::Actors::Subscription
          def runner_class
            Legion::Extensions::Mesh::Runners::Preferences
          end

          def runner_function
            'dispatch_preference_message'
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
            Legion::Extensions::Mesh::Transport::Queues::Preference
          end

          def enabled?
            defined?(Legion::Extensions::Mesh::Runners::Preferences) &&
              defined?(Legion::Transport)
          rescue StandardError
            false
          end
        end
      end
    end
  end
end
