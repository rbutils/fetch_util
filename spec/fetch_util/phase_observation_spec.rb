# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil.const_get(:PhaseObservation, false) do
  it 'emits immutable start and finish events from a deterministic monotonic clock' do
    now = 4.0
    events = []
    observation = described_class.new(url: 'https://example.test/a', callback: events.method(:<<), clock: -> { now })

    result = observation.measure(:extract, attempt: 2) do
      now += 0.25
      :payload
    end

    expect(result).to eq(:payload)
    expect(events.length).to eq(2)
    expect(events.first).to include(url: 'https://example.test/a', phase: :extract, edge: :start, duration: nil, attempt: 2)
    expect(events.last).to include(url: 'https://example.test/a', phase: :extract, edge: :finish, duration: 0.25, attempt: 2)
    expect(events.map { |event| event[:request_id] }.uniq.length).to eq(1)
    expect(events.first[:request_id]).to be_a(Integer)
    expect(events.last).to include(outcome: :success, error_class: nil)
    expect(events).to all(be_frozen)
  end

  it 'retains the operation error when the observer raises' do
    observer = ->(_event) { raise 'observer failure' }
    observation = described_class.new(url: 'https://example.test/a', callback: observer, clock: -> { 1.0 })

    expect { observation.measure(:extract) { raise IOError, 'extract failed' } }
      .to raise_error(IOError, 'extract failed')
  end

  it 'distinguishes concurrent observations for the same URL' do
    events = Queue.new
    observations = 2.times.map do
      ticks = 0
      described_class.new(url: 'https://same.example.test/', callback: events.method(:<<), clock: -> { ticks += 1 })
    end
    threads = observations.map { |observation| Thread.new { observation.measure(:navigation) { Thread.pass } } }
    threads.each(&:join)
    captured = 4.times.map { events.pop }

    expect(captured.group_by { |event| event[:request_id] }.transform_values(&:length).values).to eq([2, 2])
    expect(captured.map { |event| event[:url] }.uniq).to eq(['https://same.example.test/'])
    expect(captured.select { |event| event[:edge] == :finish }.map { |event| event[:duration] }).to eq([1, 1])
  end

  it 'keeps disabled observation silent and clock-free' do
    disabled = described_class.disabled

    expect(disabled.measure(:extract, attempt: 4) { :result }).to eq(:result)
    expect(disabled).to be_frozen
  end
end
