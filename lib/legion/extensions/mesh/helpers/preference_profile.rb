# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Helpers
        module PreferenceProfile
          DEFAULTS = {
            verbosity:       :normal,
            tone:            :professional,
            format:          :structured,
            technical_depth: :moderate
          }.freeze

          VALID_VALUES = {
            'verbosity'       => %i[terse concise normal detailed verbose],
            'tone'            => %i[casual conversational professional formal],
            'format'          => %i[plain structured markdown],
            'technical_depth' => %i[high_level moderate deep implementation]
          }.freeze

          SOURCE_CONFIDENCE = {
            'explicit'            => 1.0,
            'preference_learning' => 0.75,
            'personality'         => 0.4,
            'defaults'            => 0.0
          }.freeze

          INSTRUCTION_MAP = {
            verbosity:       {
              terse:    'Keep responses extremely short — one or two sentences max.',
              concise:  'Keep responses brief and to the point.',
              detailed: 'Provide thorough, detailed responses.',
              verbose:  'Be comprehensive and expansive in your responses.'
            },
            tone:            {
              casual:         'Use casual, friendly language.',
              conversational: 'Use a warm, conversational tone.',
              formal:         'Use formal, professional language.'
            },
            format:          {
              plain:    'Use plain text without formatting.',
              markdown: 'Use rich markdown formatting with headers and code blocks.'
            },
            technical_depth: {
              high_level:     'Keep explanations high-level, avoid implementation details.',
              deep:           'Include technical depth and implementation details.',
              implementation: 'Include implementation details, code examples, and edge cases.'
            }
          }.freeze

          module_function

          def resolve(owner_id:, overrides: nil, personality: nil)
            prefs = DEFAULTS.dup
            sources = Set.new([:defaults])
            custom = {}

            traces = fetch_preference_traces(owner_id: owner_id)
            all_prefs = traces + (overrides || [])

            all_prefs.sort_by { |p| p[:confidence] || SOURCE_CONFIDENCE.fetch(p[:source].to_s, 0.0) }.each do |pref|
              domain = pref[:domain].to_s
              value = pref[:value].to_s
              source = pref[:source].to_s

              if domain.start_with?('custom:')
                custom_key = domain.sub('custom:', '')
                custom[custom_key] = value
                sources << source.to_sym
              elsif VALID_VALUES.key?(domain) && VALID_VALUES[domain].include?(value.to_sym)
                prefs[domain.to_sym] = value.to_sym
                sources << source.to_sym
              end
            end

            prefs.merge(
              personality: personality,
              custom:      custom,
              sources:     sources.to_a,
              resolved_at: Time.now
            )
          end

          def store_preference(owner_id:, domain:, value:, source: 'explicit')
            return { stored: false, reason: :memory_not_available } unless memory_available?

            confidence = SOURCE_CONFIDENCE.fetch(source.to_s, 0.5)
            memory_runner.store_trace(
              type:            :semantic,
              content_payload: { domain: domain, value: value, source: source }.to_s,
              domain_tags:     ['preference', "preference:#{domain}", "owner:#{owner_id}"],
              origin:          :direct_experience,
              confidence:      confidence
            )
            { stored: true, domain: domain, value: value, source: source }
          rescue StandardError => e
            { stored: false, reason: :error, message: e.message }
          end

          def clear_preferences(owner_id:, source: nil)
            return { cleared: false, reason: :memory_not_available } unless memory_available?

            { cleared: true, owner_id: owner_id, source: source }
          end

          def preference_instructions(profile:)
            lines = []

            INSTRUCTION_MAP.each do |domain, value_map|
              current = profile[domain]
              default = DEFAULTS[domain]
              next if current == default

              instruction = value_map[current]
              lines << instruction if instruction
            end

            return nil if lines.empty?

            lines.join(' ')
          end

          MESH_CACHE_TTL = 3600 # 1 hour default

          def store_mesh_profile(agent_id:, profile:, source_agent_id:)
            @mesh_cache ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
            @mesh_cache[agent_id.to_s] = { # rubocop:disable ThreadSafety/ClassInstanceVariable
              profile:         profile,
              source_agent_id: source_agent_id,
              origin:          :mesh_transfer,
              cached_at:       Time.now
            }

            if memory_available?
              store_preference(
                owner_id: agent_id,
                domain:   'mesh_profile',
                value:    profile.to_s,
                source:   'mesh_transfer'
              )
            end

            { stored: true, agent_id: agent_id, origin: :mesh_transfer }
          rescue StandardError => e
            { stored: false, error: e.message }
          end

          def cached_mesh_profile(agent_id:, ttl: MESH_CACHE_TTL)
            @mesh_cache ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
            entry = @mesh_cache[agent_id.to_s] # rubocop:disable ThreadSafety/ClassInstanceVariable
            return nil unless entry

            if Time.now - entry[:cached_at] > ttl
              @mesh_cache.delete(agent_id.to_s) # rubocop:disable ThreadSafety/ClassInstanceVariable
              return nil
            end

            entry[:profile]
          rescue StandardError => _e
            nil
          end

          def clear_mesh_cache(agent_id: nil)
            @mesh_cache ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
            if agent_id
              @mesh_cache.delete(agent_id.to_s) # rubocop:disable ThreadSafety/ClassInstanceVariable
            else
              @mesh_cache.clear # rubocop:disable ThreadSafety/ClassInstanceVariable
            end
          end

          def for_agent(agent_id:, ttl: MESH_CACHE_TTL)
            cached = cached_mesh_profile(agent_id: agent_id, ttl: ttl)
            if cached
              return {
                source:        :mesh_cache,
                profile:       cached,
                agent_id:      agent_id,
                compatibility: compute_compatibility(cached)
              }
            end

            profile = resolve(owner_id: agent_id)

            {
              source:        :local,
              profile:       profile,
              agent_id:      agent_id,
              compatibility: compute_compatibility(profile)
            }
          rescue StandardError => e
            {
              source:        :local,
              profile:       DEFAULTS.dup,
              agent_id:      agent_id,
              compatibility: nil,
              error:         e.message
            }
          end

          def memory_available?
            defined?(Legion::Extensions::Agentic::Memory::Trace::Runners::Traces)
          end

          def memory_runner
            Object.new.extend(Legion::Extensions::Agentic::Memory::Trace::Runners::Traces)
          end

          def fetch_preference_traces(owner_id:)
            return [] unless memory_available?

            traces = memory_runner.retrieve_by_domain(domain_tag: "owner:#{owner_id}")
            traces.select { |t| t[:domain_tags]&.include?('preference') }.filter_map do |trace|
              parse_preference_trace(trace)
            end
          rescue StandardError => _e
            []
          end

          def parse_preference_trace(trace)
            payload = trace[:content_payload]
            return nil unless payload.is_a?(String)

            match = payload.match(/domain.*?(\w+).*?value.*?(\w+).*?source.*?(\w+)/)
            return nil unless match

            { domain: match[1], value: match[2], source: match[3], confidence: trace[:confidence] }
          rescue StandardError => _e
            nil
          end

          def compute_compatibility(profile)
            return nil unless profile.is_a?(Hash) && profile[:personality]
            return nil unless personality_available?

            personality_runner = Object.new.extend(
              Legion::Extensions::Agentic::Self::Personality::Runners::Personality
            )
            result = personality_runner.personality_compatibility(other_profile: profile[:personality])
            { score: result[:compatibility], interpretation: result[:interpretation] }
          rescue StandardError => _e
            nil
          end

          def personality_available?
            defined?(Legion::Extensions::Agentic::Self::Personality::Runners::Personality)
          end
        end
      end
    end
  end
end
