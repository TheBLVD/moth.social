# frozen_string_literal: true

require 'rails_helper'

describe RequestPool do
  subject { described_class.new }

  describe '#with' do
    it 'returns a HTTP client for a host' do
      subject.with('http://example.com') do |http_client|
        expect(http_client).to be_a HTTP::Client
      end
    end

    it 'returns the same instance of HTTP client within the same thread for the same host' do
      test_client = nil

      subject.with('http://example.com') { |http_client| test_client = http_client }
      expect(test_client).to_not be_nil
      subject.with('http://example.com') { |http_client| expect(http_client).to be test_client }
    end

    it 'returns different HTTP clients for different hosts' do
      test_client = nil

      subject.with('http://example.com') { |http_client| test_client = http_client }
      expect(test_client).to_not be_nil
      subject.with('http://example.org') { |http_client| expect(http_client).to_not be test_client }
    end

    it 'grows to the number of threads accessing it' do
      stub_request(:get, 'http://example.com/').to_return(status: 200, body: 'Hello!')

      subject

      threads = 20.times.map do |i|
        Thread.new do
          20.times do
            subject.with('http://example.com') do |http_client|
              http_client.get('/').flush
            end
          end
        end
      end

      threads.map(&:join)

      expect(subject.size).to be > 1
    end

    # The frequency is how often the request pool reaper checks
    # for idle connections.  In real-world usage, it's 30 seconds,
    # but we change it to one here so the test doesn't take as long.
    it 'closes idle connections' do
      stub_const('RequestPool::FREQUENCY', 1)
      stub_request(:get, 'http://example.com/').to_return(status: 200, body: 'Hello!')
      subject.with('http://example.com') do |http_client|
        http_client.get('/').flush
      end

      expect(subject.size).to eq 1
      allow(Process).to receive(:clock_gettime) { Time.now.to_i + 100 }
      sleep(RequestPool::FREQUENCY * 2)
      expect(subject.size).to eq 0
    end
  end
end
