# lex-mesh

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Agent-to-agent mesh communication layer for the LegionIO cognitive architecture. Manages agent registration, capability-based discovery, heartbeat status tracking, and message routing with unicast/multicast/broadcast patterns.

## Gem Info

- **Gem name**: `lex-mesh`
- **Version**: `0.4.5`
- **Module**: `Legion::Extensions::Mesh`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/mesh/
  version.rb
  helpers/
    topology.rb            # PROTOCOLS, PATTERNS, constants, valid_protocol?, valid_pattern?
    registry.rb            # Registry class - agents hash, capabilities index, messages buffer
    preference_profile.rb  # PreferenceProfile - resolve, store, clear, preference_instructions
    pending_requests.rb    # Thread-safe (Mutex) tracker for async RPC by correlation_id with TTL
    delegation.rb          # Delegation class - create, complete, revoke, depth enforcement, consent validation
    peer_table.rb          # PeerTable class - TTL-aware peer tracking with Mutex
    peer_verify.rb         # PeerVerify module - Ed25519 message signing and verification
  runners/
    mesh.rb                # register, unregister (+ departure signal), heartbeat, send_message, find_agents, mesh_status, expire_silent_agents
    preferences.rb         # query_preferences, handle_preference_query, handle_preference_response, dispatch_preference_message, expire_pending_requests
    delegation.rb          # delegate, complete_delegation, revoke_delegation, delegation_chain, agent_delegations, delegation_stats
    task_request.rb        # request_task, handle_task_reply, pending_task_stats, expire_pending_tasks
  transport/               # AMQP transport classes (loaded conditionally when Legion::Transport available)
    messages/
      preference_query.rb    # Publishes to agent exchange with agent.<target>.preferences routing key
      preference_response.rb # Response routed back via agent.<requester>.preferences
      mesh_departure.rb      # Publishes to node exchange with mesh.departure routing key on agent leave
      gossip.rb              # Publishes mesh gossip snapshot to the mesh exchange
      mesh_conflict.rb       # Publishes conflict resolution events to the mesh exchange
    queues/
      preference.rb          # Per-agent preference queue (agent.<id>.preferences, auto-delete)
      gossip.rb              # Per-node gossip queue bound to mesh.gossip routing key
  actors/
    heartbeat.rb             # Every 10s: broadcast_heartbeat
    silence_watchdog.rb      # Every 15s: expire_silent_agents (marks offline when last_seen > MESH_SILENCE_TIMEOUT)
    preference_listener.rb   # Subscription: dispatches preference_query/response from agent queue
    pending_expiry.rb        # Every 30s: expire TTL-expired pending requests
    gossip.rb                # Every 15s: publish_gossip — fan out mesh state to peers
    gossip_listener.rb       # Subscription: receives gossip from peer nodes, merges into registry
spec/
  legion/extensions/mesh/
    runners/
      mesh_spec.rb
      preferences_spec.rb
      delegation_spec.rb
      task_request_spec.rb
    helpers/
      pending_requests_spec.rb
    actors/
      heartbeat_spec.rb
      silence_watchdog_spec.rb
      preference_listener_spec.rb
      pending_expiry_spec.rb
    transport/
      messages/
        mesh_departure_spec.rb
        preference_query_spec.rb
        preference_response_spec.rb
      queues/
        preference_spec.rb
    client_spec.rb
