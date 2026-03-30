# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/mesh/helpers/peer_table'

RSpec.describe Legion::Extensions::Mesh::Helpers::PeerTable do
  subject(:table) { described_class.new(ttl: 60) }

  describe '#upsert / #get' do
    it 'stores and retrieves a peer entry' do
      table.upsert('agent-1', { node: 'node-01' })
      entry = table.get('agent-1')
      expect(entry[:node]).to eq('node-01')
    end

    it 'sets last_seen_at on upsert' do
      table.upsert('agent-1', {})
      expect(table.get('agent-1')[:last_seen_at]).to be_a(Time)
    end

    it 'overwrites an existing entry on re-upsert' do
      table.upsert('agent-1', { node: 'node-01' })
      table.upsert('agent-1', { node: 'node-02' })
      expect(table.get('agent-1')[:node]).to eq('node-02')
    end

    it 'returns nil for unknown agent' do
      expect(table.get('missing')).to be_nil
    end
  end

  describe '#expire' do
    let(:short_ttl_table) { described_class.new(ttl: 1) }

    it 'removes peers whose last_seen_at is older than TTL' do
      short_ttl_table.upsert('old-agent', {})
      entry = short_ttl_table.instance_variable_get(:@peers)['old-agent']
      entry[:last_seen_at] = Time.now.utc - 120
      expired = short_ttl_table.expire
      expect(expired).to include('old-agent')
      expect(short_ttl_table.get('old-agent')).to be_nil
    end

    it 'keeps peers within TTL' do
      short_ttl_table.upsert('fresh-agent', {})
      short_ttl_table.expire
      expect(short_ttl_table.get('fresh-agent')).not_to be_nil
    end

    it 'returns an array of expired agent IDs' do
      short_ttl_table.upsert('e1', {})
      short_ttl_table.upsert('e2', {})
      short_ttl_table.instance_variable_get(:@peers).each_value { |e| e[:last_seen_at] = Time.now.utc - 120 }
      expired = short_ttl_table.expire
      expect(expired).to contain_exactly('e1', 'e2')
    end

    it 'returns empty array when nothing is expired' do
      table.upsert('fresh', {})
      expect(table.expire).to be_empty
    end
  end

  describe 'thread safety' do
    it 'handles concurrent upserts without data corruption' do
      threads = Array.new(10) do |i|
        Thread.new { table.upsert("agent-#{i}", { node: "node-#{i}" }) }
      end
      threads.each(&:join)
      expect(table.count).to eq(10)
    end
  end

  describe '#count' do
    it 'reflects the number of stored peers' do
      table.upsert('a1', {})
      table.upsert('a2', {})
      expect(table.count).to eq(2)
    end
  end

  describe '#remove' do
    it 'removes a specific peer' do
      table.upsert('agent-1', {})
      table.remove('agent-1')
      expect(table.get('agent-1')).to be_nil
    end

    it 'does nothing for unknown agent' do
      expect { table.remove('missing') }.not_to raise_error
    end
  end

  describe '#all' do
    it 'returns a copy of all peers' do
      table.upsert('a1', { node: 'n1' })
      all = table.all
      expect(all.keys).to include('a1')
      all.delete('a1')
      expect(table.get('a1')).not_to be_nil
    end
  end
end
