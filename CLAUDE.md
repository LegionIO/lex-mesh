# lex-mesh

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Agent-to-agent mesh communication layer for the LegionIO cognitive architecture. Manages agent registration, capability-based discovery, heartbeat status tracking, and message routing with unicast/multicast/broadcast patterns.

## Gem Info

- **Gem name**: `lex-mesh`
- **Version**: `0.1.1`
- **Module**: `Legion::Extensions::Mesh`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/mesh/
  version.rb
  helpers/
    topology.rb           # PROTOCOLS, PATTERNS, constants, valid_protocol?, valid_pattern?
    registry.rb           # Registry class - agents hash, capabilities index, messages buffer
    preference_profile.rb # PreferenceProfile - resolve, store, clear, preference_instructions
  runners/
    mesh.rb       # register, unregister, heartbeat, send_message, find_agents, mesh_status
spec/
  legion/extensions/mesh/
    runners/
      mesh_spec.rb
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

## Integration Points

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

**Design doc**: `docs/plans/2026-03-15-preference-exchange-design.md`

## Development Notes

- `online_agents` returns all agents with `status: :online` — currently all registered agents are always online since heartbeat timeout is not enforced
- `MESH_SILENCE_TIMEOUT` and `MAX_HOPS` are defined but not yet enforced in the routing logic
- The `delivered_to` field in sent message result contains agent_id strings, not agent records
