# frozen_string_literal: true

require 'base64'

module Legion
  module Extensions
    module Mesh
      module Helpers
        module PeerVerify
          class << self
            def sign_message(payload, private_key_b64)
              require 'ed25519'
              key = Ed25519::SigningKey.new(Base64.strict_decode64(private_key_b64))
              message_bytes = json_dump(payload)
              signature = key.sign(message_bytes)
              { payload: payload, signature: Base64.strict_encode64(signature), signed_bytes: message_bytes }
            end

            def verify_message(signed_message, org_id:)
              peer = find_peer(org_id)
              return { valid: false, org_id: org_id, reason: :unknown_peer } unless peer

              require 'ed25519'
              pub_key_b64 = peer[:public_key].sub(/\Aed25519:/, '')
              verify_key  = Ed25519::VerifyKey.new(Base64.strict_decode64(pub_key_b64))
              signature   = Base64.strict_decode64(signed_message[:signature])
              message_bytes = signed_message[:signed_bytes] || json_dump(signed_message[:payload])
              verify_key.verify(signature, message_bytes)
              { valid: true, org_id: org_id }
            rescue Ed25519::VerifyError
              { valid: false, org_id: org_id, reason: :invalid_signature }
            rescue StandardError => e
              { valid: false, org_id: org_id, reason: :error, message: e.message }
            end

            def check_rate_limit(org_id)
              @counters ||= Hash.new { |h, k| h[k] = { count: 0, window_start: Time.now.utc } }
              counter = @counters[org_id]
              peer  = find_peer(org_id)
              limit = peer&.dig(:rate_limit) || 100

              if Time.now.utc - counter[:window_start] > 60
                counter[:count] = 0
                counter[:window_start] = Time.now.utc
              end

              counter[:count] += 1
              return { allowed: true, remaining: limit - counter[:count] } if counter[:count] <= limit

              { allowed: false, error: :rate_limited, org_id: org_id }
            end

            def reset_counters!
              @counters = nil
            end

            private

            def find_peer(org_id)
              return nil unless defined?(Legion::Settings)

              peers = Legion::Settings.dig(:mesh, :trusted_peers) || []
              peers.find { |p| p[:org_id] == org_id }
            end

            def json_dump(data)
              if defined?(Legion::JSON)
                Legion::JSON.dump({ data: data })
              else
                require 'json'
                ::JSON.dump({ data: data })
              end
            end
          end
        end
      end
    end
  end
end
