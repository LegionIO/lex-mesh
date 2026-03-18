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
    end
  end
end

unless defined?(Legion::Transport::Exchanges::Agent)
  module Legion
    module Transport
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

require 'legion/extensions/mesh/transport/messages/preference_query'

RSpec.describe Legion::Extensions::Mesh::Transport::Messages::PreferenceQuery do
  subject(:msg) do
    described_class.new(
      target_agent_id:     'agent-42',
      requesting_agent_id: 'agent-1',
      domains:             %i[verbosity tone]
    )
  end

  describe '#exchange' do
    it 'returns the Agent exchange' do
      expect(msg.exchange).to eq(Legion::Transport::Exchanges::Agent)
    end
  end

  describe '#routing_key' do
    it 'routes to target agent' do
      expect(msg.routing_key).to eq('agent.agent-42.preferences')
    end
  end

  describe '#message' do
    it 'includes type preference_query' do
      expect(msg.message[:type]).to eq('preference_query')
    end

    it 'includes requesting_agent_id' do
      expect(msg.message[:requesting_agent_id]).to eq('agent-1')
    end

    it 'includes domains' do
      expect(msg.message[:domains]).to eq(%i[verbosity tone])
    end

    it 'includes requested_at timestamp' do
      expect(msg.message[:requested_at]).to be_a(String)
    end
  end

  describe '#type' do
    it 'returns preference_query' do
      expect(msg.type).to eq('preference_query')
    end
  end

  describe 'empty domains default' do
    subject(:msg_no_domains) { described_class.new(target_agent_id: 'x', requesting_agent_id: 'y') }

    it 'defaults domains to empty array' do
      expect(msg_no_domains.message[:domains]).to eq([])
    end
  end
end
