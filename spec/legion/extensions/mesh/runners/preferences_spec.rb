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
