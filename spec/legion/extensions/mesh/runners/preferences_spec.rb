# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/mesh/helpers/pending_requests'
require 'legion/extensions/mesh/helpers/preference_profile'
require 'legion/extensions/mesh/runners/preferences'

RSpec.describe Legion::Extensions::Mesh::Runners::Preferences do
  let(:runner) { Object.new.extend(described_class) }

  describe '#query_preferences' do
    context 'without transport' do
      it 'returns local_default profile' do
        result = runner.query_preferences(target_agent_id: 'agent-99')
        expect(result[:success]).to be true
        expect(result[:source]).to eq(:local_default)
        expect(result[:profile]).to be_a(Hash)
      end

      it 'includes default preference keys in profile' do
        result = runner.query_preferences(target_agent_id: 'agent-99')
        expect(result[:profile]).to have_key(:verbosity)
        expect(result[:profile]).to have_key(:tone)
      end
    end

    context 'with transport available' do
      before do
        stub_const('Legion::Transport::Connection', Class.new do
          def self.session; end
        end)
        stub_const('Legion::Extensions::Mesh::Transport::Messages::PreferenceQuery',
                   Class.new do
                     def initialize(**_opts); end

                     def publish; end
                   end)
      end

      it 'returns pending status with correlation_id' do
        result = runner.query_preferences(target_agent_id: 'agent-42')
        expect(result[:success]).to be true
        expect(result[:source]).to eq(:pending)
        expect(result[:correlation_id]).to be_a(String)
        expect(result[:correlation_id]).not_to be_empty
      end

      it 'registers a pending request' do
        result = runner.query_preferences(target_agent_id: 'agent-42')
        pending_req = runner.send(:pending_requests)
        expect(pending_req.pending?(result[:correlation_id])).to be true
      end
    end
  end

  describe '#handle_preference_query' do
    it 'returns local profile' do
      result = runner.handle_preference_query(requesting_agent_id: 'agent-1')
      expect(result[:success]).to be true
      expect(result[:profile]).to be_a(Hash)
      expect(result[:responding_agent_id]).not_to be_nil
    end

    it 'includes verbosity in profile' do
      result = runner.handle_preference_query(requesting_agent_id: 'agent-1')
      expect(result[:profile]).to have_key(:verbosity)
    end

    context 'with trust module available' do
      let(:trust_runner) do
        Module.new do
          def get_trust(agent_id:, domain: :general, **)
            case agent_id
            when 'trusted-agent' then { found: true, trust: { composite: 0.8 } }
            when 'untrusted-agent' then { found: true, trust: { composite: 0.1 } }
            else { found: false, agent_id: agent_id, domain: domain }
            end
          end
        end
      end

      before do
        stub_const('Legion::Extensions::Agentic::Social::Trust::Runners::Trust', trust_runner)
      end

      it 'returns profile for trusted agents' do
        result = runner.handle_preference_query(requesting_agent_id: 'trusted-agent')
        expect(result[:success]).to be true
        expect(result[:profile]).to be_a(Hash)
      end

      it 'refuses preferences for untrusted agents' do
        result = runner.handle_preference_query(requesting_agent_id: 'untrusted-agent')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:insufficient_trust)
      end

      it 'returns profile for unknown agents (trust not found defaults to open)' do
        result = runner.handle_preference_query(requesting_agent_id: 'unknown-agent')
        expect(result[:success]).to be true
      end
    end
  end

  describe '#handle_preference_response' do
    it 'resolves a pending request' do
      received = nil
      pending_req = runner.send(:pending_requests)
      pending_req.register(
        correlation_id: 'corr-1',
        callback:       ->(profile) { received = profile }
      )
      result = runner.handle_preference_response(
        correlation_id: 'corr-1',
        profile:        { verbosity: :concise }
      )
      expect(result[:resolved]).to be true
      expect(received).to eq({ verbosity: :concise })
    end

    it 'returns false for unknown correlation_id' do
      result = runner.handle_preference_response(
        correlation_id: 'unknown-corr',
        profile:        {}
      )
      expect(result[:resolved]).to be false
    end
  end

  describe '#dispatch_preference_message' do
    context 'with preference_query type' do
      it 'calls handle_preference_query and returns profile' do
        result = runner.dispatch_preference_message(
          type:                'preference_query',
          requesting_agent_id: 'agent-1',
          correlation_id:      'corr-123'
        )
        expect(result[:success]).to be true
        expect(result[:profile]).to be_a(Hash)
      end
    end

    context 'with preference_response type' do
      it 'resolves a pending request' do
        pending_req = runner.send(:pending_requests)
        pending_req.register(correlation_id: 'corr-abc', callback: ->(_p) {})
        result = runner.dispatch_preference_message(
          type:           'preference_response',
          correlation_id: 'corr-abc',
          profile:        { verbosity: :concise }
        )
        expect(result[:resolved]).to be true
      end

      it 'returns false for unknown correlation_id' do
        result = runner.dispatch_preference_message(
          type:           'preference_response',
          correlation_id: 'unknown',
          profile:        {}
        )
        expect(result[:resolved]).to be false
      end
    end

    context 'with unknown type' do
      it 'returns error' do
        result = runner.dispatch_preference_message(type: 'bogus')
        expect(result[:success]).to be false
        expect(result[:error]).to include('unknown')
      end
    end

    context 'with nil type' do
      it 'returns error' do
        result = runner.dispatch_preference_message(type: nil)
        expect(result[:success]).to be false
      end
    end
  end

  describe '#handle_preference_response with mesh caching' do
    it 'caches the received profile' do
      pending_req = runner.send(:pending_requests)
      pending_req.register(
        correlation_id: 'corr-cache',
        callback: ->(profile) { }
      )
      runner.handle_preference_response(
        correlation_id: 'corr-cache',
        profile: { verbosity: :concise, tone: :casual },
        responding_agent_id: 'agent-42'
      )
      cached = Legion::Extensions::Mesh::Helpers::PreferenceProfile.cached_mesh_profile(
        agent_id: 'agent-42'
      )
      expect(cached).to be_a(Hash)
      expect(cached[:verbosity]).to eq(:concise)
    end
  end

  describe 'personality compatibility' do
    context 'without personality module' do
      it 'returns nil compatibility in for_agent' do
        result = Legion::Extensions::Mesh::Helpers::PreferenceProfile.for_agent(agent_id: 'agent-99')
        expect(result[:compatibility]).to be_nil
      end
    end

    context 'with personality module available' do
      let(:personality_runner) do
        Module.new do
          def personality_compatibility(other_profile:, **)
            { compatibility: 0.82, interpretation: :compatible }
          end

          private

          def personality_store
            @personality_store ||= Struct.new(:model).new(nil)
          end
        end
      end

      before do
        stub_const(
          'Legion::Extensions::Agentic::Self::Personality::Runners::Personality',
          personality_runner
        )
      end

      it 'returns compatibility score when personality data exists' do
        Legion::Extensions::Mesh::Helpers::PreferenceProfile.store_mesh_profile(
          agent_id: 'agent-42',
          profile: {
            verbosity: :concise,
            personality: { openness: 0.8, conscientiousness: 0.6 }
          },
          source_agent_id: 'agent-42'
        )
        result = Legion::Extensions::Mesh::Helpers::PreferenceProfile.for_agent(agent_id: 'agent-42')
        expect(result[:compatibility]).to be_a(Hash)
        expect(result[:compatibility][:score]).to eq(0.82)
        expect(result[:compatibility][:interpretation]).to eq(:compatible)
      end
    end
  end

  describe '#expire_pending_requests' do
    it 'cleans up expired entries and returns count' do
      pending_req = runner.send(:pending_requests)
      pending_req.register(correlation_id: 'old-1', callback: nil, ttl: 1)
      pending_req.register(correlation_id: 'old-2', callback: nil, ttl: 1)
      pending_req.instance_variable_get(:@requests).each_value { |e| e[:registered_at] = Time.now - 60 }

      result = runner.expire_pending_requests
      expect(result[:expired]).to eq(2)
      expect(result[:correlation_ids]).to contain_exactly('old-1', 'old-2')
    end

    it 'returns zero when nothing expired' do
      result = runner.expire_pending_requests
      expect(result[:expired]).to eq(0)
      expect(result[:correlation_ids]).to be_empty
    end
  end
end
