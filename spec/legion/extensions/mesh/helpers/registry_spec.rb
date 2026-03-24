# frozen_string_literal: true

RSpec.describe Legion::Extensions::Mesh::Helpers::Registry do
  let(:registry) { described_class.new }

  describe '#initialize' do
    it 'starts with an empty agents hash' do
      expect(registry.agents).to eq({})
    end

    it 'starts with an empty capabilities hash' do
      expect(registry.capabilities).to eq({})
    end

    it 'starts with an empty messages array' do
      expect(registry.messages).to eq([])
    end
  end

  describe '#register_agent' do
    it 'adds the agent to the agents hash' do
      registry.register_agent('agent-1')
      expect(registry.agents).to have_key('agent-1')
    end

    it 'stores the agent_id on the record' do
      registry.register_agent('agent-1')
      expect(registry.agents['agent-1'][:agent_id]).to eq('agent-1')
    end

    it 'defaults status to :online' do
      registry.register_agent('agent-1')
      expect(registry.agents['agent-1'][:status]).to eq(:online)
    end

    it 'stores an empty capabilities array by default' do
      registry.register_agent('agent-1')
      expect(registry.agents['agent-1'][:capabilities]).to eq([])
    end

    it 'stores provided capabilities' do
      registry.register_agent('agent-1', capabilities: %i[search code_review])
      expect(registry.agents['agent-1'][:capabilities]).to eq(%i[search code_review])
    end

    it 'stores the endpoint when provided' do
      registry.register_agent('agent-1', endpoint: 'http://host:9000')
      expect(registry.agents['agent-1'][:endpoint]).to eq('http://host:9000')
    end

    it 'defaults endpoint to nil' do
      registry.register_agent('agent-1')
      expect(registry.agents['agent-1'][:endpoint]).to be_nil
    end

    it 'indexes each capability to the agent_id' do
      registry.register_agent('agent-1', capabilities: [:search])
      expect(registry.capabilities[:search]).to include('agent-1')
    end

    it 'indexes multiple capabilities separately' do
      registry.register_agent('agent-1', capabilities: %i[search compute])
      expect(registry.capabilities[:search]).to include('agent-1')
      expect(registry.capabilities[:compute]).to include('agent-1')
    end

    it 'accumulates multiple agents under the same capability' do
      registry.register_agent('agent-1', capabilities: [:search])
      registry.register_agent('agent-2', capabilities: [:search])
      expect(registry.capabilities[:search]).to include('agent-1', 'agent-2')
    end

    it 'records registered_at as a UTC Time' do
      before = Time.now.utc
      registry.register_agent('agent-1')
      after = Time.now.utc
      ts = registry.agents['agent-1'][:registered_at]
      expect(ts).to be_between(before, after)
    end

    it 'sets last_seen on registration' do
      registry.register_agent('agent-1')
      expect(registry.agents['agent-1'][:last_seen]).not_to be_nil
    end
  end

  describe '#unregister_agent' do
    before { registry.register_agent('agent-1', capabilities: %i[search compute]) }

    it 'removes the agent from agents hash' do
      registry.unregister_agent('agent-1')
      expect(registry.agents).not_to have_key('agent-1')
    end

    it 'returns the removed agent record' do
      result = registry.unregister_agent('agent-1')
      expect(result[:agent_id]).to eq('agent-1')
    end

    it 'removes the agent from each capability index' do
      registry.unregister_agent('agent-1')
      expect(registry.capabilities[:search]).not_to include('agent-1')
      expect(registry.capabilities[:compute]).not_to include('agent-1')
    end

    it 'does not affect other agents in the same capability' do
      registry.register_agent('agent-2', capabilities: [:search])
      registry.unregister_agent('agent-1')
      expect(registry.capabilities[:search]).to include('agent-2')
    end

    it 'returns nil for unknown agent_id' do
      expect(registry.unregister_agent('nonexistent')).to be_nil
    end

    it 'leaves other agents unaffected' do
      registry.register_agent('agent-2')
      registry.unregister_agent('agent-1')
      expect(registry.agents).to have_key('agent-2')
    end
  end

  describe '#heartbeat' do
    before { registry.register_agent('agent-1') }

    it 'updates last_seen to a recent UTC time' do
      before = Time.now.utc
      registry.heartbeat('agent-1')
      after = Time.now.utc
      expect(registry.agents['agent-1'][:last_seen]).to be_between(before, after)
    end

    it 'sets status to :online' do
      registry.agents['agent-1'][:status] = :unknown
      registry.heartbeat('agent-1')
      expect(registry.agents['agent-1'][:status]).to eq(:online)
    end

    it 'returns nil for unknown agent_id' do
      expect(registry.heartbeat('nonexistent')).to be_nil
    end
  end

  describe '#find_by_capability' do
    it 'returns agents that have the requested capability' do
      registry.register_agent('a1', capabilities: [:search])
      registry.register_agent('a2', capabilities: [:search])
      results = registry.find_by_capability(:search)
      ids = results.map { |a| a[:agent_id] }
      expect(ids).to contain_exactly('a1', 'a2')
    end

    it 'returns only agents with that specific capability' do
      registry.register_agent('a1', capabilities: [:search])
      registry.register_agent('a2', capabilities: [:compute])
      results = registry.find_by_capability(:search)
      expect(results.size).to eq(1)
      expect(results.first[:agent_id]).to eq('a1')
    end

    it 'returns an empty array when no agents have the capability' do
      expect(registry.find_by_capability(:nonexistent)).to eq([])
    end

    it 'excludes agents that were unregistered' do
      registry.register_agent('a1', capabilities: [:search])
      registry.unregister_agent('a1')
      expect(registry.find_by_capability(:search)).to eq([])
    end
  end

  describe '#route_message' do
    before do
      registry.register_agent('a1', capabilities: [:search])
      registry.register_agent('a2', capabilities: [:search])
      registry.register_agent('a3', capabilities: [:compute])
    end

    describe 'unicast pattern' do
      it 'delivers to the specified recipient' do
        result = registry.route_message(from: 'sender', to: 'a1', pattern: :unicast, payload: { x: 1 })
        expect(result[:delivered_to]).to eq(['a1'])
      end

      it 'returns empty delivered_to for unknown recipient' do
        result = registry.route_message(from: 'sender', to: 'unknown', pattern: :unicast)
        expect(result[:delivered_to]).to eq([])
      end

      it 'records the message in the buffer' do
        registry.route_message(from: 'sender', to: 'a1', pattern: :unicast)
        expect(registry.messages.size).to eq(1)
      end

      it 'stores from, to, pattern, and payload on the message' do
        registry.route_message(from: 'sender', to: 'a1', pattern: :unicast, payload: { key: 'val' })
        msg = registry.messages.last
        expect(msg[:from]).to eq('sender')
        expect(msg[:to]).to eq('a1')
        expect(msg[:pattern]).to eq(:unicast)
        expect(msg[:payload]).to eq({ key: 'val' })
      end
    end

    describe 'multicast pattern' do
      it 'delivers to all agents with the given capability' do
        result = registry.route_message(from: 'sender', capability: :search, pattern: :multicast)
        expect(result[:delivered_to]).to contain_exactly('a1', 'a2')
      end

      it 'returns empty delivered_to when capability has no agents' do
        result = registry.route_message(from: 'sender', capability: :unknown, pattern: :multicast)
        expect(result[:delivered_to]).to eq([])
      end

      it 'returns empty delivered_to when no capability is given' do
        result = registry.route_message(from: 'sender', pattern: :multicast)
        expect(result[:delivered_to]).to eq([])
      end
    end

    describe 'broadcast pattern' do
      it 'delivers to all registered agents' do
        result = registry.route_message(from: 'sender', pattern: :broadcast)
        expect(result[:delivered_to]).to contain_exactly('a1', 'a2', 'a3')
      end

      it 'returns empty delivered_to when no agents registered' do
        empty = described_class.new
        result = empty.route_message(from: 'sender', pattern: :broadcast)
        expect(result[:delivered_to]).to eq([])
      end
    end

    describe 'unknown pattern' do
      it 'returns empty delivered_to' do
        result = registry.route_message(from: 'sender', pattern: :unknown_pattern)
        expect(result[:delivered_to]).to eq([])
      end
    end

    describe 'hop-count enforcement' do
      it 'delivers normally when hops is below MAX_HOPS' do
        result = registry.route_message(from: 'sender', to: 'a1', pattern: :unicast, hops: 0)
        expect(result[:delivered_to]).to eq(['a1'])
        expect(result[:rejected]).to be_nil
      end

      it 'rejects when hops equals MAX_HOPS' do
        result = registry.route_message(from: 'sender', to: 'a1', pattern: :unicast,
                                        hops: Legion::Extensions::Mesh::Helpers::Topology::MAX_HOPS)
        expect(result[:delivered_to]).to eq([])
        expect(result[:rejected]).to eq(:max_hops_exceeded)
      end

      it 'rejects when hops exceeds MAX_HOPS' do
        result = registry.route_message(from: 'sender', to: 'a1', pattern: :unicast,
                                        hops: Legion::Extensions::Mesh::Helpers::Topology::MAX_HOPS + 1)
        expect(result[:delivered_to]).to eq([])
        expect(result[:rejected]).to eq(:max_hops_exceeded)
      end

      it 'includes :max_hops_exceeded in the rejected field' do
        result = registry.route_message(from: 'sender', pattern: :broadcast,
                                        hops: Legion::Extensions::Mesh::Helpers::Topology::MAX_HOPS)
        expect(result[:rejected]).to eq(:max_hops_exceeded)
      end

      it 'defaults hops to 0 for backward compatibility' do
        result = registry.route_message(from: 'sender', to: 'a1', pattern: :unicast)
        expect(result[:delivered_to]).to eq(['a1'])
        expect(result[:rejected]).to be_nil
      end
    end

    describe 'message buffer cap' do
      it 'shifts old messages when buffer exceeds 1000' do
        1001.times { |i| registry.route_message(from: 'sender', to: "a#{i}", pattern: :unicast) }
        expect(registry.messages.size).to eq(1000)
      end
    end

    it 'stores a timestamp on the message' do
      before = Time.now.utc
      registry.route_message(from: 'sender', pattern: :broadcast)
      after = Time.now.utc
      expect(registry.messages.last[:at]).to be_between(before, after)
    end
  end

  describe '#online_agents' do
    it 'returns agents with :online status' do
      registry.register_agent('a1')
      registry.register_agent('a2')
      expect(registry.online_agents.size).to eq(2)
    end

    it 'excludes agents with non-online status' do
      registry.register_agent('a1')
      registry.agents['a1'][:status] = :offline
      expect(registry.online_agents).to eq([])
    end

    it 'returns an empty array when no agents are registered' do
      expect(registry.online_agents).to eq([])
    end
  end

  describe '#expire_silent_agents' do
    it 'marks stale agents as offline' do
      registry.register_agent('a1')
      registry.agents['a1'][:last_seen] = Time.now.utc - 60
      expired = registry.expire_silent_agents(timeout: 30)
      expect(expired).to eq(['a1'])
      expect(registry.agents['a1'][:status]).to eq(:offline)
    end

    it 'does not expire agents within timeout' do
      registry.register_agent('a1')
      expired = registry.expire_silent_agents(timeout: 30)
      expect(expired).to eq([])
      expect(registry.agents['a1'][:status]).to eq(:online)
    end

    it 'does not expire already-offline agents' do
      registry.register_agent('a1')
      registry.agents['a1'][:last_seen] = Time.now.utc - 60
      registry.agents['a1'][:status] = :offline
      expired = registry.expire_silent_agents(timeout: 30)
      expect(expired).to eq([])
    end

    it 'returns multiple expired agent ids' do
      registry.register_agent('a1')
      registry.register_agent('a2')
      registry.agents['a1'][:last_seen] = Time.now.utc - 60
      registry.agents['a2'][:last_seen] = Time.now.utc - 60
      expired = registry.expire_silent_agents(timeout: 30)
      expect(expired).to contain_exactly('a1', 'a2')
    end

    it 'uses MESH_SILENCE_TIMEOUT as default' do
      registry.register_agent('a1')
      registry.agents['a1'][:last_seen] = Time.now.utc - 31
      expired = registry.expire_silent_agents
      expect(expired).to eq(['a1'])
    end
  end

  describe 'gossip fields' do
    it 'stores source, node, and generation on registration' do
      registry.register_agent('agent-1', capabilities: [:test], source: :native, node: 'node-01')
      agent = registry.agents['agent-1']
      expect(agent[:source]).to eq(:native)
      expect(agent[:node]).to eq('node-01')
      expect(agent[:generation]).to eq(1)
    end

    it 'increments generation on heartbeat' do
      registry.register_agent('agent-1', capabilities: [:test])
      registry.heartbeat('agent-1')
      expect(registry.agents['agent-1'][:generation]).to eq(2)
    end
  end

  describe '#all_agents' do
    it 'returns all agent records as an array' do
      registry.register_agent('a1', capabilities: [:search])
      registry.register_agent('a2', capabilities: [:compute])
      all = registry.all_agents
      expect(all).to be_an(Array)
      expect(all.size).to eq(2)
    end
  end

  describe '#count' do
    it 'returns 0 for an empty registry' do
      expect(registry.count).to eq(0)
    end

    it 'returns the number of registered agents' do
      registry.register_agent('a1')
      registry.register_agent('a2')
      expect(registry.count).to eq(2)
    end

    it 'decrements after unregistration' do
      registry.register_agent('a1')
      registry.unregister_agent('a1')
      expect(registry.count).to eq(0)
    end
  end
end
