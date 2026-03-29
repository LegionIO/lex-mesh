# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Messages
          class MeshConflict < Legion::Transport::Message
            def exchange
              Legion::Transport::Exchanges::Node
            end

            def routing_key
              'mesh.conflict'
            end

            def message
              {
                type:           'mesh_conflict',
                detecting_node: @options[:detecting_node],
                claiming_node:  @options[:claiming_node],
                agents:         @options[:agents] || [],
                detected_at:    Time.now.to_s
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
