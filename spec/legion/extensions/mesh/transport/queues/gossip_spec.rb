# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Transport::Queue)
  module Legion
    module Transport
      class Queue
        def initialize(**); end
      end
    end
  end
end

unless defined?(Legion::Transport::Exchanges::Node)
  module Legion
    module Transport
      module Exchanges
        class Node # rubocop:disable Lint/EmptyClass
        end
      end
    end
  end
end

require 'legion/extensions/mesh/transport/queues/gossip'

RSpec.describe Legion::Extensions::Mesh::Transport::Queues::Gossip do
  subject(:queue) { described_class.allocate }

  describe '#queue_name' do
    it "returns 'mesh.gossip'" do
      expect(queue.queue_name).to eq('mesh.gossip')
    end
  end

  describe '#exchange' do
    it 'returns Legion::Transport::Exchanges::Node' do
      expect(queue.exchange).to eq(Legion::Transport::Exchanges::Node)
    end
  end

  describe '#routing_key' do
    it "returns 'mesh.gossip'" do
      expect(queue.routing_key).to eq('mesh.gossip')
    end
  end
end
