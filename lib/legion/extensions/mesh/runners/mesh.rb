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
            log.info "[mesh] registered: agent=#{agent_id} capabilities=#{capabilities.join(',')}"
            { registered: true, agent_id: agent_id }
          end

          def unregister(agent_id:, **)
            result = mesh_registry.unregister_agent(agent_id)
            if result
              log.info "[mesh] unregistered: agent=#{agent_id}"
              publish_mesh_departure(agent_id: agent_id, capabilities: result[:capabilities] || [])
              { unregistered: true }
            else
              log.debug "[mesh] unregister failed: agent=#{agent_id} not found"
              { error: :not_found }
            end
          end

          def heartbeat(agent_id:, **)
            result = mesh_registry.heartbeat(agent_id)
            log.debug "[mesh] heartbeat: agent=#{agent_id} alive=#{!result.nil?}"
            result ? { alive: true } : { error: :not_registered }
          end

          def send_message(from:, to: nil, capability: nil, pattern: :unicast, payload: {}, **)
            return { error: :invalid_pattern } unless Helpers::Topology.valid_pattern?(pattern)

            msg = mesh_registry.route_message(from: from, to: to, capability: capability,
                                              pattern: pattern, payload: payload)
            count = msg[:delivered_to].size
            log.debug "[mesh] message: from=#{from} pattern=#{pattern} delivered=#{count} to=#{msg[:delivered_to].join(',')}"
            { sent: true, delivered_to: msg[:delivered_to], count: count }
          end

          def find_agents(capability:, **)
            agents = mesh_registry.find_by_capability(capability)
            log.debug "[mesh] find: capability=#{capability} found=#{agents.size}"
            { agents: agents.map { |a| a[:agent_id] }, count: agents.size }
          end

          def mesh_status(**)
            online = mesh_registry.online_agents
            total = mesh_registry.count
            msgs = mesh_registry.messages.size
            log.debug "[mesh] status: total=#{total} online=#{online.size} messages=#{msgs}"
            { total: total, online: online.size, message_count: msgs }
          end

          def expire_silent_agents(**)
            expired = mesh_registry.expire_silent_agents
            expired.each do |agent_id|
              log.info "[mesh] expired silent agent: #{agent_id}"
            end
            { success: true, expired: expired, count: expired.size }
          end

          def publish_gossip(**)
            registry = mesh_registry
            peers = registry.all_agents.first(gossip_max_peers).map do |agent|
              agent.slice(:agent_id, :capabilities, :node, :source, :status, :generation,
                          :last_seen, :registered_at).transform_values { |v| v.is_a?(Time) ? v.to_s : v }
            end

            @gossip_round = (@gossip_round || 0) + 1
            peer_table.expire
            publish_gossip_message(peers)
            { success: true, peers_broadcast: peers.size, gossip_round: @gossip_round }
          rescue StandardError => e
            { success: false, reason: :error, message: e.message }
          end

          def merge_gossip(incoming_peers:, sender: nil, **) # rubocop:disable Lint/UnusedMethodArgument
            registry = mesh_registry
            merged = 0
            conflict_agents = []
            local = local_node_name

            peer_table.upsert(sender) if sender && sender != local

            incoming_peers.each do |peer|
              peer = peer.transform_keys(&:to_sym)
              next if peer[:node] == local

              if sender && sender != local && peer[:node] == local
                conflict_agents << peer[:agent_id]
                next
              end

              local_agent = registry.agents[peer[:agent_id]]
              if local_agent.nil?
                registry.register_agent(
                  peer[:agent_id],
                  capabilities: (peer[:capabilities] || []).map(&:to_sym),
                  source:       (peer[:source] || :native).to_sym,
                  node:         peer[:node]
                )
                registry.agents[peer[:agent_id]][:generation] = peer[:generation] || 1
                merged += 1
              elsif (peer[:generation] || 0) > (local_agent[:generation] || 0)
                local_agent.merge!(peer.slice(:capabilities, :status, :generation, :last_seen))
                local_agent[:capabilities] = (local_agent[:capabilities] || []).map(&:to_sym)
                merged += 1
              end
            end

            unless conflict_agents.empty?
              log.warn "[mesh] split-brain: node=#{sender} claims #{conflict_agents.size} local agents"
              publish_conflict_message(detecting_node: local, claiming_node: sender, agents: conflict_agents)
            end

            { success: true, merged: merged, total_peers: incoming_peers.size }
          rescue StandardError => e
            { success: false, reason: :error, message: e.message }
          end

          private

          def publish_mesh_departure(agent_id:, capabilities:)
            return unless defined?(Legion::Extensions::Mesh::Transport::Messages::MeshDeparture)

            Legion::Extensions::Mesh::Transport::Messages::MeshDeparture.new(
              agent_id: agent_id, capabilities: capabilities
            ).publish
            log.debug "[mesh] departure signal published: agent=#{agent_id}"
          rescue StandardError => e
            log.warn "[mesh] failed to publish departure signal: #{e.message}"
          end

          def publish_gossip_message(peers)
            return unless defined?(Legion::Extensions::Mesh::Transport::Messages::Gossip)

            Legion::Extensions::Mesh::Transport::Messages::Gossip.new(
              sender:       local_node_name,
              gossip_round: @gossip_round,
              peers:        peers
            ).publish
          end

          def publish_conflict_message(detecting_node:, claiming_node:, agents:)
            return unless defined?(Legion::Extensions::Mesh::Transport::Messages::MeshConflict)

            Legion::Extensions::Mesh::Transport::Messages::MeshConflict.new(
              detecting_node: detecting_node,
              claiming_node:  claiming_node,
              agents:         agents
            ).publish
          rescue StandardError => e
            log.warn "[mesh] failed to publish conflict signal: #{e.message}"
          end

          def gossip_max_peers
            settings = Legion::Settings.dig(:mesh, :gossip)
            (settings.is_a?(Hash) ? settings[:max_peers_per_message] : nil) || 100
          rescue StandardError
            100
          end

          def local_node_name
            Legion::Settings[:client][:name]
          rescue StandardError
            'unknown'
          end

          def mesh_registry
            @mesh_registry ||= Helpers::Registry.new
          end

          def peer_table
            @peer_table ||= Helpers::PeerTable.new
          end
        end
      end
    end
  end
end
