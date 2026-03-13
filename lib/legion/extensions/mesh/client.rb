# frozen_string_literal: true

require 'legion/extensions/mesh/helpers/topology'
require 'legion/extensions/mesh/helpers/registry'
require 'legion/extensions/mesh/runners/mesh'

module Legion
  module Extensions
    module Mesh
      class Client
        include Runners::Mesh

        def initialize(**)
          @mesh_registry = Helpers::Registry.new
        end

        private

        attr_reader :mesh_registry
      end
    end
  end
end
