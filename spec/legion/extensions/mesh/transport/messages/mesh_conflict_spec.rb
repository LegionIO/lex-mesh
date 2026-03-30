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

require 'legion/extensions/mesh/transport/messages/mesh_conflict'

RSpec.describe Legion::Extensions::Mesh::Transport::Messages::MeshConflict do
  subject(:msg) do
    described_class.new(
      local_node:       'node-01',
      conflicting_node: 'node-02',
      conflict_agents:  %w[agent-a agent-b]
    )
  end

  describe '#exchange' do
    it 'returns the Node exchange' do
      expect(msg.exchange).to eq(Legion::Transport::Exchanges::Node)
    end
  end

  describe '#routing_key' do
    it 'uses mesh.conflict' do
      expect(msg.routing_key).to eq('mesh.conflict')
    end
  end

  describe '#message' do
    it 'includes type mesh_conflict' do
      expect(msg.message[:type]).to eq('mesh_conflict')
    end

    it 'includes local_node' do
      expect(msg.message[:local_node]).to eq('node-01')
    end

    it 'includes conflicting_node' do
      expect(msg.message[:conflicting_node]).to eq('node-02')
    end

    it 'includes conflict_agents list' do
      expect(msg.message[:conflict_agents]).to eq(%w[agent-a agent-b])
    end

    it 'includes detected_at timestamp string' do
      expect(msg.message[:detected_at]).to be_a(String)
    end
  end

  describe '#type' do
    it 'returns mesh_conflict' do
      expect(msg.type).to eq('mesh_conflict')
    end
  end

  describe 'conflict_agents default' do
    subject(:msg_no_agents) do
      described_class.new(local_node: 'node-01', conflicting_node: 'node-02')
    end

    it 'defaults conflict_agents to empty array' do
      expect(msg_no_agents.message[:conflict_agents]).to eq([])
    end
  end
end
