# frozen_string_literal: true

RSpec.describe FetchUtil::Extractor do
  let(:page) { instance_double('FerrumPage') }

  it 'injects bundled assets before extraction' do
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return({ 'markdown' => 'Hello' })

    described_class.new.extract(page)

    expect(page).to have_received(:add_script_tag).exactly(3).times
    expect(page).to have_received(:evaluate).with(/window\.FetchUtilExtract\.extract/)
  end

  it 'raises when extraction payload is missing' do
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return(nil)

    expect { described_class.new.extract(page) }.to raise_error(FetchUtil::ExtractionError)
  end

  it 'retries extraction after stopping a busy page when asset injection times out' do
    add_script_attempts = 0

    allow(page).to receive(:add_script_tag) do
      add_script_attempts += 1
      raise Ferrum::TimeoutError if add_script_attempts == 1
      true
    end

    allow(page).to receive(:evaluate) do |script|
      case script
      when 'window.stop && window.stop()'
        true
      when /window\.FetchUtilExtract\.extract/
        { 'markdown' => 'Hello' }
      else
        true
      end
    end

    payload = described_class.new.extract(page)

    expect(payload).to include('markdown' => 'Hello')
    expect(page).to have_received(:evaluate).with('window.stop && window.stop()')
  end
end
