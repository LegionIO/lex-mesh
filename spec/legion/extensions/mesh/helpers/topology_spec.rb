# frozen_string_literal: true

RSpec.describe Legion::Extensions::Mesh::Helpers::Topology do
  describe 'constants' do
    it 'defines PROTOCOLS as a frozen array of symbols' do
      expect(described_class::PROTOCOLS).to eq(%i[grpc websocket rest])
      expect(described_class::PROTOCOLS).to be_frozen
    end

    it 'defines PATTERNS as a frozen array of symbols' do
      expect(described_class::PATTERNS).to eq(%i[unicast multicast broadcast])
      expect(described_class::PATTERNS).to be_frozen
    end

    it 'defines MESH_SILENCE_TIMEOUT as 30' do
      expect(described_class::MESH_SILENCE_TIMEOUT).to eq(30)
    end

    it 'defines TRUST_CONSIDER_THRESHOLD as 0.3' do
      expect(described_class::TRUST_CONSIDER_THRESHOLD).to eq(0.3)
    end

    it 'defines MAX_HOPS as 3' do
      expect(described_class::MAX_HOPS).to eq(3)
    end
  end

  describe '.valid_protocol?' do
    it 'returns true for :grpc' do
      expect(described_class.valid_protocol?(:grpc)).to be true
    end

    it 'returns true for :websocket' do
      expect(described_class.valid_protocol?(:websocket)).to be true
    end

    it 'returns true for :rest' do
      expect(described_class.valid_protocol?(:rest)).to be true
    end

    it 'returns false for an unknown protocol' do
      expect(described_class.valid_protocol?(:http2)).to be false
    end

    it 'returns false for nil' do
      expect(described_class.valid_protocol?(nil)).to be false
    end

    it 'returns false for a string version of a valid protocol' do
      expect(described_class.valid_protocol?('grpc')).to be false
    end

    it 'accepts all PROTOCOLS members as valid' do
      described_class::PROTOCOLS.each do |proto|
        expect(described_class.valid_protocol?(proto)).to be true
      end
    end
  end

  describe '.valid_pattern?' do
    it 'returns true for :unicast' do
      expect(described_class.valid_pattern?(:unicast)).to be true
    end

    it 'returns true for :multicast' do
      expect(described_class.valid_pattern?(:multicast)).to be true
    end

    it 'returns true for :broadcast' do
      expect(described_class.valid_pattern?(:broadcast)).to be true
    end

    it 'returns false for an unknown pattern' do
      expect(described_class.valid_pattern?(:anycast)).to be false
    end

    it 'returns false for nil' do
      expect(described_class.valid_pattern?(nil)).to be false
    end

    it 'returns false for a string version of a valid pattern' do
      expect(described_class.valid_pattern?('unicast')).to be false
    end

    it 'accepts all PATTERNS members as valid' do
      described_class::PATTERNS.each do |pat|
        expect(described_class.valid_pattern?(pat)).to be true
      end
    end
  end
end
