# frozen_string_literal: true

# Stub the framework subscription base class
unless defined?(Legion::Extensions::Actors::Subscription)
  module Legion
    module Extensions
      module Actors
        class Subscription # rubocop:disable Lint/EmptyClass
        end
      end
    end
  end

  $LOADED_FEATURES << 'legion/extensions/actors/subscription'
end

# Stub transport queue class if not loaded
unless defined?(Legion::Extensions::Mesh::Transport::Queues::Gossip)
  module Legion
    module Extensions
      module Mesh
        module Transport
          module Queues
            class Gossip # rubocop:disable Lint/EmptyClass
            end
          end
        end
      end
    end
  end
end

require 'legion/extensions/mesh/runners/mesh'
require 'legion/extensions/mesh/actors/gossip_listener'

RSpec.describe Legion::Extensions::Mesh::Actor::GossipListener do
  subject(:actor) { described_class.new }

  describe '#runner_class' do
    it 'returns the Mesh runner module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Mesh::Runners::Mesh)
    end
  end

  describe '#runner_function' do
    it 'returns dispatch_gossip_message' do
      expect(actor.runner_function).to eq('dispatch_gossip_message')
    end
  end

  describe '#use_runner?' do
    it 'returns false (actor handles dispatch directly without runner pipeline)' do
      expect(actor.use_runner?).to be false
    end
  end

  describe '#check_subtask?' do
    it 'returns false' do
      expect(actor.check_subtask?).to be false
    end
  end

  describe '#generate_task?' do
    it 'returns false' do
      expect(actor.generate_task?).to be false
    end
  end

  describe '#queue' do
    it 'returns the Gossip queue class' do
      expect(actor.queue).to eq(Legion::Extensions::Mesh::Transport::Queues::Gossip)
    end
  end

  describe '#enabled?' do
    context 'when Mesh runner and Transport are both defined' do
      it 'returns truthy' do
        stub_const('Legion::Transport', Module.new)
        expect(actor.enabled?).to be_truthy
      end
    end

    context 'when Transport is not defined' do
      it 'returns falsey' do
        hide_const('Legion::Transport')
        expect(actor.enabled?).to be_falsey
      end
    end
  end
end