```

## Key Constants (Helpers::Topology)

```ruby
PROTOCOLS             = %i[grpc websocket rest]
PATTERNS              = %i[unicast multicast broadcast]
MESH_SILENCE_TIMEOUT  = 30   # seconds (not enforced in current implementation)
TRUST_CONSIDER_THRESHOLD = 0.3  # mirrors lex-trust threshold
MAX_HOPS              = 3
```

## Registry Class

`Helpers::Registry` holds:
- `@agents` - Hash of agent_id => agent record
- `@capabilities` - Hash of capability => [agent_ids] (default-populating)
- `@messages` - Array buffer, capped at 1000 entries

Agent record structure:
```ruby
{
  agent_id:      "agent-42",
  capabilities:  [:code_review],
  endpoint:      "http://...",
  registered_at: Time,
  last_seen:     Time,
  status:        :online
}
```

`unregister_agent` removes the agent from the capabilities index as well as `@agents`.

`heartbeat` updates `last_seen` and sets `status: :online`. Agents are never automatically marked offline — heartbeat timeout enforcement is left to the caller.

## Message Routing

`route_message` builds a targets list based on pattern:
- `:unicast` - `[@agents[to]].compact` (nil-safe, not found = empty)
- `:multicast` - `find_by_capability(capability)`
- `:broadcast` - `@agents.values`

The message (including `delivered_to` list) is appended to `@messages` buffer (shift when > 1000).

## Async Preference Exchange (v0.2.0)

Agent-to-agent preference query via AMQP RPC over the `agent` exchange (from `legion-transport`).

**Pattern**: Non-blocking async with timeout fallback.
1. `query_preferences(target_agent_id:)` publishes a `PreferenceQuery` message to `agent.<target>` with `reply_to` + `correlation_id`
2. Returns defaults immediately; registers a callback in `PendingRequests`
3. Target agent's `handle_preference_query` resolves local preferences via `PreferenceProfile`
4. Target publishes `PreferenceResponse` back to the requesting agent's `reply_to` queue
5. Requester's `handle_preference_response` resolves the pending callback with the profile

**PendingRequests**: Thread-safe tracker (Mutex-based, no `concurrent-ruby` dependency). Keyed by `correlation_id`, each entry has a TTL (default 30s). `expire_pending_requests` cleans up stale entries.

**Transport**: Message classes are loaded conditionally (`if defined?(Legion::Transport)`) to allow standalone use without RabbitMQ.

**Routing key separation**: Preference messages use `agent.<id>.preferences` routing key suffix, avoiding collision with GAIA's `agent.<id>` inbound queue on the same topic exchange.

## Mesh Departure Signal (v0.2.2)

When an agent successfully unregisters, a `MeshDeparture` message is published to the `node` exchange with routing key `mesh.departure`. The message includes:
- `agent_id` — the departing agent
- `capabilities` — what the agent was providing
- `departed_at` — timestamp

This enables downstream consumers (e.g., Apollo's `GaiaIntegration.handle_mesh_departure`) to detect knowledge vulnerability when sole experts leave. The publish is fire-and-forget with rescue — unregister succeeds even if transport fails.

## Task Request RPC (v0.3.0)

RPC-style task delegation over the mesh, combining capability discovery, delegation tracking, and async callback via `PendingRequests`.

**Module**: `Runners::TaskRequest`

**Key methods:**
- `request_task(to: nil, capability: nil, task:, timeout: 30, **opts)` — send a task request to a specific agent by ID or route to the best available agent by capability. Registers a `PendingRequests` callback keyed by `correlation_id`. Returns `{ success: true, status: :pending, correlation_id: }` or `{ success: false, reason: }`.
- `handle_task_reply(correlation_id:, result:, **opts)` — resolve the pending callback when the reply arrives. Returns `{ success: true, resolved: true }` or `{ success: false, reason: :not_found }`.
- `pending_task_stats` — returns `{ pending_count: N }` for monitoring.
- `expire_pending_tasks` — cleans up TTL-expired pending task requests, returns `{ expired: N }`.

**Routing**: When `to:` is provided and matches a registered agent, the task is sent directly. When `to:` is not a known agent ID (or omitted), `find_by_capability` is used to locate an agent that can handle the task.

**Delegation tracking**: Each `request_task` call creates a delegation record via `Helpers::Delegation`, enforcing max depth (3) and consent non-escalation constraints.

**Standalone Client**: `Client` includes `Runners::TaskRequest` (and `Runners::Delegation`) — callable without the full framework.

## Integration Points

- **legion-transport**: `agent` exchange for preference RPC; `node` exchange for mesh departure signals
- **lex-apollo**: `GaiaIntegration.handle_mesh_departure` consumes `mesh.departure` events for knowledge vulnerability detection
- **lex-trust**: `TRUST_CONSIDER_THRESHOLD` referenced in topology; callers should filter by trust before routing sensitive messages
- **lex-swarm**: swarm agents register with mesh on formation; use multicast for swarm-wide coordination
- **lex-tick**: `mesh_interface` phase (one of 11) handles inbound mesh messages

## PreferenceProfile Helper (v0.1.1)

Domain-agnostic preference resolution from multiple sources. Lives in lex-mesh for Phase 2 generic exchange reuse.

**Module**: `Helpers::PreferenceProfile`

**Key methods:**
- `resolve(owner_id:, overrides: nil, personality: nil)` — returns resolved preference hash
- `store_preference(owner_id:, domain:, value:, source:)` — stores to lex-memory
- `clear_preferences(owner_id:, source: nil)` — clears explicit preferences
- `preference_instructions(profile:)` — translates profile to natural language prompt text

**Source priority** (highest confidence wins):
1. Explicit (1.0) — user said "prefer concise"
2. Preference learning (0.75) — pairwise observation via lex-preference-learning
3. Personality inference (0.4) — OCEAN traits mapped to style
4. Defaults (0.0) — fallback

**Preference domains**: verbosity, tone, format, technical_depth, custom:*

**Design doc**: `docs/work/completed/2026-03-15-preference-exchange-design.md`

## Preference Exchange Phase 2 (v0.4.0)

**Trust gating**: `handle_preference_query` checks requesting agent's trust composite via `Social::Trust::Runners::Trust.get_trust`. Agents below `TRUST_CONSIDER_THRESHOLD` (0.3) receive `{ success: false, reason: :insufficient_trust }`. Falls back to open sharing if trust module isn't loaded.

**Universal entry point**: `PreferenceProfile.for_agent(agent_id:)` — checks mesh cache first (returns `source: :mesh_cache`), falls back to local lex-memory resolve (`source: :local`). Includes `compatibility:` hash when personality data is available.

**Mesh cache**: `store_mesh_profile(agent_id:, profile:, source_agent_id:)` stores received preferences in-memory with TTL (default 3600s). `cached_mesh_profile(agent_id:, ttl:)` returns cached profile or nil if expired. `clear_mesh_cache(agent_id:)` for manual invalidation.

**Personality compatibility**: When `lex-agentic-self` is loaded and the cached profile includes a `:personality` hash, `for_agent` calls `personality_compatibility` and includes `{ score:, interpretation: }` in the response.

## Development Notes

- `online_agents` returns agents with `status: :online`; `SilenceWatchdog` actor marks agents `:offline` when `last_seen` exceeds `MESH_SILENCE_TIMEOUT` (30s)
- `MAX_HOPS` is enforced in `Registry#route_message`: accepts a `hops:` parameter (default 0) and rejects with `{ rejected: :max_hops_exceeded }` when `hops >= Topology::MAX_HOPS (3)`, including `hops: hops` in the message hash
- The `delivered_to` field in sent message result contains agent_id strings, not agent records
- Gossip queue spec added (3 specs covering queue_name, exchange, and routing_key)

---

**Maintained By**: Matthew Iverson (@Esity)
