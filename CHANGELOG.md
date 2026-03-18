# Changelog

## [0.2.0] - 2026-03-17

### Added
- `Runners::Preferences` with async cross-agent preference query RPC
  - `query_preferences(target_agent_id:)` — publish query to agent exchange, return defaults immediately, callback when response arrives
  - `handle_preference_query` — respond to incoming preference queries with local profile
  - `handle_preference_response` — resolve pending request callback on response
  - `expire_pending_requests` — cleanup TTL-expired pending requests
- `Helpers::PendingRequests` thread-safe tracker with correlation_id callbacks and TTL expiration
- Transport layer: `PreferenceQuery` and `PreferenceResponse` messages via agent exchange
- Standalone `Client` class includes both `Mesh` and `Preferences` runners

## [0.1.1] - 2026-03-15

### Added
- PreferenceProfile helper: domain-agnostic preference resolution from multiple sources
- `preference_instructions`: translates profile to natural language system prompt text
- `store_preference` / `clear_preferences`: lex-memory backed preference persistence
- `spec/legion/extensions/mesh/actors/heartbeat_spec.rb` (8 examples) — tests for the Heartbeat actor (Every 10s)

## [0.1.0] - 2026-03-13

### Added
- Initial release
