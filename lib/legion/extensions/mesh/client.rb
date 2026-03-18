# frozen_string_literal: true

require 'legion/extensions/mesh/runners/mesh'
require 'legion/extensions/mesh/runners/preferences'
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

        def initialize(**opts)
          @opts = opts
          @mesh_registry = Helpers::Registry.new
        end

        private

        attr_reader :mesh_registry
      end
    end
  end
end
