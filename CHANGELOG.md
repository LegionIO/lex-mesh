# Changelog

## [0.4.2] - 2026-03-30

### Changed
- update to rubocop-legion 0.1.7, resolve all offenses

## [0.4.1] - 2026-03-26

### Changed
- Migrate PreferenceProfile from `Legion::Extensions::Memory::Runners::Traces` to `Legion::Extensions::Agentic::Memory::Trace::Runners::Traces`

## [0.4.0] - 2026-03-24

### Added
- Trust gating on preference query responder: refuses preferences to agents below TRUST_CONSIDER_THRESHOLD (0.3)
- `PreferenceProfile.for_agent(agent_id:)`: universal entry point, checks mesh cache then falls back to local resolve
- Mesh-received preference caching: `store_mesh_profile`, `cached_mesh_profile`, `clear_mesh_cache` with configurable TTL (default 1 hour)
- Personality compatibility scoring via lex-agentic-self when available (graceful degradation when not loaded)
- `handle_preference_response` now caches received profiles for future `for_agent` lookups
- `dispatch_preference_message` forwards `responding_agent_id` for correct cache keying

## [0.3.4] - 2026-03-24

### Fixed
- `Preference#queue_name` and `#bind_routing_key` now use symbol keys (`Legion::Settings[:client][:name]`) instead of string keys, fixing a `NoMethodError: undefined method '[]' for nil` crash that prevented `PreferenceListener` from starting on every boot (fixes #2)
- Fixed `preference_spec.rb` stub to use symbol keys matching production `Legion::Settings` behavior

## [0.3.3] - 2026-03-24

### Fixed
- `Runners::Preferences` now includes `Helpers::Lex` so instance methods are available as module methods (fixes `undefined method 'expire_pending_requests'` from PendingExpiry actor)
- `log_debug` in Preferences uses tagged `log` helper instead of bare `Legion::Logging`

## [0.3.2] - 2026-03-24

### Added
- `Registry#route_message` now accepts `hops: 0` keyword parameter
- Enforce `MAX_HOPS` (3) in `route_message`: messages with `hops >= MAX_HOPS` are rejected immediately with `delivered_to: []` and `rejected: :max_hops_exceeded`
- `hops` field stored on forwarded messages for downstream hop tracking
- 5 new specs for hop-count enforcement in `registry_spec.rb`
- `spec/legion/extensions/mesh/transport/queues/gossip_spec.rb` with 3 examples covering queue name, exchange, and routing key
- `.rubocop.yml`: `Metrics/ParameterLists` now sets `CountKeywordArgs: false`; removed 3 now-redundant inline disable comments from delegation, mesh, and task_request runners

## [0.3.1] - 2026-03-22

### Changed
- Add legion-cache, legion-crypt, legion-data, legion-json, legion-logging, legion-settings, legion-transport as runtime dependencies
- Replace direct Legion::Logging calls with injected log helper in runners/mesh.rb, runners/task_request.rb, runners/delegation.rb
- Update spec_helper with real sub-gem helper stubs

## [0.3.0] - 2026-03-22

### Added
- `Runners::TaskRequest`: RPC-style task delegation combining capability discovery, delegation tracking, and PendingRequests async callback
- `request_task`: send task to agent by ID or capability with timeout
- `handle_task_reply`: resolve pending task request when reply arrives
- `pending_task_stats` and `expire_pending_tasks`: monitoring and cleanup
- Client now includes Delegation and TaskRequest runners

## [0.2.5] - 2026-03-20

### Added
- `Registry#all_agents` returns all agent records as an array
- `source`, `node`, `generation` fields on registered agents
- `heartbeat` now increments `generation` counter
- `Runners::Mesh#publish_gossip` — broadcasts peer table to node exchange every 15 seconds
- `Runners::Mesh#merge_gossip` — integrates incoming gossip with generation-based conflict resolution
- `Transport::Messages::Gossip` — AMQP message for peer table broadcast (routing key: `mesh.gossip`)
- `Transport::Queues::Gossip` — queue binding for gossip messages
- `Actor::Gossip` — periodic actor (15s) that calls `publish_gossip`

## [0.2.4] - 2026-03-20

### Added
- `Helpers::Delegation` class for in-memory delegation chain tracking with consent non-escalation, max depth (3), and cascade revocation
- `Runners::Delegation` with delegate, complete_delegation, revoke_delegation, delegation_chain, agent_delegations, and delegation_stats methods
- `Helpers::PeerVerify` module with Ed25519 sign_message, verify_message, and per-peer rate limiting for cross-org diplomacy
- `ed25519` (~> 1.3) and `base64` gem dependencies

## [0.2.3] - 2026-03-18

### Added
- `Registry#expire_silent_agents(timeout:)` marks agents as `:offline` when `last_seen` exceeds `MESH_SILENCE_TIMEOUT` (30s default)
- `Runners::Mesh#expire_silent_agents` runner method wrapping registry expiry
- `Actor::SilenceWatchdog` periodic actor (15s) enforces `MESH_SILENCE_TIMEOUT` — agents that miss heartbeats are marked offline
- 12 new specs: 5 for registry expiry, 6 for actor, 1 for runner

## [0.2.2] - 2026-03-18

### Added
- `Transport::Messages::MeshDeparture` publishes departure signal to `node` exchange on `mesh.departure` routing key
- `Runners::Mesh#unregister` now emits mesh departure signal with agent_id and capabilities when agent leaves
- Departure spec with 7 examples for message class

### Fixed
- Transport message spec guards now use per-constant `unless defined?` to prevent load-order pollution between Agent/Node exchange stubs

## [0.2.1] - 2026-03-18

### Added
- `Actor::PreferenceListener` subscription actor wires AMQP messages to preference runner dispatch
- `Actor::PendingExpiry` periodic actor (30s) cleans up TTL-expired pending requests
- `Transport::Queues::Preference` per-agent preference queue (`agent.<id>.preferences`)
- `Runners::Preferences#dispatch_preference_message` routes by message type to query/response handlers
- Auto-reply: `dispatch_preference_message` publishes `PreferenceResponse` back to requester on query

### Changed
- Preference routing keys now use `agent.<id>.preferences` suffix to avoid collision with GAIA inbound queue
- `reply_to` field uses `.preferences` suffix for correct response routing

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
