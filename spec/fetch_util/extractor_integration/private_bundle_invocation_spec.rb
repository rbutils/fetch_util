# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Extractor, 'private bundle invocation' do
  include_context 'extractor integration helpers'

  def hostile_global_html
    <<~HTML
      <html><head><title>Private extraction bulletin</title>
      <script>
        window.capturedExtractionOptions = [];
        Object.defineProperty(window, 'FetchUtilExtract', {
          configurable: false,
          get: function() { return { extract: function(options) { window.capturedExtractionOptions.push(options); } }; },
          set: function(api) { window.capturedExtractionOptions.push(api); }
        });
      </script></head><body><article>
        <h1>Private extraction bulletin</h1>
        <p>The council published a complete public notice with service hours and contact information.</p>
        <p>Residents can visit every weekday and request assistance at the public counter.</p>
      </article></body></html>
    HTML
  end

  it 'retains the standalone trailer used by direct probe instrumentation' do
    root = File.expand_path('../../..', __dir__)
    entries = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |entry|
      entry.empty? || entry.start_with?('#')
    end
    source = entries.map { |entry| File.read(File.join(root, 'websieve', entry)) }.join("\n")

    expect(source.rstrip).to end_with('})(window);')
  end

  it 'does not publish extraction options through a page-owned global API' do
    with_url_page('https://bulletin.example/private', hostile_global_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      markdown = described_class.new.extract(page).fetch('markdown')

      expect(markdown).to include('Private extraction bulletin', 'The council published', 'Residents can visit')
      expect(page.evaluate('window.capturedExtractionOptions')).to eq([])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps extraction private after script-tag injection times out' do
    with_url_page('https://bulletin.example/fallback', hostile_global_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      fallback_page = Object.new
      fallback_page.define_singleton_method(:add_script_tag) { |**| raise Ferrum::TimeoutError }
      fallback_page.define_singleton_method(:evaluate) { |script| page.evaluate(script) }

      result = described_class.new(reader_mode: false).extract(fallback_page)

      expect(result.fetch('markdown')).to include('Private extraction bulletin', 'Residents can visit')
      expect(result.fetch('readerMode')).to be(false)
      expect(page.evaluate('window.capturedExtractionOptions')).to eq([])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'publishes the compatibility API when the bundle is injected as a script' do
    html = <<~HTML
      <html><head><title>Standalone extraction bulletin</title>
      <script>
        window.deliveredStandaloneApis = [];
        window.__fetchUtilDeliverExtractApi = function(api) { window.deliveredStandaloneApis.push(api); };
        window.__fetchUtilPrivateExtraction = true;
        Object.defineProperty(Document.prototype, 'currentScript', {
          configurable: true,
          get: function() { return null; }
        });
      </script></head><body><article>
        <h1>Standalone extraction bulletin</h1>
        <p>A complete public article remains available to direct browser integrations.</p>
        <p>The compatibility API should return both visible paragraphs without calling hostile control globals.</p>
      </article></body></html>
    HTML

    with_url_page('https://bulletin.example/standalone', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      asset_root = File.expand_path('../../../lib/fetch_util/assets', __dir__)
      FetchUtil::Extractor::INLINE_ASSET_PATHS.each do |relative_path|
        page.add_script_tag(path: File.join(asset_root, relative_path))
      end
      result = page.evaluate('window.FetchUtilExtract.extract({ reader_mode: true })')

      expect(result.fetch('markdown')).to include('Standalone extraction bulletin', 'compatibility API')
      expect(result.fetch('readerMode')).to be(true)
      expect(page.evaluate('window.deliveredStandaloneApis')).to eq([])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
