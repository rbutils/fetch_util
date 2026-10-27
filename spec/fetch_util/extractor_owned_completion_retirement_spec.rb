# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Extractor::OwnedEvaluation, 'completed-work retirement' do
  let(:frame) { double('retirement frame', execution_id!: 17) }
  let(:page) { double('retirement page', main_frame: frame) }
  let(:payload) { { 'markdown' => "Complete material\n\n```\nfirst\n\nlast\n```", 'readerMode' => false } }
  let(:calls) { [] }
  let(:clock) { { now: 0.0 } }
  let(:costs) { {} }
  let(:errors) { {} }
  let(:protocol) { {} }
  let(:owned) { false }
  let(:deferred) { false }
  let(:collection_flag) { true }
  let(:collection_type) { 'boolean' }
  let(:properties) do
    rows = [
      { 'name' => 'owned', 'value' => { 'type' => 'boolean', 'value' => owned } },
      { 'name' => 'finish', 'value' => { 'type' => 'function', 'objectId' => 'finish-task' } }
    ]
    rows << { 'name' => 'prepare', 'value' => { 'type' => 'function' } } if deferred
    unless collection_flag.nil?
      rows << { 'name' => 'collectAfterFinish', 'value' => { 'type' => collection_type, 'value' => collection_flag } }
    end
    rows
  end
  subject(:evaluation) { described_class.new(page, 'retirementPreparation()', budget: 200) }

  before do
    allow(page).to receive(:timeout=)
    allow(evaluation).to receive(:monotonic_time) { clock.fetch(:now) }
    allow(page).to receive(:command) do |method, **parameters|
      calls << [method, parameters]
      declaration = parameters[:functionDeclaration].to_s
      phase = if declaration.include?('retirementPreparation()')
                'start'
              elsif declaration.include?('return this.finish()')
                'finish'
              elsif declaration.include?('this.dispose()')
                'dispose'
              else
                method
              end
      clock[:now] += costs.fetch(phase, 0)
      case method
      when 'Runtime.callFunctionOn'
        if declaration.include?('retirementPreparation()')
          protocol[:direct] ? { 'result' => { 'value' => payload } } : { 'result' => { 'objectId' => 'retirement-task' } }
        elsif declaration.include?('return this.finish()')
          if errors[:finish]
            { 'exceptionDetails' => { 'text' => errors[:finish], 'exception' => { 'description' => errors[:finish] } } }
          else
            { 'result' => { 'value' => payload } }
          end
        else
          {}
        end
      when 'Runtime.getProperties' then { 'result' => properties }
      when 'HeapProfiler.collectGarbage'
        raise errors.fetch(:collector) if errors[:collector]
        {}
      when 'Runtime.releaseObjectGroup' then {}
      else raise "Unexpected retirement command: #{method}"
      end
    end
  end

  def collections
    calls.select { |method, _parameters| method == 'HeapProfiler.collectGarbage' }
  end

  def finalizations
    calls.select { |_method, parameters| parameters[:functionDeclaration].to_s.include?('return this.finish()') }
  end

  it 'collects only after complete serialization, disposal and group release when explicitly opted in' do
    expect(evaluation.call).to equal(payload)
    expected_commands = [
      'Runtime.callFunctionOn', 'Runtime.getProperties', 'Runtime.callFunctionOn',
      'Runtime.callFunctionOn', 'Runtime.releaseObjectGroup', 'HeapProfiler.collectGarbage'
    ]
    expect(calls.map(&:first)).to eq(expected_commands)
    expect(finalizations.length).to eq(1)
    expect(finalizations.first.last.fetch(:returnByValue)).to be(true)
    expect(calls[-3].last.fetch(:functionDeclaration)).to include('this.dispose()')
    expect(calls[-2].last.fetch(:objectGroup)).to eq(calls.first.last.fetch(:objectGroup))
  end

  context 'without the optional field' do
    let(:collection_flag) { nil }

    it 'retains the complete legacy ordinary-descriptor contract' do
      expect(evaluation.call).to equal(payload)
      expect(collections).to be_empty
      expect(finalizations.length).to eq(1)
    end
  end

  context 'with an explicit false field' do
    let(:collection_flag) { false }

    it 'does not add retirement collection' do
      expect(evaluation.call).to equal(payload)
      expect(collections).to be_empty
    end
  end

  it 'preserves a completion error without collecting or retrying extraction' do
    errors[:finish] = 'original completion failure'
    expect { evaluation.call }.to raise_error(Ferrum::JavaScriptError, /original completion failure/)
    expect(collections).to be_empty
    expect(finalizations.length).to eq(1)
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  it 'does not replace a completed result when optional retirement collection times out' do
    errors[:collector] = Ferrum::TimeoutError.new('retirement collection timeout')
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    expect(finalizations.length).to eq(1)
  end

  it 'retains the completed result on a transport without the optional collector' do
    errors[:collector] = Ferrum::BrowserError.new('method unavailable')
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    expect(finalizations.length).to eq(1)
  end

  it 'does not borrow a new deadline after retirement consumes the remaining budget' do
    costs['Runtime.releaseObjectGroup'] = 210
    expect(evaluation.call).to equal(payload)
    expect(collections).to be_empty
    expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
  end

  it 'charges retirement collection to the remaining original budget' do
    costs.merge!('start' => 10, 'finish' => 15, 'dispose' => 5, 'Runtime.releaseObjectGroup' => 5)
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    expect(page).to have_received(:timeout=).with(165)
  end

  context 'with a malformed opt-in declaration' do
    let(:collection_type) { 'string' }

    it 'rejects the descriptor before invoking any work' do
      expect { evaluation.call }.to raise_error(FetchUtil::ExtractionError, 'Invalid owned extraction work descriptor')
      expect(finalizations).to be_empty
      expect(collections).to be_empty
      expect(calls.last.first).to eq('Runtime.releaseObjectGroup')
    end
  end

  it 'does not carry the opt-in into a subsequent legacy descriptor' do
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    properties.reject! { |row| row.fetch('name') == 'collectAfterFinish' }
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    expect(finalizations.length).to eq(2)
  end

  context 'with deferred owned rendering' do
    let(:owned) { true }
    let(:deferred) { true }

    it 'retains both original collection boundaries and retires the completed result once' do
      expect(evaluation.call).to equal(payload)
      expect(collections.length).to eq(3)
      expect(finalizations.length).to eq(1)
      expect(calls.count { |_method, parameters| parameters[:functionDeclaration].to_s.include?('return this.prepare()') }).to eq(1)
      expect(calls.last.first).to eq('HeapProfiler.collectGarbage')
    end
  end

  it 'does not collect after a subsequent failed completion using the same evaluator' do
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    errors[:finish] = 'later completion failure'
    expect { evaluation.call }.to raise_error(Ferrum::JavaScriptError, /later completion failure/)
    expect(collections.length).to eq(1)
  end

  it 'does not collect again for a subsequent direct primitive transport result' do
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    protocol[:direct] = true
    expect(evaluation.call).to equal(payload)
    expect(collections.length).to eq(1)
    expect(finalizations.length).to eq(1)
  end
end
