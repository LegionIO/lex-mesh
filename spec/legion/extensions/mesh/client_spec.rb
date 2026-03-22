# frozen_string_literal: true

require 'legion/extensions/mesh/client'

RSpec.describe Legion::Extensions::Mesh::Client do
  let(:client) { described_class.new }

  it 'responds to mesh runner methods' do
    expect(client).to respond_to(:register)
    expect(client).to respond_to(:unregister)
    expect(client).to respond_to(:heartbeat)
    expect(client).to respond_to(:send_message)
    expect(client).to respond_to(:find_agents)
    expect(client).to respond_to(:mesh_status)
  end

  it 'responds to preference runner methods' do
    expect(client).to respond_to(:query_preferences)
    expect(client).to respond_to(:handle_preference_query)
    expect(client).to respond_to(:handle_preference_response)
    expect(client).to respond_to(:expire_pending_requests)
  end

  describe '#query_preferences' do
    it 'returns a result hash with success key' do
      result = client.query_preferences(target_agent_id: 'agent-1')
      expect(result).to have_key(:success)
      expect(result[:success]).to be true
    end
  end

  describe '#handle_preference_query' do
    it 'returns local profile' do
      result = client.handle_preference_query(requesting_agent_id: 'agent-1')
      expect(result[:success]).to be true
      expect(result[:profile]).to be_a(Hash)
    end
  end

  describe '#handle_preference_response' do
    it 'returns resolved false for unknown id' do
      result = client.handle_preference_response(correlation_id: 'nope', profile: {})
      expect(result[:resolved]).to be false
    end
  end

  describe '#expire_pending_requests' do
    it 'returns expiry summary' do
      result = client.expire_pending_requests
      expect(result).to have_key(:expired)
      expect(result[:expired]).to eq(0)
    end
  end

  it 'responds to delegation runner methods' do
    expect(client).to respond_to(:delegate)
    expect(client).to respond_to(:complete_delegation)
    expect(client).to respond_to(:revoke_delegation)
  end

  it 'responds to task request runner methods' do
    expect(client).to respond_to(:request_task)
    expect(client).to respond_to(:handle_task_reply)
    expect(client).to respond_to(:pending_task_stats)
  end

  describe '#request_task' do
    it 'sends a task request via the client' do
      client.register(agent_id: 'a', capabilities: [:orchestration])
      client.register(agent_id: 'b', capabilities: [:review])
      result = client.request_task(from: 'a', to: 'b', task: 'review', payload: {})
      expect(result[:success]).to be true
      expect(result[:target_agent]).to eq('b')
    end
  end
end
