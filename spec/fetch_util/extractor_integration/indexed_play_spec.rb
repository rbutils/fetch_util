# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil complete indexed plays' do
  include_context 'extractor integration helpers'

  def play_page(text)
    <<~HTML
      <html><head><title>The Example - Entire Play | Published edition</title>
      <link rel="canonical" href="https://publication.example.test/play">
      <meta property="og:title" content="The Example - Entire Play">
      <meta property="article:published_time" content="1990-01-01"></head><body>
      <nav>Foreign navigation</nav><main><h1>The Example - Entire Play</h1>
      <p>A complete source-owned synopsis remains available.</p><section class="reading-layout_sidebar-open">
      <aside><a href='/navigation/1'>Sidebar item 1</a><a href='/navigation/2'>Sidebar item 2</a>
      <a href='/navigation/3'>Sidebar item 3</a></aside>
      <div xmlns:html="http://www.w3.org/1999/xhtml">#{text}</div></section></main>
      <footer>Foreign footer</footer></body></html>
    HTML
  end

  def play_text(lines_per_scene = 30)
    (1..2).map do |act|
      scenes = (1..2).map do |scene|
        lines = (1..lines_per_scene).map do |line|
          "<span id='line-#{act}.#{scene}.#{line}'></span>Spoken line #{act}.#{scene}.#{line}." \
            "<a href='/line/#{act}/#{scene}/#{line}'>Published reference</a><br>" \
            '<span>Let the published words remain.</span><br>'
        end.join
        "<div id='line-#{act}.#{scene}.0'><div>⌜Scene #{scene}⌝</div>" \
          "<span>Actor enters and speaks.</span><br>#{lines}</div>"
      end.join
      "<div><div>⟨ACT #{act}⟩</div>#{scenes}</div>"
    end.join
  end

  def play_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);', <<~JAVASCRIPT
        window.hasIndexedPlay = function() { return !!physicalIndexedPlayContext(); };
        window.indexedAttributionProbe = function() {
          var original = readerSourceOwnedBylineForContent, calls = 0;
          readerSourceOwnedBylineForContent = function() { calls++; return original.apply(this, arguments); };
          try { return { result: fetchUtilExtractApi.extract({}), calls: calls }; }
          finally { readerSourceOwnedBylineForContent = original; }
        };
        })(window);
      JAVASCRIPT
    )
  end

  it 'retains all indexed dialogue, repetitions, stage directions, references and editorial symbols' do
    html = play_page("#{play_text}<p hidden>Hidden example stays hidden.</p>")
    extract_from_url('https://publication.example.test/play', html) do |payload|
      %w[html markdown].each do |format|
        (1..2).each do |act|
          (1..2).each do |scene|
            (1..30).each do |line|
              expect(payload[format]).to include("Spoken line #{act}.#{scene}.#{line}.", "/line/#{act}/#{scene}/#{line}")
            end
          end
        end
        expect(payload[format].scan('Let the published words remain.').size).to eq(120)
        expect(payload[format]).to include('A complete source-owned synopsis remains available.', 'Actor enters and speaks.', '⌜Scene 1⌝', '⟨ACT 2⟩')
        expect(payload[format]).not_to include('Foreign navigation', 'Foreign footer', 'Hidden example stays hidden.', 'Sidebar item')
      end
      expect(payload['title']).to eq('The Example - Entire Play')
      expect(payload['contentType']).to eq('article')
      expect(payload['readerMode']).to be(false)
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'preserves actual published replies beside the play without treating its voices as a thread' do
    html = play_page(play_text(2)).sub('</main>', <<~HTML)
      <section class="comments"><article class="comment" data-author="Reader">
      <span class="comment-author">Reader</span><p>An actual published reply remains available.</p></article></section></main>
    HTML
    extract_from_url('https://publication.example.test/play', html) do |payload|
      %w[html markdown].each do |format|
        expect(payload[format]).to include('Spoken line 1.1.1.', 'Spoken line 2.2.2.', 'An actual published reply remains available.')
      end
      expect(payload['contentType']).to eq('article')
    end
  end

  it 'retains work-owned headed resources while removing unrelated promotion and hidden cards' do
    reference = <<~HTML
      <div class="resource-cta"><h3>Teaching The Example</h3>
      <img src="https://publication.example.test/guide-cover.png" alt="The Example teaching guide cover">
      <p><a href="https://publication.example.test/guide">Get the published guide</a></p></div>
    HTML
    foreign = reference.sub('Teaching The Example', 'Foreign promotion').sub('/guide">', '/foreign-guide">')
    hidden = reference.sub('resource-cta', 'resource-cta" hidden="hidden').sub('/guide">', '/hidden-guide">')
    html = play_page(play_text(2)).sub('</main>', "#{reference}#{foreign}#{hidden}</main>")
    extract_from_url('https://publication.example.test/play', html) do |payload|
      %w[html markdown].each do |format|
        expect(payload[format]).to include('Teaching The Example', 'Get the published guide', '/guide-cover.png', '/guide')
        expect(payload[format]).not_to include('Foreign promotion', '/foreign-guide', '/hidden-guide')
      end
    end
  end

  it 'declines foreign, reporting, hidden, conflicting and incomplete physical indexing' do
    valid = play_page(play_text(2))
    cases = [
      valid.sub('/play">', '/foreign">'),
      valid.sub('</head>', '<meta property="og:type" content="article"></head>'),
      valid.sub('<main>', '<main hidden>'),
      valid.sub('<h1>The Example - Entire Play</h1>', '<h1>Other work - Entire Play</h1>'),
      valid.sub('</main>', '</main><main><h1>The Example - Entire Play</h1></main>'),
      valid.sub('http://www.w3.org/1999/xhtml', 'https://example.test/unrelated'),
      valid.sub("id='line-1.1.0'", "id='line-1.3.0'"),
      valid.sub("id='line-2.1.0'", "id='line-2.1.0' hidden"),
      valid.sub("id='line-1.2.1'", "id='line-1.1.1'"),
      valid.sub("id='line-2.2.0'", "id='unindexed-scene'")
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/play', html) do |page|
        page.add_script_tag(content: play_source)
        expect(page.evaluate('hasIndexedPlay()')).to be(false)
      end
    end
  end

  it 'does not request visibility on a page without the complete-play title prerequisite' do
    html = play_page(play_text(2)).sub('The Example - Entire Play | Published edition', 'Ordinary page')
    with_url_page('https://publication.example.test/play', html) do |page|
      page.add_script_tag(content: play_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const original = window.getComputedStyle;
          let calls = 0;
          window.getComputedStyle = function() { calls++; return original.apply(this, arguments); };
          try { return { owned: hasIndexedPlay(), calls: calls }; }
          finally { window.getComputedStyle = original; }
        })()
      JAVASCRIPT
      expect(result).to eq('owned' => false, 'calls' => 0)
    end
  end

  it 'does not search unrelated attribution after proving an unattributed complete work' do
    with_url_page('https://publication.example.test/play', play_page(play_text(2))) do |page|
      page.add_script_tag(content: play_source)
      result = page.evaluate('indexedAttributionProbe()')
      expect(result['calls']).to eq(0)
      expect(result['result']['byline']).to be_nil
      expect(result['result']['publishedTime']).to be_nil
      expect(result['result']['markdown']).to include('Spoken line 2.2.2.')
    end
  end
end
