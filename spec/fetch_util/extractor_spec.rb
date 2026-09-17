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
      File.write(
        File.join(asset_root, 'extract.js'),
        '(function(deliver) { deliver({ extract: function(options) { return options; } }); })' \
        '("fetch-util:standalone-api:v1");',
        mode: 'w'
      )

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

    expect(page).to have_received(:add_script_tag).exactly(2).times
    expect(page).to have_received(:evaluate).with(/__fetchUtilPrivateApi\.extract\(\{"reader_mode":true,/)
    expect(page).to have_received(:evaluate).with(/"shadow_root_token":"[a-f0-9]{64}"/)
    expect(page).to have_received(:evaluate).with(/"shadow_root_reader_property":"__fetchUtilClosedShadowRootReaderV1_[a-f0-9]{32}"/)
    expect(page).not_to have_received(:evaluate).with(/window\.FetchUtilExtract\.extract/)
  end

  it 'registers parser-created closed roots through CDP before extraction' do
    commands = []
    document = {
      'root' => {
        'backendNodeId' => 1,
        'children' => [{
          'backendNodeId' => 2,
          'shadowRoots' => [{ 'backendNodeId' => 3, 'shadowRootType' => 'closed' }]
        }]
      }
    }
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return({ 'markdown' => 'Closed content' })
    allow(page).to receive(:command) do |method, **parameters|
      commands << [method, parameters]
      case method
      when 'DOM.getDocument' then document
      when 'DOM.resolveNode'
        { 'object' => { 'objectId' => "object-#{parameters.fetch(:backendNodeId)}" } }
      when 'Runtime.callFunctionOn' then { 'result' => { 'value' => true } }
      when 'Runtime.releaseObject' then {}
      end
    end

    expect(described_class.new.extract(page)).to include('markdown' => 'Closed content')

    expect(commands.map(&:first)).to eq([
                                          'DOM.getDocument', 'DOM.resolveNode', 'DOM.resolveNode',
                                          'Runtime.callFunctionOn', 'Runtime.releaseObject', 'Runtime.releaseObject'
                                        ])
    registration = commands.find { |method, _parameters| method == 'Runtime.callFunctionOn' }.last
    expect(registration.fetch(:arguments)).to include(
      { value: FetchUtil::Browser::SHADOW_ROOT_READER_PROPERTY },
      { value: FetchUtil::Browser::SHADOW_ROOT_ACCESS_TOKEN }
    )
  end

  it 'continues extraction when the pierced CDP document is unavailable' do
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return({ 'markdown' => 'Ordinary content' })
    allow(page).to receive(:command).with('DOM.getDocument', depth: -1, pierce: true)
                                    .and_raise(Ferrum::TimeoutError, 'timed out')

    expect(described_class.new.extract(page)).to include('markdown' => 'Ordinary content')
  end

  it 'releases every resolved CDP object when registration fails' do
    released = []
    document = {
      'root' => {
        'backendNodeId' => 1,
        'children' => [{
          'backendNodeId' => 2,
          'shadowRoots' => [{ 'backendNodeId' => 3, 'shadowRootType' => 'closed' }]
        }]
      }
    }
    allow(page).to receive(:add_script_tag)
    allow(page).to receive(:evaluate).and_return({ 'markdown' => 'Fallback content' })
    allow(page).to receive(:command) do |method, **parameters|
      case method
      when 'DOM.getDocument' then document
      when 'DOM.resolveNode'
        { 'object' => { 'objectId' => "object-#{parameters.fetch(:backendNodeId)}" } }
      when 'Runtime.callFunctionOn' then raise Ferrum::BrowserError, 'stale node'
      when 'Runtime.releaseObject'
        released << parameters.fetch(:objectId)
        raise Ferrum::BrowserError, 'release failed' if released.one?
      end
    end

    expect(described_class.new.extract(page)).to include('markdown' => 'Fallback content')
    expect(released).to eq(%w[object-2 object-3])
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
      when /__fetchUtilPrivateApi\.extract/
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
        script.match?(/__fetchUtilPrivateApi\.extract/) ? { 'markdown' => 'Hello' } : true
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
        script.match?(/__fetchUtilPrivateApi\.extract/) ? { 'markdown' => 'Hello' } : true
      end

      expect(extractor.extract(page)).to include('markdown' => 'Hello')
    end
  end
end
