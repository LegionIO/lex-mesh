# frozen_string_literal: true

# Stub the framework actor base class since legionio gem is not available in test
module Legion
  module Extensions
    module Actors
      class Every # rubocop:disable Lint/EmptyClass
      end
    end
  end
end

# Intercept the require in the actor file so it doesn't fail
$LOADED_FEATURES << 'legion/extensions/actors/every'

require 'legion/extensions/mesh/actors/heartbeat'

RSpec.describe Legion::Extensions::Mesh::Actor::Heartbeat do
  subject(:actor) { described_class.new }

  describe '#runner_class' do
    it 'returns the Mesh runner module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Mesh::Runners::Mesh)
    end
  end

  describe '#runner_function' do
    it 'returns heartbeat' do
      expect(actor.runner_function).to eq('heartbeat')
    end
  end

  describe '#time' do
    it 'returns 10' do
      expect(actor.time).to eq(10)
    end
  end

  describe '#run_now?' do
    it 'returns true' do
      expect(actor.run_now?).to be true
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

  describe '#args' do
    it 'returns a hash with agent_id from Legion::Settings' do
      settings = { client: { name: 'test-agent' } }
      stub_const('Legion::Settings', settings)
      expect(actor.args).to eq({ agent_id: 'test-agent' })
    end
  end
end
