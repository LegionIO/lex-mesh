# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Extensions::Actors::Every)
  module Legion
    module Extensions
      module Actors
        class Every; end # rubocop:disable Lint/EmptyClass
      end
    end
  end
end

require 'legion/extensions/mesh/actors/silence_watchdog'

RSpec.describe Legion::Extensions::Mesh::Actor::SilenceWatchdog do
  subject(:actor) { described_class.allocate }

  describe '#runner_class' do
    it 'returns the Mesh runner module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Mesh::Runners::Mesh)
    end
  end

  describe '#runner_function' do
    it 'returns expire_silent_agents' do
      expect(actor.runner_function).to eq('expire_silent_agents')
    end
  end

  describe '#time' do
    it 'returns 15' do
      expect(actor.time).to eq(15)
    end
  end

  describe '#use_runner?' do
    it 'returns false' do
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
end
