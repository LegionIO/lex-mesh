# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Messages
          class MeshConflict < Legion::Transport::Message
            def exchange
              Legion::Extensions::Mesh::Transport::Exchanges::Fanout
            end

            def routing_key
              'mesh.conflict'
            end

            def message
              {
                type:             'mesh_conflict',
                local_node:       @options[:local_node],
                conflicting_node: @options[:conflicting_node],
                conflict_agents:  @options[:conflict_agents] || [],
                detected_at:      Time.now.to_s
              }
            end

            def type
              'mesh_conflict'
            end
          end
        end
      end
    end
  end
end
