# frozen_string_literal: true

require 'legion/extensions/mesh/client'

RSpec.describe Legion::Extensions::Mesh::Client do
  it 'responds to mesh runner methods' do
    client = described_class.new
    expect(client).to respond_to(:register)
    expect(client).to respond_to(:unregister)
    expect(client).to respond_to(:heartbeat)
    expect(client).to respond_to(:send_message)
    expect(client).to respond_to(:find_agents)
    expect(client).to respond_to(:mesh_status)
  end
end
