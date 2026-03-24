# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Transport::Queues::Agent)
  module Legion
    module Transport
      module Queues
        class Agent
          def initialize(agent_id: nil, **)
            @agent_id = agent_id
          end

          def queue_name
            @agent_id ? "agent.#{@agent_id}" : 'agent.default'
          end
        end
      end
    end
  end
end

require 'legion/extensions/mesh/transport/queues/preference'

RSpec.describe Legion::Extensions::Mesh::Transport::Queues::Preference do
  describe 'with explicit agent_id' do
    subject(:queue) { described_class.allocate.tap { |q| q.instance_variable_set(:@agent_id, 'worker-1') } }

    describe '#queue_name' do
      it 'appends .preferences to the agent queue name' do
        expect(queue.queue_name).to eq('agent.worker-1.preferences')
      end
    end

    describe '#bind_routing_key' do
      it 'returns the preferences routing key' do
        expect(queue.bind_routing_key).to eq('agent.worker-1.preferences')
      end
    end
  end

  describe 'with default agent_id from settings' do
    subject(:queue) { described_class.allocate.tap { |q| q.instance_variable_set(:@agent_id, nil) } }

    before do
      stub_const('Legion::Settings', { client: { name: 'my-agent' } })
    end

    describe '#queue_name' do
      it 'uses settings for the agent name' do
        expect(queue.queue_name).to eq('agent.my-agent.preferences')
      end
    end

    describe '#bind_routing_key' do
      it 'uses settings for the routing key' do
        expect(queue.bind_routing_key).to eq('agent.my-agent.preferences')
      end
    end
  end
end
