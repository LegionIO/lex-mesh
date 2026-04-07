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

unless defined?(Legion::Transport::Queue)
  module Legion
    module Transport
      class Queue
        def initialize(**); end
      end
    end
  end
end

unless defined?(Legion::Transport::Exchange)
  module Legion
    module Transport
      class Exchange; end # rubocop:disable Lint/EmptyClass
    end
  end
end

require 'legion/extensions/mesh/transport/exchanges/fanout'
require 'legion/extensions/mesh/transport/queues/gossip'

RSpec.describe Legion::Extensions::Mesh::Transport::Queues::Gossip do
  subject(:queue) { described_class.allocate }

  describe '#queue_name' do
    it "returns 'mesh.gossip'" do
      expect(queue.queue_name).to eq('mesh.gossip')
    end
  end

  describe '#exchange' do
    it 'returns the Fanout exchange' do
      expect(queue.exchange).to eq(Legion::Extensions::Mesh::Transport::Exchanges::Fanout)
    end
  end
end
