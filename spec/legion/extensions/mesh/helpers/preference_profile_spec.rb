# frozen_string_literal: true

require 'spec_helper'

# Stub lex-agentic-memory if not loaded
unless defined?(Legion::Extensions::Agentic::Memory::Trace::Runners::Traces)
  module Legion
    module Extensions
      module Agentic
        module Memory
          module Trace
            module Runners
              module Traces
                def retrieve_by_domain(**)
                  { count: 0, traces: [] }
                end

                def store_trace(**)
                  { stored: true }
                end

                def delete_trace(trace_id:, **)
                  { deleted: true, trace_id: trace_id }
                end
              end
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

    it 'serializes payload as JSON string' do
      captured_payload = nil
      runner_double = double('memory_runner')
      allow(profile_mod).to receive(:memory_available?).and_return(true)
      allow(profile_mod).to receive(:memory_runner).and_return(runner_double)
      allow(runner_double).to receive(:store_trace) do |**args|
        captured_payload = args[:content_payload]
        { stored: true }
      end

      profile_mod.store_preference(owner_id: 'u1', domain: 'verbosity', value: 'concise', source: 'explicit')

      parsed = Legion::JSON.load(captured_payload)
      expect(parsed[:domain]).to eq('verbosity')
      expect(parsed[:value]).to eq('concise')
      expect(parsed[:source]).to eq('explicit')
    end
  end

  describe '.clear_preferences' do
    it 'returns cleared result' do
      result = profile_mod.clear_preferences(owner_id: 'user1', source: 'explicit')
      expect(result[:cleared]).to be true
    end

    it 'actually deletes traces via memory runner when memory is available' do
      trace = { trace_id: 'abc-123', domain_tags: ['preference', 'owner:user1'], confidence: 0.9 }
      runner_double = double('memory_runner')
      allow(profile_mod).to receive(:memory_available?).and_return(true)
      allow(profile_mod).to receive(:memory_runner).and_return(runner_double)
      allow(runner_double).to receive(:retrieve_by_domain).and_return({ traces: [trace] })
      allow(runner_double).to receive(:delete_trace).and_return({ deleted: true })

      result = profile_mod.clear_preferences(owner_id: 'user1')

      expect(runner_double).to have_received(:retrieve_by_domain).with(hash_including(domain_tag: 'owner:user1'))
      expect(runner_double).to have_received(:delete_trace).with(hash_including(trace_id: 'abc-123'))
      expect(result[:cleared]).to be true
      expect(result[:count]).to eq(1)
    end

    it 'returns not_available when memory is unavailable' do
      allow(profile_mod).to receive(:memory_available?).and_return(false)
      result = profile_mod.clear_preferences(owner_id: 'user1')
      expect(result[:cleared]).to be false
      expect(result[:reason]).to eq(:memory_not_available)
    end
  end

  describe '.parse_preference_trace' do
    it 'parses JSON-encoded payload and returns symbol-keyed hash' do
      payload = Legion::JSON.dump({ domain: 'verbosity', value: 'concise', source: 'explicit' })
      trace = { content_payload: payload, confidence: 0.9 }
      result = profile_mod.parse_preference_trace(trace)
      expect(result[:domain]).to eq('verbosity')
      expect(result[:value]).to eq('concise')
      expect(result[:source]).to eq('explicit')
      expect(result[:confidence]).to eq(0.9)
    end

    it 'falls back to legacy regex for old .to_s hash format' do
      legacy_payload = '{:domain=>"verbosity", :value=>"concise", :source=>"explicit"}'
      trace = { content_payload: legacy_payload, confidence: 0.7 }
      result = profile_mod.parse_preference_trace(trace)
      expect(result[:domain]).to eq('verbosity')
      expect(result[:value]).to eq('concise')
      expect(result[:source]).to eq('explicit')
      expect(result[:confidence]).to eq(0.7)
    end

    it 'returns nil for a non-string payload' do
      trace = { content_payload: nil, confidence: 0.5 }
      expect(profile_mod.parse_preference_trace(trace)).to be_nil
    end

    it 'returns nil for a payload that cannot be parsed by either method' do
      trace = { content_payload: 'garbage data without structure', confidence: 0.5 }
      expect(profile_mod.parse_preference_trace(trace)).to be_nil
    end
  end

  describe '.erase_partner!' do
    before do
      described_class.clear_observations
      described_class.clear_mesh_cache
    end

    it 'removes observation counts for the identity' do
      5.times { described_class.update_from_observation(owner_id: 'partner-x', signals: { channel: :cli, direct_address: false }) }
      described_class.erase_partner!(identity: 'partner-x')
      expect(described_class.observation_counts['partner-x']).to be_nil
    end

    it 'removes inferred preferences for the identity' do
      20.times { described_class.update_from_observation(owner_id: 'partner-x', signals: { channel: :cli, direct_address: false }) }
      described_class.erase_partner!(identity: 'partner-x')
      expect(described_class.inferred_preferences('partner-x')).to be_empty
    end

    it 'removes mesh cache entries for the identity' do
      described_class.store_mesh_profile(
        agent_id:        'partner-x',
        profile:         { verbosity: :concise },
        source_agent_id: 'partner-x'
      )
      described_class.erase_partner!(identity: 'partner-x')
      expect(described_class.cached_mesh_profile(agent_id: 'partner-x')).to be_nil
    end

    it 'deletes memory traces tagged with the identity' do
      trace = { trace_id: 'xyz-789', domain_tags: ['preference', 'owner:partner-x'], confidence: 0.8 }
      runner_double = double('memory_runner')
      allow(described_class).to receive(:memory_available?).and_return(true)
      allow(described_class).to receive(:memory_runner).and_return(runner_double)
      allow(runner_double).to receive(:retrieve_by_domain).and_return({ traces: [trace] })
      allow(runner_double).to receive(:delete_trace).and_return({ deleted: true })

      described_class.erase_partner!(identity: 'partner-x')

      expect(runner_double).to have_received(:delete_trace).with(hash_including(trace_id: 'xyz-789'))
    end

    it 'leaves data for other identities untouched' do
      3.times { described_class.update_from_observation(owner_id: 'partner-y', signals: { channel: :cli, direct_address: false }) }
      described_class.store_mesh_profile(
        agent_id:        'partner-y',
        profile:         { verbosity: :detailed },
        source_agent_id: 'partner-y'
      )
      described_class.erase_partner!(identity: 'partner-x')
      expect(described_class.observation_counts['partner-y']).to eq(3)
      expect(described_class.cached_mesh_profile(agent_id: 'partner-y')).not_to be_nil
    end

    it 'returns a result hash with erased identity and counts' do
      result = described_class.erase_partner!(identity: 'partner-x')
      expect(result).to be_a(Hash)
      expect(result[:erased]).to be true
      expect(result[:identity]).to eq('partner-x')
    end
  end

  describe '.store_mesh_profile' do
    it 'stores a profile with mesh_transfer origin' do
      result = described_class.store_mesh_profile(
        agent_id:        'agent-42',
        profile:         { verbosity: :concise, tone: :casual },
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
        agent_id:        'agent-42',
        profile:         { verbosity: :concise, tone: :casual },
        source_agent_id: 'agent-42'
      )
      result = described_class.cached_mesh_profile(agent_id: 'agent-42')
      expect(result).to be_a(Hash)
      expect(result[:verbosity]).to eq(:concise)
    end

    it 'returns nil for expired cache entries' do
      described_class.store_mesh_profile(
        agent_id:        'agent-42',
        profile:         { verbosity: :concise },
        source_agent_id: 'agent-42'
      )
      # Expire the entry by manipulating the cache timestamp
      cache = described_class.instance_variable_get(:@mesh_cache)
      cache['agent-42'][:cached_at] = Time.now - 7200 if cache&.dig('agent-42')
      result = described_class.cached_mesh_profile(agent_id: 'agent-42', ttl: 3600)
      expect(result).to be_nil
    end
  end

  describe '.for_agent' do
    before { described_class.clear_mesh_cache }

    it 'returns local profile when no mesh cache exists' do
      result = described_class.for_agent(agent_id: 'agent-99')
      expect(result[:source]).to eq(:local)
      expect(result[:profile]).to be_a(Hash)
      expect(result[:profile][:verbosity]).to eq(:normal)
    end

    it 'returns cached mesh profile when available' do
      described_class.store_mesh_profile(
        agent_id:        'agent-42',
        profile:         { verbosity: :concise, tone: :formal },
        source_agent_id: 'agent-42'
      )
      result = described_class.for_agent(agent_id: 'agent-42')
      expect(result[:source]).to eq(:mesh_cache)
      expect(result[:profile][:verbosity]).to eq(:concise)
    end

    it 'falls back to local when mesh cache is expired' do
      described_class.store_mesh_profile(
        agent_id:        'agent-42',
        profile:         { verbosity: :concise },
        source_agent_id: 'agent-42'
      )
      cache = described_class.instance_variable_get(:@mesh_cache)
      cache['agent-42'][:cached_at] = Time.now - 7200
      result = described_class.for_agent(agent_id: 'agent-42')
      expect(result[:source]).to eq(:local)
    end

    it 'includes compatibility when available' do
      result = described_class.for_agent(agent_id: 'agent-99')
      expect(result).to have_key(:compatibility)
    end
  end

  describe '.update_from_observation' do
    before { described_class.clear_observations }

    let(:cli_signal)   { { content_type: :text, channel: :cli, direct_address: false } }
    let(:chat_signal)  { { content_type: :text, channel: :chat, direct_address: true } }
    let(:mixed_signal) { { content_type: :text, channel: :api, direct_address: false } }

    it 'returns { updated: true } on each call' do
      result = described_class.update_from_observation(owner_id: 'user-obs', signals: cli_signal)
      expect(result).to eq({ updated: true })
    end

    it 'accumulates signals per owner_id' do
      5.times { described_class.update_from_observation(owner_id: 'user-obs', signals: cli_signal) }
      counts = described_class.observation_counts
      expect(counts['user-obs']).to eq(5)
    end

    it 'does not infer preferences before threshold (20)' do
      19.times { described_class.update_from_observation(owner_id: 'user-obs', signals: cli_signal) }
      inferred = described_class.inferred_preferences('user-obs')
      expect(inferred).to be_empty
    end

    it 'derives :concise verbosity for CLI-heavy usage after threshold' do
      20.times { described_class.update_from_observation(owner_id: 'user-cli', signals: cli_signal) }
      inferred = described_class.inferred_preferences('user-cli')
      verbosity = inferred.find { |p| p[:domain] == 'verbosity' }
      expect(verbosity).not_to be_nil
      expect(verbosity[:value]).to eq('concise')
      expect(verbosity[:source]).to eq('observation')
    end

    it 'derives :conversational tone for high direct_address ratio after threshold' do
      20.times { described_class.update_from_observation(owner_id: 'user-da', signals: chat_signal) }
      inferred = described_class.inferred_preferences('user-da')
      tone = inferred.find { |p| p[:domain] == 'tone' }
      expect(tone).not_to be_nil
      expect(tone[:value]).to eq('conversational')
      expect(tone[:source]).to eq('observation')
    end

    it 'derives :structured format for mixed channel usage after threshold' do
      channels = %i[cli api chat rest]
      20.times.with_index do |i, _|
        ch = channels[i % channels.length]
        described_class.update_from_observation(
          owner_id: 'user-mix',
          signals:  { content_type: :text, channel: ch, direct_address: false }
        )
      end
      inferred = described_class.inferred_preferences('user-mix')
      format = inferred.find { |p| p[:domain] == 'format' }
      expect(format).not_to be_nil
      expect(format[:value]).to eq('structured')
      expect(format[:source]).to eq('observation')
    end

    it 'derive_format never returns a value outside VALID_VALUES[:format]' do
      channels = %i[cli api chat rest grpc websocket]
      20.times.with_index do |i, _|
        ch = channels[i % channels.length]
        described_class.update_from_observation(
          owner_id: 'user-valid',
          signals:  { content_type: :text, channel: ch, direct_address: false }
        )
      end
      inferred = described_class.inferred_preferences('user-valid')
      format_pref = inferred.find { |p| p[:domain] == 'format' }
      if format_pref
        valid_format_values = described_class::VALID_VALUES['format'].map(&:to_s)
        expect(valid_format_values).to include(format_pref[:value])
      end
    end

    it 'keeps separate observation counts per owner_id' do
      3.times { described_class.update_from_observation(owner_id: 'user-a', signals: cli_signal) }
      7.times { described_class.update_from_observation(owner_id: 'user-b', signals: cli_signal) }
      counts = described_class.observation_counts
      expect(counts['user-a']).to eq(3)
      expect(counts['user-b']).to eq(7)
    end

    it 'calls store_preference for each inferred preference after threshold' do
      allow(described_class).to receive(:store_preference).and_call_original
      20.times { described_class.update_from_observation(owner_id: 'user-store', signals: cli_signal) }
      expect(described_class).to have_received(:store_preference).with(
        hash_including(owner_id: 'user-store', source: 'observation')
      ).at_least(:once)
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

  describe 'SOURCE_CONFIDENCE' do
    it 'includes observation source' do
      expect(described_class::SOURCE_CONFIDENCE).to have_key('observation')
      expect(described_class::SOURCE_CONFIDENCE['observation']).to eq(0.55)
    end

    it 'includes llm_inference source' do
      expect(described_class::SOURCE_CONFIDENCE).to have_key('llm_inference')
      expect(described_class::SOURCE_CONFIDENCE['llm_inference']).to eq(0.65)
    end

    it 'maintains descending confidence order for all sources' do
      conf = described_class::SOURCE_CONFIDENCE
      expect(conf['explicit']).to be > conf['preference_learning']
      expect(conf['preference_learning']).to be > conf['llm_inference']
      expect(conf['llm_inference']).to be > conf['observation']
      expect(conf['observation']).to be > conf['personality']
      expect(conf['personality']).to be > conf['defaults']
    end
  end
end
