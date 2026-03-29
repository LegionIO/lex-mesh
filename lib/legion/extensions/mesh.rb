# frozen_string_literal: true

require 'legion/extensions/mesh/version'
require 'legion/extensions/mesh/helpers/topology'
require 'legion/extensions/mesh/helpers/registry'
require 'legion/extensions/mesh/helpers/preference_profile'
require 'legion/extensions/mesh/helpers/pending_requests'
require 'legion/extensions/mesh/helpers/delegation'
require 'legion/extensions/mesh/helpers/peer_verify'
require 'legion/extensions/mesh/helpers/peer_table'
require 'legion/extensions/mesh/runners/mesh'
require 'legion/extensions/mesh/runners/preferences'
require 'legion/extensions/mesh/runners/delegation'
require 'legion/extensions/mesh/runners/task_request'

if defined?(Legion::Transport)
  require 'legion/extensions/mesh/transport/messages/preference_query'
  require 'legion/extensions/mesh/transport/messages/preference_response'
  require 'legion/extensions/mesh/transport/messages/mesh_departure'
  require 'legion/extensions/mesh/transport/messages/gossip'
  require 'legion/extensions/mesh/transport/messages/mesh_conflict'
  require 'legion/extensions/mesh/transport/queues/preference'
  require 'legion/extensions/mesh/transport/queues/gossip'
end

module Legion
  module Extensions
    module Mesh
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
