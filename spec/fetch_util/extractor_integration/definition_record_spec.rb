# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil physical identifier-owned field records' do
  include_context 'extractor integration helpers'

  def definition_record_page(fields)
    <<~HTML
      <html><head><title>inscribed object | Reference collection</title>
      <link rel="canonical" href="https://publication.example.test/collection/object/X_R42">
      <meta property="og:type" content="article"><meta property="og:title" content="inscribed object | Reference collection">
      <meta property="article:published_time" content="1990-01-01"></head><body>
      <nav>Foreign navigation</nav><main><h1>inscribed object</h1><dl>
      <div><dt>Object Type</dt><dd>inscribed object</dd></div>
      <div><dt>Inventory number</dt><dd>R42</dd></div>#{fields}
      </dl></main><footer>Foreign footer</footer></body></html>
    HTML
  end

  def definition_record_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', 'window.hasDefinitionRecord = function() { return !!physicalDefinitionRecordContext({}); }; })(window);'
    )
  end

  it 'retains every physical field, sibling value, curator comment, date and reference in order' do
    fields = (1..180).map do |index|
      <<~HTML
        <div><dt>Physical field #{index}</dt><dd>Complete observed value #{index}</dd>
        <dd><a href="/references/#{index}">Published reference #{index}</a></dd></div>
      HTML
    end.join
    fields += '<div><dt>Curator comments</dt><dd>The inscription discusses services and published comments.</dd></div>'
    fields += '<div><dt>Production date</dt><dd>1901</dd></div><div hidden><dt>Hidden field</dt><dd>Hidden value</dd></div>'
    extract_from_url('https://publication.example.test/collection/object/X_R42', definition_record_page(fields)) do |payload|
      %w[html markdown].each do |format|
        previous = -1
        (1..180).each do |index|
          text = "Complete observed value #{index}"
          current = payload[format].index(text, previous + 1)
          expect(current).not_to be_nil
          expect(payload[format]).to include("Published reference #{index}", "/references/#{index}")
          previous = current
        end
        expect(payload[format]).to include('The inscription discusses services and published comments.', '1901')
        expect(payload[format]).not_to include('Hidden value', 'Foreign navigation', 'Foreign footer')
      end
      expect(payload['title']).to eq('inscribed object')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['readerMode']).to be(false)
      expect(payload['contentType']).to eq('article')
    end
  end

  it 'declines foreign, ambiguous, hidden, incomplete and reporting ownership' do
    valid = definition_record_page('<div><dt>Description</dt><dd>Source description.</dd></div>')
    cases = [
      valid.sub('/collection/object/X_R42"', '/collection/object/X_foreign"'),
      valid.sub('<main>', '<main hidden>'),
      valid.sub('<dl>', '<dl hidden>'),
      valid.sub('<h1>inscribed object</h1>', '<h1>Other identity</h1>'),
      valid.sub('<dd>R42</dd>', '<dd>R43</dd>'),
      valid.sub('<dd>inscribed object</dd>', '<dd>Different object type</dd>'),
      valid.sub('<dt>Inventory number</dt>', '<dt>Unrelated field</dt>'),
      valid.sub('<dd>R42</dd>', '<dd hidden>R42</dd>'),
      valid.sub('</main>', '<dl><dt>Another identity</dt><dd>Foreign value</dd></dl></main>'),
      valid.sub('</main>', '</main><main><h1>Other record</h1></main>'),
      valid.sub('<h1>inscribed object</h1>', '<h1>inscribed object</h1><h1>Other header</h1>'),
      valid.sub('</head>', '<script type="application/ld+json">{"@type":"NewsArticle","headline":"Reporting"}</script></head>'),
      valid.sub('</dl>', '</dl><a rel="author">Published writer</a>')
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/collection/object/X_R42', html) do |page|
        page.add_script_tag(content: definition_record_source)
        expect(page.evaluate('hasDefinitionRecord()')).to be(false)
      end
    end
  end

  it 'does not request source visibility for a URL without the record-route prerequisite' do
    with_url_page('https://publication.example.test/article/unrelated', definition_record_page('')) do |page|
      page.add_script_tag(content: definition_record_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = window.getComputedStyle;
          let calls = 0;
          window.getComputedStyle = function() { calls++; return original.apply(this, arguments); };
          try { return { owned: hasDefinitionRecord(), calls: calls }; }
          finally { window.getComputedStyle = original; }
        })()
      JAVASCRIPT
      expect(result).to eq('owned' => false, 'calls' => 0)
    end
  end
end
