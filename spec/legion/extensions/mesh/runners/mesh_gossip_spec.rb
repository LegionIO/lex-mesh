# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Gossip runner methods' do
  subject { Object.new.extend(Legion::Extensions::Mesh::Runners::Mesh) }

  before do
    allow(subject).to receive(:mesh_registry).and_return(
      Legion::Extensions::Mesh::Helpers::Registry.new # rubocop:disable Legion/Singleton/UseInstance
    )
  end

  describe '#merge_gossip' do
    it 'adds unknown agents from incoming gossip' do
      incoming = [
        { agent_id: 'remote-1', capabilities: [:test], node: 'node-02',
          source: :native, status: :online, generation: 5,
          last_seen: Time.now.utc.to_s, registered_at: Time.now.utc.to_s }
      ]
      result = subject.merge_gossip(incoming_peers: incoming, sender: 'node-02')
      expect(result[:success]).to be true
      expect(result[:merged]).to eq(1)
    end

    it 'updates agents with higher generation' do
      registry = subject.send(:mesh_registry)
      registry.register_agent('agent-1', capabilities: [:old], node: 'node-01')

      incoming = [
        { agent_id: 'agent-1', capabilities: [:updated], node: 'node-01',
          source: :native, status: :online, generation: 99,
          last_seen: Time.now.utc.to_s, registered_at: Time.now.utc.to_s }
      ]
      result = subject.merge_gossip(incoming_peers: incoming, sender: 'node-01')
      expect(result[:merged]).to eq(1)
      expect(registry.agents['agent-1'][:generation]).to eq(99)
    end

    it 'skips agents from local node' do
      local_name = 'local-node'
      allow(subject).to receive(:local_node_name).and_return(local_name)

      incoming = [
        { agent_id: 'local-agent', node: local_name, generation: 1 }
      ]
      result = subject.merge_gossip(incoming_peers: incoming, sender: 'other-node')
      expect(result[:merged]).to eq(0)
    end

    it 'ignores agents with lower or equal generation' do
      registry = subject.send(:mesh_registry)
      registry.register_agent('agent-1', capabilities: [:test], node: 'node-01')
      # generation is 1 after register

      incoming = [
        { agent_id: 'agent-1', capabilities: [:test], node: 'node-01',
          generation: 1, source: :native, status: :online }
      ]
      result = subject.merge_gossip(incoming_peers: incoming, sender: 'node-02')
      expect(result[:merged]).to eq(0)
    end

    context 'split-brain detection' do
      before do
        allow(subject).to receive(:local_node_name).and_return('local-node')
        allow(subject).to receive(:publish_mesh_conflict)
      end

      it 'detects a conflict when incoming peers claim the local node from a different sender' do
        incoming = [
          { agent_id: 'local-agent', node: 'local-node', generation: 1 }
        ]
        result = subject.merge_gossip(incoming_peers: incoming, sender: 'other-node')
        expect(result[:conflicts]).to eq(1)
      end

      it 'publishes MeshConflict when split-brain is detected' do
        incoming = [
          { agent_id: 'local-agent', node: 'local-node', generation: 1 }
        ]
        subject.merge_gossip(incoming_peers: incoming, sender: 'other-node')
        expect(subject).to have_received(:publish_mesh_conflict).with(
          local_node:       'local-node',
          conflicting_node: 'other-node',
          conflict_agents:  ['local-agent']
        )
      end

      it 'does not publish MeshConflict when sender is the local node' do
        incoming = [
          { agent_id: 'local-agent', node: 'local-node', generation: 1 }
        ]
        subject.merge_gossip(incoming_peers: incoming, sender: 'local-node')
        expect(subject).not_to have_received(:publish_mesh_conflict)
      end

      it 'reports zero conflicts when no peers claim the local node' do
        incoming = [
          { agent_id: 'remote-agent', node: 'remote-node', generation: 1 }
        ]
        result = subject.merge_gossip(incoming_peers: incoming, sender: 'remote-node')
        expect(result[:conflicts]).to eq(0)
      end
    end
  end

  describe '#publish_gossip' do
    it 'returns success with peer count' do
      allow(subject).to receive(:publish_gossip_message)
      result = subject.publish_gossip
      expect(result[:success]).to be true
      expect(result[:peers_broadcast]).to be_a(Integer)
    end
  end
end
