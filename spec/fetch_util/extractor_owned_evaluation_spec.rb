# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Extractor::OwnedEvaluation do
  let(:frame) { double('owned frame', execution_id!: 17) }
  let(:page) { double('owned page', main_frame: frame) }
  let(:payload) { { 'markdown' => 'Complete material', 'readerMode' => false, 'byline' => nil } }
  let(:owned) { true }
  let(:deferred) { false }
  let(:calls) { [] }
  let(:clock) { { now: 0.0 } }
  let(:phase_costs) { {} }
  subject(:evaluation) { described_class.new(page, 'privatePreparation()', budget: 200) }

  before do
    allow(page).to receive(:timeout=)
    allow(evaluation).to receive(:monotonic_time) { clock.fetch(:now) }
    allow(page).to receive(:command) do |method, **parameters|
      calls << [method, parameters]
      declaration = parameters[:functionDeclaration]
      phase = if declaration&.include?('privatePreparation()')
                'prepare'
              elsif declaration&.include?('return this.prepare()')
                'owned preparation'
              else
                method
              end
      clock[:now] += phase_costs.fetch(phase, 0)
      case method
      when 'Runtime.callFunctionOn'
        if parameters.fetch(:functionDeclaration).include?('privatePreparation()')
          { 'result' => { 'type' => 'object', 'objectId' => 'owned-task' } }
        elsif parameters.fetch(:functionDeclaration).include?('return this.finish()')
          { 'result' => { 'value' => payload } }
        else
          {}
        end
      when 'Runtime.getProperties'
        properties = [
          { 'name' => 'owned', 'value' => { 'type' => 'boolean', 'value' => owned } },
          { 'name' => 'finish', 'value' => { 'type' => 'function', 'objectId' => 'finish-task' } }
        ]
        properties << { 'name' => 'prepare', 'value' => { 'type' => 'function', 'objectId' => 'prepare-task' } } if deferred
        { 'result' => properties }
      when 'HeapProfiler.collectGarbage', 'Runtime.releaseObjectGroup' then {}
      else raise "Unexpected protocol command: #{method}"
      end
    end
  end

  it 'reclaims only completed owned work and releases the whole remote group' do
    expect(evaluation.call).to eq(payload)
    expected = [
      'Runtime.callFunctionOn', 'Runtime.getProperties', 'HeapProfiler.collectGarbage',
      'Runtime.callFunctionOn', 'Runtime.callFunctionOn', 'Runtime.releaseObjectGroup'
    ]
    expect(calls.map(&:first)).to eq(expected)
    expect(calls.first.last.fetch(:executionContextId)).to eq(17)
    expect(calls.last.last).to include(objectGroup: calls.first.last.fetch(:objectGroup), async: true)
    expect(calls[-2].last.fetch(:async)).to be(true)
  end

  context 'when the ordinary extraction has no completed owned material' do
    let(:owned) { false }

    it 'finishes once without forcing collection or changing the payload' do
      expect(evaluation.call).to eq(payload)
      expect(calls.map(&:first)).not_to include('HeapProfiler.collectGarbage')
      expect(calls.count { |_method, parameters| parameters[:functionDeclaration]&.include?('return this.finish()') }).to eq(1)
    end
  end

  it 'shares the original larger deadline instead of granting each command another wait' do
    phase_costs.merge!('prepare' => 160, 'HeapProfiler.collectGarbage' => 30)
    expect(evaluation.call).to eq(payload)
    expect(page).to have_received(:timeout=).with(200)
    expect(page).to have_received(:timeout=).with(40).twice
    expect(page).to have_received(:timeout=).with(10)
  end

  it 'never queues finalization after preparation times out' do
    error = Ferrum::TimeoutError.new('preparation timeout')
    allow(page).to receive(:command).with('Runtime.callFunctionOn', hash_including(executionContextId: 17))
                                    .and_raise(error)
    expect { evaluation.call }.to(raise_error { |raised| expect(raised).to equal(error) })
    expect(calls.none? { |_method, parameters| parameters[:functionDeclaration]&.include?('return this.finish()') }).to be(true)
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  it 'disposes and releases owned work when collection times out without retrying extraction' do
    error = Ferrum::TimeoutError.new('collection timeout')
    allow(page).to receive(:command).with('HeapProfiler.collectGarbage').and_raise(error)
    expect { evaluation.call }.to(raise_error { |raised| expect(raised).to equal(error) })
    expect(calls.none? { |_method, parameters| parameters[:functionDeclaration]&.include?('return this.finish()') }).to be(true)
    expect(calls[-2].last.fetch(:functionDeclaration)).to include('this.dispose()')
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  it 'rejects malformed work descriptors while releasing every remote object' do
    allow(page).to receive(:command).with('Runtime.getProperties', objectId: 'owned-task', ownProperties: true)
                                    .and_return({ 'result' => [] })
    expect { evaluation.call }.to raise_error(FetchUtil::ExtractionError, 'Invalid owned extraction work descriptor')
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  it 'preserves JavaScript errors and releases the work rather than evaluating it again' do
    allow(page).to receive(:command).with(
      'Runtime.callFunctionOn',
      objectId: 'owned-task',
      functionDeclaration: 'function() { return this.finish(); }',
      returnByValue: true
    ).and_return({ 'exceptionDetails' => { 'text' => 'render failure', 'exception' => { 'description' => 'render failure' } } })
    expect { evaluation.call }.to raise_error(Ferrum::JavaScriptError, /render failure/)
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  it 'keeps complete extraction available when an older transport lacks the optional collector' do
    allow(page).to receive(:command).with('HeapProfiler.collectGarbage').and_raise(Ferrum::BrowserError, 'method unavailable')
    expect(evaluation.call).to eq(payload)
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  context 'when owned rendering is deferred' do
    let(:deferred) { true }

    it 'collects before and after completed preparation without duplicating preparation or finalization' do
      expect(evaluation.call).to eq(payload)
      expected = [
        'Runtime.callFunctionOn', 'Runtime.getProperties', 'HeapProfiler.collectGarbage',
        'Runtime.callFunctionOn', 'HeapProfiler.collectGarbage', 'Runtime.callFunctionOn',
        'Runtime.callFunctionOn', 'Runtime.releaseObjectGroup'
      ]
      expect(calls.map(&:first)).to eq(expected)
      expect(calls[3].last.fetch(:functionDeclaration)).to include('return this.prepare()')
      expect(calls[5].last.fetch(:functionDeclaration)).to include('return this.finish()')
    end

    it 'charges both collections and preparation to the original deadline' do
      phase_costs.merge!('prepare' => 20, 'owned preparation' => 110, 'HeapProfiler.collectGarbage' => 30)
      expect(evaluation.call).to eq(payload)
      [200, 150, 40, 10].each { |remaining| expect(page).to have_received(:timeout=).with(remaining) }
      expect(page).to have_received(:timeout=).with(180).twice
    end

    it 'releases a timed-out preparation without queuing finalization' do
      error = Ferrum::TimeoutError.new('deferred preparation timeout')
      allow(page).to receive(:command).with(
        'Runtime.callFunctionOn',
        objectId: 'owned-task',
        functionDeclaration: 'function() { return this.prepare(); }',
        returnByValue: false
      ).and_raise(error)
      expect { evaluation.call }.to(raise_error { |raised| expect(raised).to equal(error) })
      expect(calls.none? { |_method, parameters| parameters[:functionDeclaration]&.include?('return this.finish()') }).to be(true)
      expect(calls[-2].last.fetch(:functionDeclaration)).to include('this.dispose()')
      expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
    end

    it 'retains both phases when an older transport lacks collection support' do
      allow(page).to receive(:command).with('HeapProfiler.collectGarbage').and_raise(Ferrum::BrowserError, 'method unavailable')
      expect(evaluation.call).to eq(payload)
      expect(calls.count { |_method, parameters| parameters[:functionDeclaration]&.include?('return this.prepare()') }).to eq(1)
      expect(calls.count { |_method, parameters| parameters[:functionDeclaration]&.include?('return this.finish()') }).to eq(1)
    end

    it 'rejects a non-function preparation before collecting or invoking it' do
      properties = [
        { 'name' => 'owned', 'value' => { 'type' => 'boolean', 'value' => true } },
        { 'name' => 'finish', 'value' => { 'type' => 'function' } },
        { 'name' => 'prepare', 'value' => { 'type' => 'string', 'value' => 'prepare' } }
      ]
      allow(page).to receive(:command).with('Runtime.getProperties', objectId: 'owned-task', ownProperties: true)
                                      .and_return({ 'result' => properties })
      expect { evaluation.call }.to raise_error(FetchUtil::ExtractionError, 'Invalid owned extraction work descriptor')
      expect(calls.map(&:first)).not_to include('HeapProfiler.collectGarbage')
      expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
    end
  end
end
