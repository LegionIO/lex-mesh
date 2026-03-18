# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Messages
          class MeshDeparture < Legion::Transport::Message
            def exchange
              Legion::Transport::Exchanges::Node
            end

            def routing_key
              'mesh.departure'
            end

            def message
              {
                type:         'mesh_departure',
                agent_id:     @options[:agent_id],
                capabilities: @options[:capabilities] || [],
                departed_at:  Time.now.to_s
              }
            end

            def type
              'mesh_departure'
            end
          end
        end
      end
    end
  end
end
