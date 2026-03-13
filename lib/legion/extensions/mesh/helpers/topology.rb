# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Helpers
        module Topology
          PROTOCOLS = %i[grpc websocket rest].freeze
          PATTERNS  = %i[unicast multicast broadcast].freeze

          MESH_SILENCE_TIMEOUT = 30 # seconds
          TRUST_CONSIDER_THRESHOLD = 0.3
          MAX_HOPS = 3

          module_function

          def valid_protocol?(protocol)
            PROTOCOLS.include?(protocol)
          end

          def valid_pattern?(pattern)
            PATTERNS.include?(pattern)
          end
        end
      end
    end
  end
end
