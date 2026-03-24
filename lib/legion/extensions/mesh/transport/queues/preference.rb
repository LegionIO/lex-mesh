# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Queues
          class Preference < Legion::Transport::Queues::Agent
            def initialize(agent_id: nil, **)
              super
            end

            def queue_name
              agent = @agent_id || Legion::Settings[:client][:name]
              "agent.#{agent}.preferences"
            end

            def bind_routing_key
              agent = @agent_id || Legion::Settings[:client][:name]
              "agent.#{agent}.preferences"
            end
          end
        end
      end
    end
  end
end
