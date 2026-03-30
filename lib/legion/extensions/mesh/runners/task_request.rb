# frozen_string_literal: true

require 'securerandom'
require_relative '../helpers/pending_requests'
require_relative '../helpers/delegation'
require_relative '../helpers/registry'
require_relative 'mesh'

module Legion
  module Extensions
    module Mesh
      module Runners
        module TaskRequest # rubocop:disable Legion/Extension/RunnerIncludeHelpers
          include Runners::Mesh

          DEFAULT_TIMEOUT = 30

          def request_task(from:, to:, task:, payload:, timeout: DEFAULT_TIMEOUT, consent_level: :execute, **)
            target_id = resolve_target(to)
            return { success: false, reason: :no_agent_found, requested: to } unless target_id

            correlation_id = "task-#{SecureRandom.uuid}"

            delegation = delegation_tracker.create(
              from: from, to: target_id,
              task_context: task, consent_level: consent_level
            )
            return { success: false, reason: delegation[:error] } if delegation[:error]

            task_pending.register(
              correlation_id: correlation_id,
              callback:       nil,
              ttl:            timeout
            )

            send_message(from: from, to: target_id, pattern: :unicast,
                         payload: { type: :task_request, correlation_id: correlation_id,
                                    task: task, payload: payload, reply_to: from })

            log.info "[mesh-task] request: from=#{from} to=#{target_id} task=#{task} cid=#{correlation_id[0..11]}"
            { success: true, correlation_id: correlation_id, delegation_id: delegation[:delegation_id],
              target_agent: target_id }
          end

          def handle_task_reply(correlation_id:, result:, **)
            resolved = task_pending.resolve(correlation_id: correlation_id, result: result)
            if resolved
              log.debug "[mesh-task] reply resolved: cid=#{correlation_id[0..11]}"
              { success: true, resolved: true, correlation_id: correlation_id }
            else
              { success: false, reason: :not_found, correlation_id: correlation_id }
            end
          end

          def pending_task_stats(**)
            { success: true, pending_count: task_pending.pending_count }
          end

          def expire_pending_tasks(**)
            expired = task_pending.expire
            log.debug "[mesh-task] expired #{expired.size} pending tasks" unless expired.empty?
            { success: true, expired_count: expired.size, expired_ids: expired }
          end

          private

          def resolve_target(to)
            return to if mesh_registry.agents.key?(to) # rubocop:disable Legion/Extension/RunnerReturnHash

            agents = mesh_registry.find_by_capability(to.to_sym)
            return nil if agents.empty? # rubocop:disable Legion/Extension/RunnerReturnHash

            online = agents.select { |a| a[:status] == :online }
            (online.empty? ? agents : online).sample[:agent_id]
          end

          def task_pending
            @task_pending ||= Helpers::PendingRequests.new(default_ttl: DEFAULT_TIMEOUT)
          end

          def delegation_tracker
            @delegation_tracker ||= Helpers::Delegation.new
          end
        end
      end
    end
  end
end
