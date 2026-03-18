# frozen_string_literal: true

require_relative 'lib/legion/extensions/mesh/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-mesh'
  spec.version       = Legion::Extensions::Mesh::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Mesh'
  spec.description   = 'Agent-to-agent mesh communication protocol for brain-modeled agentic AI'
  spec.homepage      = 'https://github.com/LegionIO/lex-mesh'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-mesh'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-mesh'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-mesh'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-mesh/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-mesh.gemspec Gemfile]
  end
  spec.require_paths = ['lib']
end
