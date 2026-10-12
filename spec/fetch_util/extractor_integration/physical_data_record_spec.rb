# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil physical current data records' do
  include_context 'extractor integration helpers'

  def record_page(body, declaration: nil)
    declaration ||= {
      '@context' => 'https://schema.org', '@type' => 'DataRecord',
      'url' => 'https://publication.example.test/record/R42',
      'mainEntity' => {
        '@type' => 'BioChemEntity', 'identifier' => 'R42', 'name' => 'Alpha reference entity',
        'url' => 'https://publication.example.test/record/R42', 'hasRepresentation' => 'JSON_ONLY_SEQUENCE'
      }
    }
    <<~HTML
      <html><head><title>Reference directory</title><script type="application/ld+json">#{JSON.generate(declaration)}</script>
      <meta property="article:published_time" content="1990-01-01"></head><body>
      <nav><p>Foreign global navigation dated 1990-01-01.</p></nav><main><h1>R42 · ALPHA</h1>
      <p>Alpha reference entity</p>#{body}</main><footer>Foreign footer</footer></body></html>
    HTML
  end

  def record_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', 'window.hasPhysicalRecord = function() { return !!physicalDataRecordContext(); }; })(window);'
    )
  end

  it 'retains all physical tables, descriptions, sequences and references without rendering JSON-only material' do
    sections = (1..140).map do |number|
      <<~HTML
        <section><h2>Record section #{number}</h2><p>Complete source explanation #{number}.</p>
        <table><tr><th>Source field #{number}</th><td>Physical value #{number}</td></tr></table>
        <p><a href="/references/#{number}">Published reference #{number}</a></p></section>
      HTML
    end.join
    body = "#{sections}<h2>Sequence</h2><pre>SOURCE_OBSERVED_SEQUENCE</pre><p hidden>Hidden record value.</p>"
    extract_from_url('https://publication.example.test/record/R42', record_page(body)) do |payload|
      (1..140).each do |number|
        expect(payload['html']).to include("Record section #{number}", "Physical value #{number}", "/references/#{number}")
        expect(payload['markdown']).to include("Record section #{number}", "Physical value #{number}", "/references/#{number}")
      end
      expect(payload['title']).to eq('R42 · ALPHA')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['readerMode']).to be(false)
      expect(payload['html']).to include('SOURCE_OBSERVED_SEQUENCE')
      expect(payload['markdown']).to include('SOURCE_OBSERVED_SEQUENCE')
      expect(payload['html']).not_to include('JSON_ONLY_SEQUENCE', 'Hidden record value', 'Foreign global navigation', 'Foreign footer')
      expect(payload['markdown']).not_to include('JSON_ONLY_SEQUENCE', 'Hidden record value', 'Foreign global navigation', 'Foreign footer')
    end
  end

  it 'declines foreign, ambiguous, hidden and JSON-only primary record identities' do
    body = '<h2>Source fields</h2><table><tr><td>Source field</td><td>Source value</td></tr></table>'
    valid = record_page(body)
    cases = [
      valid.sub('"url":"https://publication.example.test/record/R42"', '"url":"https://publication.example.test/record/foreign"'),
      valid.sub('<main>', '<main hidden>'),
      valid.sub('<h1>R42 · ALPHA</h1>', '<h1>Other primary identity</h1>'),
      valid.sub('<p>Alpha reference entity</p>', '<p hidden>Alpha reference entity</p>'),
      valid.sub('</main>', '</main><main><h1>Other record</h1></main>'),
      valid.sub('<h1>R42 · ALPHA</h1>', '<h1>R42 · ALPHA</h1><h1>R42 · OTHER</h1>'),
      valid.sub('<p>Alpha reference entity</p>', ''),
      valid.sub('"@type":"BioChemEntity"', '"@type":"NewsArticle"'),
      valid.sub('"@type":"DataRecord"', '"@type":"WebPage"'),
      valid.sub('"@type":"DataRecord"', '"@type":"DataRecord","creator":{"name":"Declared creator"}')
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/record/R42', html) do |page|
        page.add_script_tag(content: record_source)
        expect(page.evaluate('hasPhysicalRecord()')).to be(false)
      end
    end
  end

  it 'keeps record reference hierarchies and source-bound provenance labels in both forms' do
    body = <<~HTML
      <h2>Reference fields</h2><table><tr><th>Source field</th><td>Observed value
      <button type="button" aria-expanded="false" aria-controls="reference-detail"><span>Source:Public repository</span></button>
      <div id="reference-detail"></div></td></tr></table>
      <ul><li><div><a translate="no" href="/database?query=(name:ReferenceIndex)&amp;direct">Reference index</a></div>
      <div><ul><li><a href="https://resources.example.test/identifier/R42">SOURCE-R42</a></li></ul></div></li></ul>
      <p><a href="/record/R42/references">Publications</a></p>
      <p data-fetchutil-record-reference-slot="0">An authored source note remains complete.</p>
      <div class="button-group"><button disabled>Compare entries</button><button disabled>Add entries</button>
      <a href="/records?query=identifier:R42 OR identifier:R43">View all</a></div>
    HTML
    body += (1..5).map do |index|
      "<ul><li>Observed annotation #{index}<button aria-expanded='false' aria-controls='evidence-#{index}'>1 publication</button>" \
        "<div id='evidence-#{index}'></div></li></ul>"
    end.join
    extract_from_url('https://publication.example.test/record/R42', record_page(body)) do |payload|
      %w[html markdown].each do |format|
        expect(payload[format]).to include('Source:Public repository', 'Reference index', 'SOURCE-R42', 'Publications')
        expect(payload[format]).to include('https://resources.example.test/identifier/R42', '/record/R42/references')
        expect(payload[format]).to include('View all', '/records?query=identifier:R42%20OR%20identifier:R43')
        expect(payload[format]).to include('An authored source note remains complete.')
        expect(payload[format].scan('1 publication').size).to eq(5)
      end
    end
  end

  it 'does not request source visibility for a page without the typed current-record prerequisite' do
    html = record_page('<h2>Fields</h2><dl><dt>Field</dt><dd>Value</dd></dl>').sub('"@type":"DataRecord"', '"@type":"WebPage"')
    with_url_page('https://publication.example.test/record/R42', html) do |page|
      page.add_script_tag(content: record_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = window.getComputedStyle;
          let calls = 0;
          window.getComputedStyle = function() { calls++; return original.apply(this, arguments); };
          try { return { owned: hasPhysicalRecord(), calls: calls }; }
          finally { window.getComputedStyle = original; }
        })()
      JAVASCRIPT
      expect(result).to eq('owned' => false, 'calls' => 0)
    end
  end
end
