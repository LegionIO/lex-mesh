# frozen_string_literal: true

require 'legion/extensions/mesh/version'
require 'legion/extensions/mesh/helpers/topology'
require 'legion/extensions/mesh/helpers/registry'
require 'legion/extensions/mesh/helpers/preference_profile'
require 'legion/extensions/mesh/runners/mesh'

module Legion
  module Extensions
    module Mesh
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
