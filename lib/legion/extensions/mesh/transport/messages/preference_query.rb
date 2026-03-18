# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Messages
          class PreferenceQuery < Legion::Transport::Message
            def exchange
              Legion::Transport::Exchanges::Agent
            end

            def routing_key
              "agent.#{@options[:target_agent_id]}.preferences"
            end

            def message
              {
                type:                'preference_query',
                requesting_agent_id: @options[:requesting_agent_id],
                domains:             @options[:domains] || [],
                requested_at:        Time.now.to_s
              }
            end

            def type
              'preference_query'
            end
          end
        end
      end
    end
  end
end
