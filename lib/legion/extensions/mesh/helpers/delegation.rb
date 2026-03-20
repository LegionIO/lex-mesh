# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module Mesh
      module Helpers
        class Delegation
          CONSENT_LEVELS = %i[read execute admin].freeze

          attr_reader :delegations

          def initialize(max_depth: 3, max_active_per_agent: 10)
            @delegations = {}
            @agent_delegations = Hash.new { |h, k| h[k] = [] }
            @max_depth = max_depth
            @max_active_per_agent = max_active_per_agent
          end

          def create(from:, to:, task_context:, consent_level:, parent_delegation_id: nil)
            depth = compute_depth(parent_delegation_id)
            return { error: :max_depth_exceeded } if depth >= @max_depth

            if parent_delegation_id
              parent = find(parent_delegation_id)
              return { error: :consent_escalation } if parent && CONSENT_LEVELS.index(consent_level) > CONSENT_LEVELS.index(parent[:consent_level])
            end

            active_count = (@agent_delegations[from] || []).count do |id|
              @delegations[id]&.fetch(:status, nil) == :active
            end
            return { error: :max_active_exceeded } if active_count >= @max_active_per_agent

            id = "del-#{SecureRandom.uuid}"
            record = {
              delegation_id:        id,
              from_agent_id:        from,
              to_agent_id:          to,
              task_context:         task_context,
              consent_level:        consent_level,
              parent_delegation_id: parent_delegation_id,
              depth:                depth,
              status:               :active,
              created_at:           Time.now.utc,
              completed_at:         nil
            }
            @delegations[id] = record
            @agent_delegations[from] << id
            @agent_delegations[to] << id
            record
          end

          def complete(delegation_id)
            record = @delegations[delegation_id]
            return nil unless record && record[:status] == :active

            record[:status] = :completed
            record[:completed_at] = Time.now.utc
            record
          end

          def revoke(delegation_id)
            record = @delegations[delegation_id]
            return nil unless record && record[:status] == :active

            record[:status] = :revoked
            record[:completed_at] = Time.now.utc
            cascade_revoke(delegation_id)
            record
          end

          def chain(delegation_id)
            result = []
            current = @delegations[delegation_id]
            while current
              result.unshift(current)
              current = current[:parent_delegation_id] ? @delegations[current[:parent_delegation_id]] : nil
            end
            result
          end

          def for_agent(agent_id, status: nil)
            ids = @agent_delegations[agent_id] || []
            results = ids.filter_map { |id| @delegations[id] }
            results = results.select { |d| d[:status] == status } if status
            results
          end

          def find(delegation_id)
            @delegations[delegation_id]
          end

          def stats
            active = @delegations.values.count { |d| d[:status] == :active }
            depths = @delegations.values.map { |d| d[:depth] }
            {
              total:     @delegations.size,
              active:    active,
              avg_depth: depths.empty? ? 0 : depths.sum.to_f / depths.size,
              max_depth: depths.max || 0
            }
          end

          private

          def compute_depth(parent_delegation_id)
            return 0 unless parent_delegation_id

            parent = find(parent_delegation_id)
            (parent&.fetch(:depth, 0) || 0) + 1
          end

          def cascade_revoke(parent_id)
            @delegations.each_value do |d|
              next unless d[:parent_delegation_id] == parent_id && d[:status] == :active

              d[:status] = :revoked
              d[:completed_at] = Time.now.utc
            end
          end
        end
      end
    end
  end
end
