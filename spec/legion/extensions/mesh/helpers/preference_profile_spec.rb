# frozen_string_literal: true

require 'spec_helper'

# Stub lex-memory if not loaded
unless defined?(Legion::Extensions::Memory::Runners::Traces)
  module Legion
    module Extensions
      module Memory
        module Runners
          module Traces
            def retrieve_by_domain(**)
              []
            end

            def store_trace(**)
              { stored: true }
            end
          end
        end
      end
    end
  end
end

RSpec.describe Legion::Extensions::Mesh::Helpers::PreferenceProfile do
  let(:profile_mod) { described_class }

  describe '.resolve' do
    context 'with no preferences stored' do
      it 'returns default profile' do
        result = profile_mod.resolve(owner_id: 'user1')
        expect(result[:verbosity]).to eq(:normal)
        expect(result[:tone]).to eq(:professional)
        expect(result[:format]).to eq(:structured)
        expect(result[:technical_depth]).to eq(:moderate)
        expect(result[:sources]).to eq([:defaults])
        expect(result[:resolved_at]).to be_a(Time)
      end
    end

    context 'with explicit preference stored' do
      it 'overrides default for that domain' do
        result = profile_mod.resolve(owner_id: 'user1', overrides: [
                                       { domain: 'verbosity', value: 'concise', source: 'explicit', confidence: 1.0 }
                                     ])
        expect(result[:verbosity]).to eq(:concise)
        expect(result[:sources]).to include(:explicit)
      end
    end

    context 'with multiple sources for same domain' do
      it 'higher confidence wins' do
        result = profile_mod.resolve(owner_id: 'user1', overrides: [
                                       { domain: 'tone', value: 'casual', source: 'personality', confidence: 0.4 },
                                       { domain: 'tone', value: 'formal', source: 'explicit', confidence: 1.0 }
                                     ])
        expect(result[:tone]).to eq(:formal)
      end
    end

    context 'with personality traits' do
      it 'maps OCEAN traits to preference defaults' do
        result = profile_mod.resolve(
          owner_id:    'user1',
          personality: { openness: 0.9, conscientiousness: 0.3 }
        )
        expect(result[:personality]).to eq({ openness: 0.9, conscientiousness: 0.3 })
      end
    end

    context 'with custom preferences' do
      it 'includes custom key-value pairs' do
        result = profile_mod.resolve(owner_id: 'user1', overrides: [
                                       { domain: 'custom:response_language', value: 'es', source: 'explicit', confidence: 1.0 }
                                     ])
        expect(result[:custom]).to include('response_language' => 'es')
      end
    end
  end

  describe '.store_preference' do
    it 'returns stored result with trace data' do
      result = profile_mod.store_preference(
        owner_id: 'user1', domain: 'verbosity', value: 'concise', source: 'explicit'
      )
      expect(result[:stored]).to be true
      expect(result[:domain]).to eq('verbosity')
    end

    it 'returns not_available when lex-memory is not loaded' do
      allow(profile_mod).to receive(:memory_available?).and_return(false)
      result = profile_mod.store_preference(
        owner_id: 'user1', domain: 'verbosity', value: 'concise', source: 'explicit'
      )
      expect(result[:stored]).to be false
      expect(result[:reason]).to eq(:memory_not_available)
    end
  end

  describe '.clear_preferences' do
    it 'returns cleared result' do
      result = profile_mod.clear_preferences(owner_id: 'user1', source: 'explicit')
      expect(result[:cleared]).to be true
    end
  end

  describe '.store_mesh_profile' do
    it 'stores a profile with mesh_transfer origin' do
      result = described_class.store_mesh_profile(
        agent_id: 'agent-42',
        profile:  { verbosity: :concise, tone: :casual },
        source_agent_id: 'agent-42'
      )
      expect(result[:stored]).to be true
      expect(result[:origin]).to eq(:mesh_transfer)
    end
  end

  describe '.cached_mesh_profile' do
    it 'returns nil when no cached profile exists' do
      result = described_class.cached_mesh_profile(agent_id: 'agent-unknown')
      expect(result).to be_nil
    end

    it 'returns cached profile after store' do
      described_class.store_mesh_profile(
        agent_id: 'agent-42',
        profile:  { verbosity: :concise, tone: :casual },
        source_agent_id: 'agent-42'
      )
      result = described_class.cached_mesh_profile(agent_id: 'agent-42')
      expect(result).to be_a(Hash)
      expect(result[:verbosity]).to eq(:concise)
    end

    it 'returns nil for expired cache entries' do
      described_class.store_mesh_profile(
        agent_id: 'agent-42',
        profile:  { verbosity: :concise },
        source_agent_id: 'agent-42'
      )
      # Expire the entry by manipulating the cache timestamp
      cache = described_class.instance_variable_get(:@mesh_cache)
      cache['agent-42'][:cached_at] = Time.now - 7200 if cache&.dig('agent-42')
      result = described_class.cached_mesh_profile(agent_id: 'agent-42', ttl: 3600)
      expect(result).to be_nil
    end
  end

  describe '.preference_instructions' do
    it 'generates natural language prompt instructions from profile' do
      profile = {
        verbosity:       :concise,
        tone:            :formal,
        format:          :structured,
        technical_depth: :deep
      }
      instructions = profile_mod.preference_instructions(profile: profile)
      expect(instructions).to include('brief')
      expect(instructions).to include('formal')
      expect(instructions).to include('implementation')
    end

    it 'returns nil for all-default profile' do
      profile = { verbosity: :normal, tone: :professional, format: :structured, technical_depth: :moderate }
      instructions = profile_mod.preference_instructions(profile: profile)
      expect(instructions).to be_nil
    end
  end
end
