# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Transport::Message)
  module Legion
    module Transport
      class Message
        def initialize(**options)
          @options = options
        end
      end

      module Exchanges
        class Agent
          def self.name
            'Legion::Transport::Exchanges::Agent'
          end
        end
      end
    end
  end
end

require 'legion/extensions/mesh/transport/messages/preference_response'

RSpec.describe Legion::Extensions::Mesh::Transport::Messages::PreferenceResponse do
  subject(:msg) do
    described_class.new(
      target_agent_id:     'agent-1',
      responding_agent_id: 'agent-42',
      profile:             { verbosity: :concise, tone: :professional }
    )
  end

  describe '#exchange' do
    it 'returns the Agent exchange' do
      expect(msg.exchange).to eq(Legion::Transport::Exchanges::Agent)
    end
  end

  describe '#routing_key' do
    it 'routes to target agent' do
      expect(msg.routing_key).to eq('agent.agent-1.preferences')
    end
  end

  describe '#message' do
    it 'includes type preference_response' do
      expect(msg.message[:type]).to eq('preference_response')
    end

    it 'includes responding_agent_id' do
      expect(msg.message[:responding_agent_id]).to eq('agent-42')
    end

    it 'includes profile' do
      expect(msg.message[:profile]).to eq({ verbosity: :concise, tone: :professional })
    end

    it 'includes responded_at timestamp' do
      expect(msg.message[:responded_at]).to be_a(String)
    end
  end

  describe '#type' do
    it 'returns preference_response' do
      expect(msg.type).to eq('preference_response')
    end
  end

  describe 'empty profile default' do
    subject(:msg_no_profile) { described_class.new(target_agent_id: 'x', responding_agent_id: 'y') }

    it 'defaults profile to empty hash' do
      expect(msg_no_profile.message[:profile]).to eq({})
    end
  end
end
