# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Helpers
        class Registry
          attr_reader :agents, :capabilities, :messages

          def initialize
            @agents = {}
            @capabilities = Hash.new { |h, k| h[k] = [] }
            @messages = []
          end

          def register_agent(agent_id, capabilities: [], endpoint: nil, source: :native, node: nil)
            @agents[agent_id] = {
              agent_id:      agent_id,
              capabilities:  capabilities,
              endpoint:      endpoint,
              source:        source,
              node:          node || local_node_name,
              generation:    1,
              registered_at: Time.now.utc,
              last_seen:     Time.now.utc,
              status:        :online
            }
            capabilities.each { |cap| @capabilities[cap] << agent_id }
          end

          def unregister_agent(agent_id)
            agent = @agents.delete(agent_id)
            return nil unless agent

            agent[:capabilities].each { |cap| @capabilities[cap].delete(agent_id) }
            agent
          end

          def heartbeat(agent_id)
            agent = @agents[agent_id]
            return nil unless agent

            agent[:last_seen] = Time.now.utc
            agent[:status] = :online
            agent[:generation] = (agent[:generation] || 0) + 1
          end

          def find_by_capability(capability)
            agent_ids = @capabilities[capability] || []
            agent_ids.filter_map { |id| @agents[id] }
          end

          def route_message(from:, to: nil, capability: nil, pattern: :unicast, payload: {})
            msg = {
              from: from, to: to, capability: capability,
              pattern: pattern, payload: payload, at: Time.now.utc
            }

            targets = case pattern
                      when :unicast   then to ? [@agents[to]].compact : []
                      when :multicast then capability ? find_by_capability(capability) : []
                      when :broadcast then @agents.values
                      else []
                      end

            msg[:delivered_to] = targets.map { |t| t[:agent_id] }
            @messages << msg
            @messages.shift while @messages.size > 1000
            msg
          end

          def expire_silent_agents(timeout: Topology::MESH_SILENCE_TIMEOUT)
            cutoff = Time.now.utc - timeout
            expired = []
            @agents.each_value do |agent|
              next unless agent[:status] == :online && agent[:last_seen] < cutoff

              agent[:status] = :offline
              expired << agent[:agent_id]
            end
            expired
          end

          def online_agents
            @agents.values.select { |a| a[:status] == :online }
          end

          def all_agents
            @agents.values
          end

          def count
            @agents.size
          end

          private

          def local_node_name
            Legion::Settings[:client][:name]
          rescue StandardError
            'unknown'
          end
        end
      end
    end
  end
end
