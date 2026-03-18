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

unless defined?(Legion::Transport::Exchanges::Node)
  module Legion
    module Transport
      module Exchanges
        class Node # rubocop:disable Lint/EmptyClass
        end
      end
    end
  end
end

require 'legion/extensions/mesh/transport/messages/mesh_departure'

RSpec.describe Legion::Extensions::Mesh::Transport::Messages::MeshDeparture do
  subject(:msg) do
    described_class.new(
      agent_id:     'agent-42',
      capabilities: %i[code_review search]
    )
  end

  describe '#exchange' do
    it 'returns the Node exchange' do
      expect(msg.exchange).to eq(Legion::Transport::Exchanges::Node)
    end
  end

  describe '#routing_key' do
    it 'uses mesh.departure' do
      expect(msg.routing_key).to eq('mesh.departure')
    end
  end

  describe '#message' do
    it 'includes type mesh_departure' do
      expect(msg.message[:type]).to eq('mesh_departure')
    end

    it 'includes agent_id' do
      expect(msg.message[:agent_id]).to eq('agent-42')
    end

    it 'includes capabilities' do
      expect(msg.message[:capabilities]).to eq(%i[code_review search])
    end

    it 'includes departed_at timestamp' do
      expect(msg.message[:departed_at]).to be_a(String)
    end
  end

  describe '#type' do
    it 'returns mesh_departure' do
      expect(msg.type).to eq('mesh_departure')
    end
  end

  describe 'empty capabilities default' do
    subject(:msg_no_caps) { described_class.new(agent_id: 'x') }

    it 'defaults capabilities to empty array' do
      expect(msg_no_caps.message[:capabilities]).to eq([])
    end
  end
end
