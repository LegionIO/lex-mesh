# frozen_string_literal: true

module Legion
  module Extensions
    module Mesh
      module Transport
        module Exchanges
          class Fanout < Legion::Transport::Exchange
            def exchange_name
              'amq.fanout'
            end

            def default_type
              'fanout'
            end

            def default_options
              hash = super
              hash[:passive] = true
              hash
            end
          end
        end
      end
    end
  end
end
