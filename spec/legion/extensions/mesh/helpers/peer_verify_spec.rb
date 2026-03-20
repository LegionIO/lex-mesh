# frozen_string_literal: true

require 'spec_helper'
require 'ed25519'

RSpec.describe Legion::Extensions::Mesh::Helpers::PeerVerify do
  let(:signing_key) { Ed25519::SigningKey.generate }
  let(:verify_key) { signing_key.verify_key }
  let(:private_key_b64) { Base64.strict_encode64(signing_key.to_bytes) }
  let(:public_key_b64) { Base64.strict_encode64(verify_key.to_bytes) }

  let(:peer_config) do
    [{ org_id: 'acme', public_key: "ed25519:#{public_key_b64}",
       capabilities: %w[query task], rate_limit: 5 }]
  end

  before do
    described_class.reset_counters!
    stub_const('Legion::Settings', Module.new) unless defined?(Legion::Settings)
    allow(Legion::Settings).to receive(:dig).with(:mesh, :trusted_peers).and_return(peer_config)
  end

  describe '.sign_message' do
    it 'signs a payload with Ed25519' do
      result = described_class.sign_message({ hello: 'world' }, private_key_b64)
      expect(result[:signature]).to be_a(String)
      expect(result[:payload]).to eq({ hello: 'world' })
    end
  end

  describe '.verify_message' do
    it 'verifies a validly signed message' do
      signed = described_class.sign_message({ hello: 'world' }, private_key_b64)
      result = described_class.verify_message(signed, org_id: 'acme')
      expect(result[:valid]).to be true
      expect(result[:org_id]).to eq('acme')
    end

    it 'rejects a tampered message' do
      signed = described_class.sign_message({ hello: 'world' }, private_key_b64)
      signed[:signed_bytes] = 'tampered data'
      result = described_class.verify_message(signed, org_id: 'acme')
      expect(result[:valid]).to be false
      expect(result[:reason]).to eq(:invalid_signature)
    end

    it 'rejects unknown peers' do
      signed = described_class.sign_message({ hello: 'world' }, private_key_b64)
      result = described_class.verify_message(signed, org_id: 'unknown-org')
      expect(result[:valid]).to be false
      expect(result[:reason]).to eq(:unknown_peer)
    end
  end

  describe '.check_rate_limit' do
    it 'allows messages within limit' do
      result = described_class.check_rate_limit('acme')
      expect(result[:allowed]).to be true
    end

    it 'blocks messages over limit' do
      5.times { described_class.check_rate_limit('acme') }
      result = described_class.check_rate_limit('acme')
      expect(result[:allowed]).to be false
      expect(result[:error]).to eq(:rate_limited)
    end

    it 'resets after window expires' do
      5.times { described_class.check_rate_limit('acme') }
      counters = described_class.instance_variable_get(:@counters)
      counters['acme'][:window_start] = Time.now.utc - 61
      result = described_class.check_rate_limit('acme')
      expect(result[:allowed]).to be true
    end
  end
end
