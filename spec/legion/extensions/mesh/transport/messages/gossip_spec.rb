# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Transport::Message)
  module Legion
    module Transport
      class Message
        def initialize(**options)
          @options = options
        end
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
require 'legion/extensions/mesh/transport/messages/gossip'

RSpec.describe Legion::Extensions::Mesh::Transport::Messages::Gossip do
  subject do
    described_class.new(
      sender:       'node-01',
      gossip_round: 5,
      peers:        [{ agent_id: 'w1', capabilities: [:test], node: 'node-01', generation: 3 }]
    )
  end

  it 'uses the fanout exchange' do
    expect(subject.exchange).to eq(Legion::Extensions::Mesh::Transport::Exchanges::Fanout)
  end

  it 'routes to mesh.gossip' do
    expect(subject.routing_key).to eq('mesh.gossip')
  end

  it 'includes sender and peers in the message body' do
    msg = subject.message
    expect(msg[:type]).to eq('mesh_gossip')
    expect(msg[:sender]).to eq('node-01')
    expect(msg[:peers]).to be_an(Array)
    expect(msg[:gossip_round]).to eq(5)
  end
end
