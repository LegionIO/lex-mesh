# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/mesh/helpers/pending_requests'

RSpec.describe Legion::Extensions::Mesh::Helpers::PendingRequests do
  subject(:tracker) { described_class.new(default_ttl: 5) }

  describe '#register' do
    it 'stores a pending request' do
      tracker.register(correlation_id: 'abc', callback: ->(_r) {})
      expect(tracker.pending?('abc')).to be true
    end

    it 'increments pending_count' do
      expect { tracker.register(correlation_id: 'x', callback: nil) }
        .to change { tracker.pending_count }.by(1)
    end
  end

  describe '#resolve' do
    it 'invokes callback and removes entry' do
      received = nil
      tracker.register(correlation_id: 'r1', callback: ->(result) { received = result })
      result = tracker.resolve(correlation_id: 'r1', result: { verbosity: :concise })
      expect(result).to be true
      expect(received).to eq({ verbosity: :concise })
      expect(tracker.pending?('r1')).to be false
    end

    it 'returns false for unknown correlation_id' do
      result = tracker.resolve(correlation_id: 'nonexistent', result: {})
      expect(result).to be false
    end

    it 'handles nil callback gracefully' do
      tracker.register(correlation_id: 'nil-cb', callback: nil)
      expect { tracker.resolve(correlation_id: 'nil-cb', result: {}) }.not_to raise_error
    end
  end

  describe '#pending?' do
    it 'returns false for unregistered id' do
      expect(tracker.pending?('missing')).to be false
    end
  end

  describe '#pending_count' do
    it 'returns correct count' do
      tracker.register(correlation_id: 'a', callback: nil)
      tracker.register(correlation_id: 'b', callback: nil)
      expect(tracker.pending_count).to eq(2)
    end
  end

  describe '#expire' do
    it 'removes entries past TTL' do
      tracker.register(correlation_id: 'old', callback: nil, ttl: 1)
      entry = tracker.instance_variable_get(:@requests)['old']
      entry[:registered_at] = Time.now - 10
      expired = tracker.expire
      expect(expired).to include('old')
      expect(tracker.pending?('old')).to be false
    end

    it 'does not remove entries within TTL' do
      tracker.register(correlation_id: 'fresh', callback: nil, ttl: 60)
      tracker.expire
      expect(tracker.pending?('fresh')).to be true
    end

    it 'returns array of expired correlation ids' do
      tracker.register(correlation_id: 'e1', callback: nil, ttl: 1)
      tracker.register(correlation_id: 'e2', callback: nil, ttl: 1)
      tracker.instance_variable_get(:@requests).each_value { |e| e[:registered_at] = Time.now - 10 }
      expired = tracker.expire
      expect(expired).to contain_exactly('e1', 'e2')
    end
  end
end
