# frozen_string_literal: true

require 'legion/extensions/mesh/runners/mesh'
require 'legion/extensions/mesh/runners/preferences'
require 'legion/extensions/mesh/runners/delegation'
require 'legion/extensions/mesh/runners/task_request'
require 'legion/extensions/mesh/helpers/preference_profile'
require 'legion/extensions/mesh/helpers/pending_requests'
require 'legion/extensions/mesh/helpers/topology'
require 'legion/extensions/mesh/helpers/registry'

module Legion
  module Extensions
    module Mesh
      class Client
        include Runners::Mesh
        include Runners::Preferences
        include Runners::Delegation
        include Runners::TaskRequest

        def initialize(**opts)
          @opts = opts
          @mesh_registry = Helpers::Registry.new # rubocop:disable Legion/Singleton/UseInstance
        end

        private

        attr_reader :mesh_registry
      end
    end
  end
end
