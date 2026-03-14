# lex-mesh

Agent-to-agent mesh communication for brain-modeled agentic AI. Provides agent registration, capability discovery, heartbeat monitoring, and message routing with unicast, multicast, and broadcast patterns.

## Overview

`lex-mesh` implements the communication layer between agents in a swarm or multi-agent system. Agents register themselves with their capabilities, send and receive messages via routing patterns, and maintain presence via heartbeats.

## Message Routing Patterns

| Pattern | Description |
|---------|-------------|
| `unicast` | Direct message to a specific agent |
| `multicast` | Message to all agents with a given capability |
| `broadcast` | Message to all registered agents |

## Supported Protocols

`grpc`, `websocket`, `rest`

## Installation

Add to your Gemfile:

```ruby
gem 'lex-mesh'
```

## Usage

### Registering Agents

```ruby
require 'legion/extensions/mesh'

Legion::Extensions::Mesh::Runners::Mesh.register(
  agent_id: "agent-42",
  capabilities: [:code_review, :test_generation],
  endpoint: "http://agent-42.internal:9000"
)
# => { registered: true, agent_id: "agent-42" }
```

### Heartbeats

```ruby
# Keep agent marked as online
Legion::Extensions::Mesh::Runners::Mesh.heartbeat(agent_id: "agent-42")
# => { alive: true }
```

### Sending Messages

```ruby
# Unicast to specific agent
Legion::Extensions::Mesh::Runners::Mesh.send_message(
  from: "agent-1",
  to: "agent-42",
  pattern: :unicast,
  payload: { task: "review PR #123" }
)
# => { sent: true, delivered_to: ["agent-42"], count: 1 }

# Multicast to all agents with a capability
Legion::Extensions::Mesh::Runners::Mesh.send_message(
  from: "agent-1",
  capability: :code_review,
  pattern: :multicast,
  payload: { task: "review PR #123" }
)

# Broadcast to all registered agents
Legion::Extensions::Mesh::Runners::Mesh.send_message(
  from: "coordinator",
  pattern: :broadcast,
  payload: { announcement: "swarm starting" }
)
```

### Discovery

```ruby
# Find all agents with a capability
Legion::Extensions::Mesh::Runners::Mesh.find_agents(capability: :code_review)
# => { agents: ["agent-42", "agent-7"], count: 2 }

# Mesh status
Legion::Extensions::Mesh::Runners::Mesh.mesh_status
# => { total: 5, online: 4, message_count: 23 }
```

### Unregistering

```ruby
Legion::Extensions::Mesh::Runners::Mesh.unregister(agent_id: "agent-42")
# => { unregistered: true }
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
