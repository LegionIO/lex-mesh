# frozen_string_literal: true

# Stub the framework actor base class
unless defined?(Legion::Extensions::Actors::Every)
  module Legion
    module Extensions
      module Actors
        class Every # rubocop:disable Lint/EmptyClass
        end
      end
    end
  end

  $LOADED_FEATURES << 'legion/extensions/actors/every' unless $LOADED_FEATURES.include?('legion/extensions/actors/every')
end

require 'legion/extensions/mesh/actors/pending_expiry'

RSpec.describe Legion::Extensions::Mesh::Actor::PendingExpiry do
  subject(:actor) { described_class.new }

  describe '#runner_class' do
    it 'returns the Preferences runner module' do
      expect(actor.runner_class).to eq(Legion::Extensions::Mesh::Runners::Preferences)
    end
  end

  describe '#runner_function' do
    it 'returns expire_pending_requests' do
      expect(actor.runner_function).to eq('expire_pending_requests')
    end
  end

  describe '#time' do
    it 'returns 30' do
      expect(actor.time).to eq(30)
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
