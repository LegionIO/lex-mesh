# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Mesh::Helpers::Delegation do
  subject(:tracker) { described_class.new(max_depth: 3, max_active_per_agent: 5) }

  describe '#create' do
    it 'creates a delegation record' do
      result = tracker.create(from: 'agent-a', to: 'agent-b', task_context: 'task-1', consent_level: :execute)
      expect(result[:delegation_id]).to start_with('del-')
      expect(result[:from_agent_id]).to eq('agent-a')
      expect(result[:to_agent_id]).to eq('agent-b')
      expect(result[:status]).to eq(:active)
      expect(result[:depth]).to eq(0)
    end

    it 'increments depth for chained delegations' do
      d1 = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = tracker.create(from: 'b', to: 'c', task_context: 't', consent_level: :execute,
                          parent_delegation_id: d1[:delegation_id])
      expect(d2[:depth]).to eq(1)
    end

    it 'refuses delegation beyond max depth' do
      d1 = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = tracker.create(from: 'b', to: 'c', task_context: 't', consent_level: :execute,
                          parent_delegation_id: d1[:delegation_id])
      d3 = tracker.create(from: 'c', to: 'd', task_context: 't', consent_level: :execute,
                          parent_delegation_id: d2[:delegation_id])
      d4 = tracker.create(from: 'd', to: 'e', task_context: 't', consent_level: :execute,
                          parent_delegation_id: d3[:delegation_id])
      expect(d4[:error]).to eq(:max_depth_exceeded)
    end

    it 'refuses consent escalation' do
      d1 = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = tracker.create(from: 'b', to: 'c', task_context: 't', consent_level: :admin,
                          parent_delegation_id: d1[:delegation_id])
      expect(d2[:error]).to eq(:consent_escalation)
    end

    it 'allows consent de-escalation' do
      d1 = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :admin)
      d2 = tracker.create(from: 'b', to: 'c', task_context: 't', consent_level: :read,
                          parent_delegation_id: d1[:delegation_id])
      expect(d2[:delegation_id]).to start_with('del-')
    end

    it 'refuses when max active per agent exceeded' do
      5.times { |i| tracker.create(from: 'a', to: "b#{i}", task_context: 't', consent_level: :execute) }
      result = tracker.create(from: 'a', to: 'b6', task_context: 't', consent_level: :execute)
      expect(result[:error]).to eq(:max_active_exceeded)
    end
  end

  describe '#complete' do
    it 'marks a delegation as completed' do
      d = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      result = tracker.complete(d[:delegation_id])
      expect(result[:status]).to eq(:completed)
      expect(result[:completed_at]).to be_a(Time)
    end

    it 'returns nil for non-existent delegation' do
      expect(tracker.complete('del-nonexistent')).to be_nil
    end
  end

  describe '#revoke' do
    it 'marks delegation and children as revoked' do
      d1 = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = tracker.create(from: 'b', to: 'c', task_context: 't', consent_level: :execute,
                          parent_delegation_id: d1[:delegation_id])
      tracker.revoke(d1[:delegation_id])

      expect(tracker.find(d1[:delegation_id])[:status]).to eq(:revoked)
      expect(tracker.find(d2[:delegation_id])[:status]).to eq(:revoked)
    end
  end

  describe '#chain' do
    it 'returns the full delegation chain' do
      d1 = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = tracker.create(from: 'b', to: 'c', task_context: 't', consent_level: :execute,
                          parent_delegation_id: d1[:delegation_id])
      chain = tracker.chain(d2[:delegation_id])
      expect(chain.size).to eq(2)
      expect(chain.first[:from_agent_id]).to eq('a')
      expect(chain.last[:from_agent_id]).to eq('b')
    end
  end

  describe '#for_agent' do
    it 'returns delegations involving an agent' do
      tracker.create(from: 'a', to: 'b', task_context: 't1', consent_level: :execute)
      tracker.create(from: 'a', to: 'c', task_context: 't2', consent_level: :execute)
      tracker.create(from: 'x', to: 'y', task_context: 't3', consent_level: :execute)

      results = tracker.for_agent('a')
      expect(results.size).to eq(2)
    end

    it 'filters by status' do
      d = tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      tracker.create(from: 'a', to: 'c', task_context: 't', consent_level: :execute)
      tracker.complete(d[:delegation_id])

      active = tracker.for_agent('a', status: :active)
      expect(active.size).to eq(1)
    end
  end

  describe '#stats' do
    it 'returns summary statistics' do
      tracker.create(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d = tracker.create(from: 'a', to: 'c', task_context: 't', consent_level: :execute)
      tracker.complete(d[:delegation_id])

      stats = tracker.stats
      expect(stats[:total]).to eq(2)
      expect(stats[:active]).to eq(1)
    end
  end
end
