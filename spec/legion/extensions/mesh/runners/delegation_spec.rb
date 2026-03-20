# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Mesh::Runners::Delegation do
  subject { Object.new.extend(described_class) }

  before do
    subject.instance_variable_set(:@delegation_tracker, nil)
  end

  describe '#delegate' do
    it 'creates a delegation' do
      result = subject.delegate(from: 'a', to: 'b', task_context: 'task-1', consent_level: :execute)
      expect(result[:success]).to be true
      expect(result[:delegation_id]).to start_with('del-')
      expect(result[:depth]).to eq(0)
    end

    it 'returns failure for depth exceeded' do
      d1 = subject.delegate(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = subject.delegate(from: 'b', to: 'c', task_context: 't', consent_level: :execute,
                            parent_delegation_id: d1[:delegation_id])
      d3 = subject.delegate(from: 'c', to: 'd', task_context: 't', consent_level: :execute,
                            parent_delegation_id: d2[:delegation_id])
      d4 = subject.delegate(from: 'd', to: 'e', task_context: 't', consent_level: :execute,
                            parent_delegation_id: d3[:delegation_id])
      expect(d4[:success]).to be false
    end
  end

  describe '#complete_delegation' do
    it 'completes an active delegation' do
      d = subject.delegate(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      result = subject.complete_delegation(delegation_id: d[:delegation_id])
      expect(result[:success]).to be true
    end

    it 'fails for non-existent delegation' do
      result = subject.complete_delegation(delegation_id: 'del-fake')
      expect(result[:success]).to be false
    end
  end

  describe '#revoke_delegation' do
    it 'revokes an active delegation' do
      d = subject.delegate(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      result = subject.revoke_delegation(delegation_id: d[:delegation_id])
      expect(result[:success]).to be true
    end
  end

  describe '#delegation_chain' do
    it 'returns the full chain' do
      d1 = subject.delegate(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      d2 = subject.delegate(from: 'b', to: 'c', task_context: 't', consent_level: :execute,
                            parent_delegation_id: d1[:delegation_id])
      result = subject.delegation_chain(delegation_id: d2[:delegation_id])
      expect(result[:success]).to be true
      expect(result[:chain].size).to eq(2)
      expect(result[:depth]).to eq(1)
    end
  end

  describe '#agent_delegations' do
    it 'lists delegations for an agent' do
      subject.delegate(from: 'a', to: 'b', task_context: 't1', consent_level: :execute)
      subject.delegate(from: 'a', to: 'c', task_context: 't2', consent_level: :execute)
      result = subject.agent_delegations(agent_id: 'a')
      expect(result[:success]).to be true
      expect(result[:count]).to eq(2)
    end
  end

  describe '#delegation_stats' do
    it 'returns statistics' do
      subject.delegate(from: 'a', to: 'b', task_context: 't', consent_level: :execute)
      result = subject.delegation_stats
      expect(result[:success]).to be true
      expect(result[:total]).to eq(1)
      expect(result[:active]).to eq(1)
    end
  end
end
