# frozen_string_literal: true

# Stub the framework actor base class since legionio gem is not available in test
module Legion
  module Extensions
    module Actors
      class Every # rubocop:disable Lint/EmptyClass
      end
    end
  end
end unless defined?(Legion::Extensions::Actors::Every)

$LOADED_FEATURES << 'legion/extensions/actors/every' unless $LOADED_FEATURES.include?('legion/extensions/actors/every')

require 'legion/extensions/mesh/actors/gossip'

RSpec.describe Legion::Extensions::Mesh::Actor::Gossip do
  it 'fires every 15 seconds' do
    expect(described_class.new.time).to eq(15)
  end

  it 'calls publish_gossip runner function' do
    instance = described_class.allocate
    expect(instance.runner_function).to eq(:publish_gossip)
  end
end
