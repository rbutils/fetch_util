# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil physical numbered instruments' do
  include_context 'extractor integration helpers'

  def instrument_page(body)
    <<~HTML
      <html><head><title>Example Covenant text | Public reference</title>
      <meta property="og:title" content="Example Covenant text"><meta property="og:type" content="website">
      <link rel="canonical" href="https://publication.example.test/instrument">
      <meta property="article:published_time" content="1990-01-01"></head><body>
      <nav>Foreign navigation</nav><main><article><h1>Example Covenant text</h1>
      <p>Complete preamble describing the published instrument.</p><div>#{body}</div></article></main>
      <footer>Foreign footer</footer></body></html>
    HTML
  end

  def instrument_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', 'window.hasPhysicalInstrument = function() { return !!physicalNumberedInstrumentContext(); }; })(window);'
    )
  end

  it 'retains every physical provision, repeated wording, resource and preamble without borrowing publication metadata' do
    body = (1..160).map do |number|
      "<h5>Article #{number}</h5><p>Complete physical provision #{number}.</p>" \
        "<p>Every party retains the published obligation.</p><p><a href='/sources/#{number}'>Reference #{number}</a></p>"
    end.join
    body += '<p hidden>Hidden example remains hidden.</p>'
    extract_from_url('https://publication.example.test/instrument', instrument_page(body)) do |payload|
      %w[html markdown].each do |format|
        (1..160).each do |number|
          expect(payload[format]).to include("Article #{number}", "Complete physical provision #{number}", "/sources/#{number}")
        end
        expect(payload[format]).to include('Complete preamble describing the published instrument.')
        expect(payload[format].scan('Every party retains the published obligation.').size).to eq(160)
        expect(payload[format]).not_to include('Foreign navigation', 'Foreign footer', 'Hidden example remains hidden.')
      end
      expect(payload['title']).to eq('Example Covenant text')
      expect(payload['contentType']).to eq('article')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'preserves actual published replies beside the primary instrument without classifying provisions as a thread' do
    body = '<h5>Article 1</h5><p>First physical provision.</p><h5>Article 2</h5><p>Second physical provision.</p>'
    html = instrument_page(body).sub('</main>', <<~HTML)
      <section class="comments"><article class="comment" data-author="Reader">
      <span class="comment-author">Reader</span><p>An actual published reply remains available.</p></article></section></main>
    HTML
    extract_from_url('https://publication.example.test/instrument', html) do |payload|
      %w[html markdown].each do |format|
        expect(payload[format]).to include('First physical provision.', 'Second physical provision.', 'An actual published reply remains available.')
      end
      expect(payload['contentType']).to eq('article')
    end
  end

  it 'declines foreign, reporting, hidden, ambiguous and conflicting physical instrument identities' do
    body = '<h5>Article 1</h5><p>First provision.</p><h5>Article 2</h5><p>Second provision.</p>'
    valid = instrument_page(body)
    cases = [
      valid.sub('content="website"', 'content="article"'),
      valid.sub('/instrument">', '/foreign">'),
      valid.sub('<main>', '<main hidden>'),
      valid.sub('<h1>Example Covenant text</h1>', '<h1>Other instrument</h1>'),
      valid.sub('</main>', '</main><main><h1>Example Covenant text</h1></main>'),
      valid.sub('Article 2', 'Article 3'),
      valid.sub('<h5>Article 1</h5>', '<h5 hidden>Article 1</h5>'),
      valid.sub('Article 2', 'Article 1'),
      valid.sub('</article>', '<article><h1>Another document</h1></article></article>')
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/instrument', html) do |page|
        page.add_script_tag(content: instrument_source)
        expect(page.evaluate('hasPhysicalInstrument()')).to be(false)
      end
    end
  end

  it 'does not observe source visibility without the declared instrument-title prerequisite' do
    html = instrument_page('<h5>Article 1</h5><p>Provision.</p>').sub('Example Covenant text | Public reference', 'Ordinary page')
    with_url_page('https://publication.example.test/instrument', html) do |page|
      page.add_script_tag(content: instrument_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = window.getComputedStyle;
          let calls = 0;
          window.getComputedStyle = function() { calls++; return original.apply(this, arguments); };
          try { return { owned: hasPhysicalInstrument(), calls: calls }; }
          finally { window.getComputedStyle = original; }
        })()
      JAVASCRIPT
      expect(result).to eq('owned' => false, 'calls' => 0)
    end
  end
end
