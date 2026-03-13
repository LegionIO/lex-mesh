# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Runners
        module Mesh
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def register(agent_id:, capabilities: [], endpoint: nil, **)
            mesh_registry.register_agent(agent_id, capabilities: capabilities, endpoint: endpoint)
            { registered: true, agent_id: agent_id }
          end

          def unregister(agent_id:, **)
            result = mesh_registry.unregister_agent(agent_id)
            result ? { unregistered: true } : { error: :not_found }
          end

          def heartbeat(agent_id:, **)
            result = mesh_registry.heartbeat(agent_id)
            result ? { alive: true } : { error: :not_registered }
          end

          def send_message(from:, to: nil, capability: nil, pattern: :unicast, payload: {}, **)
            return { error: :invalid_pattern } unless Helpers::Topology.valid_pattern?(pattern)

            msg = mesh_registry.route_message(from: from, to: to, capability: capability,
                                              pattern: pattern, payload: payload)
            { sent: true, delivered_to: msg[:delivered_to], count: msg[:delivered_to].size }
          end

          def find_agents(capability:, **)
            agents = mesh_registry.find_by_capability(capability)
            { agents: agents.map { |a| a[:agent_id] }, count: agents.size }
          end

          def mesh_status(**)
            online = mesh_registry.online_agents
            { total: mesh_registry.count, online: online.size, message_count: mesh_registry.messages.size }
          end

          private

          def mesh_registry
            @mesh_registry ||= Helpers::Registry.new
          end
        end
      end
    end
  end
end
