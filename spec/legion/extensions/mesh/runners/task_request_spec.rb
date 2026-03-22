# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/mesh/runners/task_request'

RSpec.describe Legion::Extensions::Mesh::Runners::TaskRequest do
  subject(:runner) { Object.new.extend(described_class) }

  before do
    runner.instance_variable_set(:@mesh_registry, nil)
    runner.instance_variable_set(:@task_pending, nil)
    runner.instance_variable_set(:@delegation_tracker, nil)
  end

  describe '#request_task' do
    before do
      runner.register(agent_id: 'requester', capabilities: [:orchestration])
      runner.register(agent_id: 'worker-1', capabilities: [:code_review])
      runner.register(agent_id: 'worker-2', capabilities: %i[code_review testing])
    end

    it 'sends a task request to a specific agent by ID' do
      result = runner.request_task(from: 'requester', to: 'worker-1',
                                   task: 'review_code', payload: { file: 'app.rb' })
      expect(result[:success]).to be true
      expect(result[:correlation_id]).to be_a(String)
      expect(result[:delegation_id]).to start_with('del-')
      expect(result[:target_agent]).to eq('worker-1')
    end

    it 'routes to an agent by capability when to: is not a registered agent' do
      result = runner.request_task(from: 'requester', to: 'code_review',
                                   task: 'review_code', payload: {})
      expect(result[:success]).to be true
      expect(%w[worker-1 worker-2]).to include(result[:target_agent])
    end

    it 'returns error when no agent found for capability' do
      result = runner.request_task(from: 'requester', to: 'nonexistent_capability',
                                   task: 'do_thing', payload: {})
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:no_agent_found)
    end

    it 'registers a pending request' do
      result = runner.request_task(from: 'requester', to: 'worker-1',
                                   task: 'review', payload: {}, timeout: 60)
      expect(runner.send(:task_pending).pending?(result[:correlation_id])).to be true
    end
  end

  describe '#handle_task_reply' do
    it 'resolves a pending request' do
      runner.register(agent_id: 'req', capabilities: [])
      runner.register(agent_id: 'wrk', capabilities: [:work])

      req = runner.request_task(from: 'req', to: 'wrk', task: 'test', payload: {})
      result = runner.handle_task_reply(
        correlation_id: req[:correlation_id],
        result:         { status: :completed, output: 'done' }
      )
      expect(result[:success]).to be true
      expect(result[:resolved]).to be true
    end

    it 'returns not_found for unknown correlation_id' do
      result = runner.handle_task_reply(correlation_id: 'unknown', result: {})
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:not_found)
    end
  end

  describe '#pending_task_stats' do
    it 'returns count of pending requests' do
      runner.register(agent_id: 'a', capabilities: [])
      runner.register(agent_id: 'b', capabilities: [:work])
      runner.request_task(from: 'a', to: 'b', task: 't', payload: {})
      stats = runner.pending_task_stats
      expect(stats[:success]).to be true
      expect(stats[:pending_count]).to be >= 1
    end
  end

  describe '#expire_pending_tasks' do
    it 'expires timed-out requests' do
      result = runner.expire_pending_tasks
      expect(result[:success]).to be true
      expect(result[:expired_count]).to eq(0)
    end
  end
end
