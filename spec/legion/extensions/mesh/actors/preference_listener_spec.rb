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

# Stub transport queue base classes if not loaded
unless defined?(Legion::Transport::Queues::Agent)
  module Legion
    module Transport
      module Queues
        class Agent # rubocop:disable Lint/EmptyClass
        end
      end
    end
  end
end

require 'legion/extensions/mesh/transport/queues/preference'
require 'legion/extensions/mesh/runners/preferences'
require 'legion/extensions/mesh/actors/preference_listener'

RSpec.describe Legion::Extensions::Mesh::Actor::PreferenceListener do
  subject(:actor) { described_class.new }

  describe '#runner_class' do
    it 'returns the Preferences runner module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Mesh::Runners::Preferences)
    end
  end

  describe '#runner_function' do
    it 'returns dispatch_preference_message' do
      expect(actor.runner_function).to eq('dispatch_preference_message')
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

  describe '#use_runner?' do
    it 'returns false' do
      expect(actor.use_runner?).to be false
    end
  end

  describe '#queue' do
    it 'returns the Preference queue class' do
      expect(actor.queue).to eq(Legion::Extensions::Mesh::Transport::Queues::Preference)
    end
  end

  describe '#enabled?' do
    context 'when transport is available' do
      it 'returns truthy' do
        stub_const('Legion::Transport', Module.new)
        expect(actor.enabled?).to be_truthy
      end
    end

    context 'when transport is not available' do
      it 'returns falsey' do
        hide_const('Legion::Transport')
        expect(actor.enabled?).to be_falsey
      end
    end
  end
end
