# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Messages
          class PreferenceResponse < Legion::Transport::Message
            def exchange
              Legion::Transport::Exchanges::Agent
            end

            def routing_key
              "agent.#{@options[:target_agent_id]}.preferences"
            end

            def message
              {
                type:                'preference_response',
                responding_agent_id: @options[:responding_agent_id],
                profile:             @options[:profile] || {},
                responded_at:        Time.now.to_s
              }
            end

            def type
              'preference_response'
            end
          end
        end
      end
    end
  end
end
