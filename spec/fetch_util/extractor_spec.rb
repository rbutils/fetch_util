# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe FetchUtil::Extractor do
  let(:page) { instance_double('FerrumPage') }

  def with_asset_root
    Dir.mktmpdir do |asset_root|
      FileUtils.mkdir_p(File.join(asset_root, 'vendor'))
      File.write(File.join(asset_root, 'vendor/readability.js'), 'window.Readability = true;', mode: 'w')
      File.write(File.join(asset_root, 'vendor/turndown.js'), 'window.TurndownService = true;', mode: 'w')
      File.write(File.join(asset_root, 'extract.js'), 'window.FetchUtilExtract = true;', mode: 'w')

      yield asset_root
    end
  end

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

    with_asset_root do |asset_root|
      payload = described_class.new(asset_root: asset_root).extract(page)

      expect(payload).to include('markdown' => 'Hello')
      expect(page).to have_received(:evaluate).with('window.stop && window.stop()')
    end
  end

  it 'caches inline fallback assets and extraction call per extractor instance' do
    with_asset_root do |asset_root|
      allow(page).to receive(:add_script_tag).and_raise(Ferrum::TimeoutError)
      allow(page).to receive(:evaluate) do |script|
        script.match?(/window\.FetchUtilExtract\.extract/) ? { 'markdown' => 'Hello' } : true
      end
      allow(JSON).to receive(:generate).and_call_original
      allow(File).to receive(:read).and_call_original

      extractor = described_class.new(asset_root: asset_root)

      2.times { expect(extractor.extract(page)).to include('markdown' => 'Hello') }

      expect(File).to have_received(:read).exactly(3).times
      expect(JSON).to have_received(:generate).once
    end
  end
end
