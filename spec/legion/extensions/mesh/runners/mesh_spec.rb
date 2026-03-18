# frozen_string_literal: true

require 'legion/extensions/mesh/client'

RSpec.describe Legion::Extensions::Mesh::Runners::Mesh do
  let(:client) { Legion::Extensions::Mesh::Client.new }

  describe '#register' do
    it 'registers an agent' do
      result = client.register(agent_id: 'agent-1', capabilities: [:search])
      expect(result[:registered]).to be true
    end
  end

  describe '#unregister' do
    it 'unregisters a known agent' do
      client.register(agent_id: 'agent-1')
      result = client.unregister(agent_id: 'agent-1')
      expect(result[:unregistered]).to be true
    end

    it 'returns error for unknown agent' do
      result = client.unregister(agent_id: 'unknown')
      expect(result[:error]).to eq(:not_found)
    end

    it 'publishes mesh departure signal when transport available' do
      client.register(agent_id: 'agent-1', capabilities: [:search])

      mock_msg = instance_double('MeshDeparture', publish: nil)
      stub_const('Legion::Extensions::Mesh::Transport::Messages::MeshDeparture', class_double('MeshDeparture', new: mock_msg))

      client.unregister(agent_id: 'agent-1')
      expect(mock_msg).to have_received(:publish)
    end

    it 'succeeds without transport available' do
      client.register(agent_id: 'agent-1')
      result = client.unregister(agent_id: 'agent-1')
      expect(result[:unregistered]).to be true
    end
  end

  describe '#send_message' do
    it 'sends unicast message' do
      client.register(agent_id: 'agent-1')
      result = client.send_message(from: 'agent-2', to: 'agent-1', payload: { text: 'hello' })
      expect(result[:sent]).to be true
      expect(result[:count]).to eq(1)
    end

    it 'sends multicast by capability' do
      client.register(agent_id: 'agent-1', capabilities: [:search])
      client.register(agent_id: 'agent-2', capabilities: [:search])
      client.register(agent_id: 'agent-3', capabilities: [:compute])
      result = client.send_message(from: 'x', capability: :search, pattern: :multicast)
      expect(result[:count]).to eq(2)
    end

    it 'sends broadcast' do
      client.register(agent_id: 'a1')
      client.register(agent_id: 'a2')
      result = client.send_message(from: 'x', pattern: :broadcast)
      expect(result[:count]).to eq(2)
    end
  end

  describe '#find_agents' do
    it 'finds agents by capability' do
      client.register(agent_id: 'a1', capabilities: [:code_review])
      result = client.find_agents(capability: :code_review)
      expect(result[:count]).to eq(1)
    end
  end

  describe '#mesh_status' do
    it 'returns status' do
      client.register(agent_id: 'a1')
      status = client.mesh_status
      expect(status[:total]).to eq(1)
      expect(status[:online]).to eq(1)
    end
  end
end
