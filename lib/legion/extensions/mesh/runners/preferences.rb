# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module Mesh
      module Runners
        module Preferences
          def query_preferences(target_agent_id:, domains: nil, callback: nil, ttl: 5, **)
            default_profile = Helpers::PreferenceProfile.resolve(owner_id: target_agent_id)

            return { success: true, source: :local_default, profile: default_profile } unless transport_available?

            correlation_id = SecureRandom.uuid
            cb = callback || default_preference_callback(target_agent_id: target_agent_id)
            pending_requests.register(correlation_id: correlation_id, callback: cb, ttl: ttl)

            publish_preference_query(
              target_agent_id: target_agent_id,
              correlation_id:  correlation_id,
              domains:         domains
            )

            { success: true, source: :pending, correlation_id: correlation_id, profile: default_profile }
          rescue StandardError => e
            { success: true, source: :local_default, profile: default_profile, error: e.message }
          end

          def handle_preference_query(**)
            owner_id = local_agent_id
            profile = Helpers::PreferenceProfile.resolve(owner_id: owner_id)

            { success: true, profile: profile, responding_agent_id: local_agent_id }
          rescue StandardError => e
            { success: false, error: e.message }
          end

          def handle_preference_response(correlation_id:, profile:, **)
            resolved = pending_requests.resolve(correlation_id: correlation_id, result: profile)
            { resolved: resolved }
          end

          def expire_pending_requests(**)
            expired = pending_requests.expire
            { expired: expired.size, correlation_ids: expired }
          end

          def dispatch_preference_message(type: nil, **msg)
            case type
            when 'preference_query'
              profile = handle_preference_query(**msg)
              publish_preference_response(msg, profile) if profile[:success]
              profile
            when 'preference_response'
              handle_preference_response(
                correlation_id: msg[:correlation_id],
                profile:        msg[:profile] || {}
              )
            else
              { success: false, error: "unknown preference message type: #{type}" }
            end
          end

          private

          def pending_requests
            @pending_requests ||= Helpers::PendingRequests.new
          end

          def transport_available?
            defined?(Legion::Transport::Connection) &&
              Legion::Transport::Connection.respond_to?(:session)
          end

          def local_agent_id
            if defined?(Legion::Settings)
              Legion::Settings['client']['name']
            else
              'unknown'
            end
          end

          def publish_preference_response(msg, profile)
            return unless transport_available?

            Transport::Messages::PreferenceResponse.new(
              target_agent_id:     msg[:requesting_agent_id],
              responding_agent_id: local_agent_id,
              profile:             profile[:profile],
              correlation_id:      msg[:correlation_id]
            ).publish
          rescue StandardError => e
            log_debug("[mesh] failed to publish preference response: #{e.message}")
          end

          def publish_preference_query(target_agent_id:, correlation_id:, domains:)
            Transport::Messages::PreferenceQuery.new(
              target_agent_id:     target_agent_id,
              requesting_agent_id: local_agent_id,
              domains:             domains || [],
              reply_to:            "agent.#{local_agent_id}.preferences",
              correlation_id:      correlation_id
            ).publish
          end

          def default_preference_callback(target_agent_id:)
            lambda do |profile|
              log_debug("[mesh] received preferences for #{target_agent_id}: #{profile.keys.join(', ')}")
            end
          end

          def log_debug(msg)
            Legion::Logging.debug(msg) if defined?(Legion::Logging)
          end
        end
      end
    end
  end
end
