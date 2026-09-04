# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'rbconfig'
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

  it 'loads Ferrum error classes from the public entrypoint' do
    root = File.expand_path('../..', __dir__)
    script = <<~'RUBY'
      require 'fetch_util'

      page = Object.new
      def page.add_script_tag(**) = raise 'primary failure'

      begin
        FetchUtil::Extractor.new.extract(page)
      rescue StandardError => error
        puts "#{error.class}: #{error.message}"
      end
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{File.join(root, "lib")}", '-e', script, chdir: root)

    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to eq("RuntimeError: primary failure\n")
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

  it 'restores a nil page timeout after extraction' do
    allow(page).to receive(:timeout).and_return(nil)
    allow(page).to receive(:timeout=)
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return({ 'markdown' => 'Hello' })

    described_class.new.extract(page)

    expect(page).to have_received(:timeout=).with(60).once
    expect(page).to have_received(:timeout=).with(nil).once
  end

  it 'preserves a successful payload when timeout restoration fails' do
    allow(page).to receive(:timeout).and_return(15)
    allow(page).to receive(:timeout=) do |timeout|
      raise Ferrum::Error, 'timeout restore failed' if timeout == 15
    end
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return({ 'markdown' => 'Hello' })

    expect(described_class.new.extract(page)).to include('markdown' => 'Hello')
  end

  it 'preserves a primary exception when timeout restoration fails' do
    allow(page).to receive(:timeout).and_return(15)
    allow(page).to receive(:timeout=) do |timeout|
      raise Ferrum::Error, 'timeout restore failed' if timeout == 15
    end
    allow(page).to receive(:add_script_tag).and_raise(RuntimeError, 'primary extraction failure')

    expect { described_class.new.extract(page) }.to raise_error(RuntimeError, 'primary extraction failure')
  end

  it 'retries extraction after stopping a busy page when asset injection times out' do
    add_script_attempts = 0

    allow(page).to receive(:timeout).and_return(15)
    allow(page).to receive(:timeout=)
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
      expect(page).to have_received(:timeout=).with(60).once
      expect(page).to have_received(:timeout=).with(15).once
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

  it 'owns the asset root used by later extraction' do
    with_asset_root do |asset_root|
      extractor = described_class.new(asset_root: asset_root)
      asset_root.replace('/missing/assets')
      allow(page).to receive(:add_script_tag).and_raise(Ferrum::TimeoutError)
      allow(page).to receive(:evaluate) do |script|
        script.match?(/window\.FetchUtilExtract\.extract/) ? { 'markdown' => 'Hello' } : true
      end

      expect(extractor.extract(page)).to include('markdown' => 'Hello')
    end
  end
end
