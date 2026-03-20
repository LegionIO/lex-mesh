# frozen_string_literal: true

require_relative '../helpers/delegation'

module Legion
  module Extensions
    module Mesh
      module Runners
        module Delegation
          include Legion::Extensions::Helpers::Lex if defined?(Legion::Extensions::Helpers::Lex)

          def delegate(from:, to:, task_context:, consent_level: :execute, parent_delegation_id: nil, **) # rubocop:disable Metrics/ParameterLists
            result = delegation_tracker.create(
              from:                 from,
              to:                   to,
              task_context:         task_context,
              consent_level:        consent_level.to_sym,
              parent_delegation_id: parent_delegation_id
            )
            return { success: false, **result } if result[:error]

            publish_delegation_event('delegation.created', result)
            { success: true, delegation_id: result[:delegation_id], depth: result[:depth] }
          end

          def complete_delegation(delegation_id:, **)
            result = delegation_tracker.complete(delegation_id)
            return { success: false, reason: :not_found_or_inactive } unless result

            publish_delegation_event('delegation.completed', result)
            { success: true, delegation_id: delegation_id }
          end

          def revoke_delegation(delegation_id:, **)
            result = delegation_tracker.revoke(delegation_id)
            return { success: false, reason: :not_found_or_inactive } unless result

            publish_delegation_event('delegation.revoked', result)
            { success: true, delegation_id: delegation_id }
          end

          def delegation_chain(delegation_id:, **)
            chain = delegation_tracker.chain(delegation_id)
            { success: true, chain: chain, depth: [chain.size - 1, 0].max }
          end

          def agent_delegations(agent_id:, status: nil, **)
            results = delegation_tracker.for_agent(agent_id, status: status&.to_sym)
            { success: true, delegations: results, count: results.size }
          end

          def delegation_stats(**)
            delegation_tracker.stats.merge(success: true)
          end

          private

          def publish_delegation_event(event_type, record)
            return unless defined?(Legion::Extensions::Audit::Transport::Messages::Audit)

            Legion::Extensions::Audit::Transport::Messages::Audit.new(
              event_type:   event_type,
              principal_id: record[:from_agent_id],
              action:       event_type.split('.').last,
              resource:     "delegation:#{record[:delegation_id]}",
              detail:       { to: record[:to_agent_id], depth: record[:depth], consent: record[:consent_level] }
            ).publish
          rescue StandardError => e
            Legion::Logging.warn "[mesh] failed to publish #{event_type}: #{e.message}" if defined?(Legion::Logging)
          end

          def delegation_tracker
            @delegation_tracker ||= begin
              max_depth = nil
              max_active = nil
              if defined?(Legion::Settings)
                max_depth  = Legion::Settings.dig(:mesh, :delegation, :max_depth)
                max_active = Legion::Settings.dig(:mesh, :delegation, :max_active_per_agent)
              end
              Helpers::Delegation.new(max_depth: max_depth || 3, max_active_per_agent: max_active || 10)
            end
          end
        end
      end
    end
  end
end
