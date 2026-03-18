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
            Legion::Logging.info "[mesh] registered: agent=#{agent_id} capabilities=#{capabilities.join(',')}"
            { registered: true, agent_id: agent_id }
          end

          def unregister(agent_id:, **)
            result = mesh_registry.unregister_agent(agent_id)
            if result
              Legion::Logging.info "[mesh] unregistered: agent=#{agent_id}"
              publish_mesh_departure(agent_id: agent_id, capabilities: result[:capabilities] || [])
              { unregistered: true }
            else
              Legion::Logging.debug "[mesh] unregister failed: agent=#{agent_id} not found"
              { error: :not_found }
            end
          end

          def heartbeat(agent_id:, **)
            result = mesh_registry.heartbeat(agent_id)
            Legion::Logging.debug "[mesh] heartbeat: agent=#{agent_id} alive=#{!result.nil?}"
            result ? { alive: true } : { error: :not_registered }
          end

          def send_message(from:, to: nil, capability: nil, pattern: :unicast, payload: {}, **) # rubocop:disable Metrics/ParameterLists
            return { error: :invalid_pattern } unless Helpers::Topology.valid_pattern?(pattern)

            msg = mesh_registry.route_message(from: from, to: to, capability: capability,
                                              pattern: pattern, payload: payload)
            count = msg[:delivered_to].size
            Legion::Logging.debug "[mesh] message: from=#{from} pattern=#{pattern} delivered=#{count} to=#{msg[:delivered_to].join(',')}"
            { sent: true, delivered_to: msg[:delivered_to], count: count }
          end

          def find_agents(capability:, **)
            agents = mesh_registry.find_by_capability(capability)
            Legion::Logging.debug "[mesh] find: capability=#{capability} found=#{agents.size}"
            { agents: agents.map { |a| a[:agent_id] }, count: agents.size }
          end

          def mesh_status(**)
            online = mesh_registry.online_agents
            total = mesh_registry.count
            msgs = mesh_registry.messages.size
            Legion::Logging.debug "[mesh] status: total=#{total} online=#{online.size} messages=#{msgs}"
            { total: total, online: online.size, message_count: msgs }
          end

          def expire_silent_agents(**)
            expired = mesh_registry.expire_silent_agents
            expired.each do |agent_id|
              Legion::Logging.info "[mesh] expired silent agent: #{agent_id}"
            end
            { success: true, expired: expired, count: expired.size }
          end

          private

          def publish_mesh_departure(agent_id:, capabilities:)
            return unless defined?(Legion::Extensions::Mesh::Transport::Messages::MeshDeparture)

            Legion::Extensions::Mesh::Transport::Messages::MeshDeparture.new(
              agent_id: agent_id, capabilities: capabilities
            ).publish
            Legion::Logging.debug "[mesh] departure signal published: agent=#{agent_id}"
          rescue StandardError => e
            Legion::Logging.warn "[mesh] failed to publish departure signal: #{e.message}"
          end

          def mesh_registry
            @mesh_registry ||= Helpers::Registry.new
          end
        end
      end
    end
  end
end
