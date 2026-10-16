# frozen_string_literal: true

require 'date'

RSpec.describe 'FetchUtil complete dated reference indexes' do
  include_context 'extractor integration helpers'

  def dated_reference_page(count = 603, shared_notes: false)
    records = count.times.map do |index|
      number = index + 1
      date = (Date.new(2026, 12, 31) - index).strftime('%b %d, %Y')
      literal = number == 1 ? '<pre><code>complete &lt;source&gt; value</code></pre><table><tr><td>Published cell</td></tr></table>' : ''
      shared = shared_notes ? '<p>Repeated authored source context stays with this dated record.</p>' : ''
      <<~HTML
        <h2>#{date}</h2><h3>Published topic #{number}</h3><ul><li>
        <a href="/materials/#{number}">Curated material #{number}</a>
        <p>Complete authored description #{number} discusses comments, privacy and references.</p>
        <a href="https://resources.example.test/evidence/#{number}">Source evidence #{number}</a>#{literal}#{shared}</li></ul>
      HTML
    end.join
    <<~HTML
      <html><head><title>Resource Directory | Publication</title>
      <meta property="og:title" content="Resource Directory"><meta property="og:type" content="summary">
      <meta property="og:url" content="https://publication.example.test/changes/resources/">
      <meta name="author" content="Foreign global author"><meta name="date" content="2020-01-02">
      </head><body><button type="button" aria-label="Toggle Dark Mode">Appearance</button><main>
      <h1>Resource Directory</h1><p>An authored introduction to this complete curated reference collection.</p>
      #{records}<ul><li></li></ul></main></body></html>
    HTML
  end

  def dated_reference_probe_source
    root = File.expand_path('../../..', __dir__)
    files = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |path| path.empty? || path.start_with?('#') }
    files.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub('})(window);', <<~JAVASCRIPT)
      global.datedReferenceOwned = function() { return !!datedReferenceIndexContext(); };
      global.datedReferenceDate = datedReferenceHeadingValue;
      global.datedReferenceLegacyLegal = function() { return legalStatuteArticleContent(null, document.querySelector("main").textContent); };
      global.datedReferenceSocialRead = function() {
        var content = datedReferenceIndexContent(collectMetadata());
        var original = listContent;
        var calls = 0;
        listContent = function() { calls++; return {contentType:"list",listExtraction:{items:[]}}; };
        try {
          var result = applySocialContentType(content, {title:"Resource Directory"});
          return { calls:calls, same:result === content, type:result.contentType };
        } finally { listContent = original; }
      };
      })(window);
    JAVASCRIPT
  end

  it 'retains every visible record, date, resource and literal in its physical source order' do
    extract_from_url('https://publication.example.test/changes/resources/', dated_reference_page) do |payload|
      expect(payload.keys).to include('html'), "Extraction returned #{payload.inspect}"
      (1..603).each do |number|
        expect(payload['html']).to include("Curated material #{number}", "description #{number}", "/evidence/#{number}")
        expect(payload['markdown']).to include("Curated material #{number}", "description #{number}", "/evidence/#{number}")
      end
      positions = (1..603).map { |number| payload['markdown'].index("Curated material #{number}]") }
      expect(positions).to eq(positions.sort)
      expect(payload['markdown']).to include('complete <source> value', 'Published cell', 'An authored introduction')
      expect(payload['title']).to eq('Resource Directory')
      expect(payload['contentType']).to eq('list')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['markdown']).not_to include('Foreign global author', '2020-01-02', 'Appearance')
    end
  end

  it 'requires complete current physical ownership and remains fresh after source changes' do
    with_url_page('https://publication.example.test/changes/resources/', dated_reference_page(3)) do |page|
      page.execute(dated_reference_probe_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (function() {
          var source = document.documentElement.outerHTML;
          var head = document.head.innerHTML;
          var body = document.body.innerHTML;
          var initial = window.datedReferenceOwned();
          var changes = [
            function() { document.querySelector("meta[property='og:url']").content = "https://foreign.example.test/changes/resources/"; },
            function() { document.querySelector("meta[property='og:type']").content = "article"; },
            function() { document.querySelector("meta[property='og:title']").content = "Foreign title"; },
            function() { document.querySelector("main").hidden = true; },
            function() { document.body.appendChild(document.createElement("main")); },
            function() { var p = document.createElement("p"); p.textContent = "Independent published reporting outside the index."; document.body.appendChild(p); },
            function() { document.querySelector("h2").textContent = "Not a calendar heading"; },
            function() { document.querySelectorAll("h2")[1].textContent = document.querySelector("h2").textContent; },
            function() { document.querySelector("h3").remove(); },
            function() { document.querySelector("ul").innerHTML = "<li></li>"; },
            function() { document.querySelector("main").appendChild(document.createElement("form")); },
            function() { document.querySelector("main").appendChild(document.createElement("article")); },
            function() { document.querySelector("main").appendChild(document.querySelector("h1")); }
          ];
          var declines = changes.map(function(change) {
            change();
            var declined = !window.datedReferenceOwned();
            document.head.innerHTML = head;
            document.body.innerHTML = body;
            return declined && window.datedReferenceOwned();
          });
          return { initial: initial, declines: declines, unchanged: source === document.documentElement.outerHTML };
        })()
      JAVASCRIPT
      expect(result).to eq('initial' => true, 'declines' => Array.new(13, true), 'unchanged' => true)
    end
  end

  it 'accepts complete calendar values without inferring dates from titles or malformed days' do
    with_url_page('https://publication.example.test/changes/resources/', dated_reference_page(2)) do |page|
      page.execute(dated_reference_probe_source)
      values = page.evaluate(<<~JAVASCRIPT)
        (function() {
          return {
            leap: window.datedReferenceDate("2024-02-29") === window.datedReferenceDate("February 29, 2024"),
            invalid: ["2023-02-29", "2024-02-31", "Oct 12, 2026 updates", "Oct 2026", "yesterday"].map(function(value) {
              return window.datedReferenceDate(value) === null;
            })
          };
        })()
      JAVASCRIPT
      expect(values).to eq('leap' => true, 'invalid' => Array.new(5, true))
    end
  end

  it 'keeps repeated authored context at every separately dated source occurrence' do
    extract_from_url('https://publication.example.test/changes/resources/', dated_reference_page(5, shared_notes: true)) do |payload|
      note = 'Repeated authored source context stays with this dated record.'
      expect(payload['html'].scan(note).length).to eq(5)
      expect(payload['markdown'].scan(note).length).to eq(5)
      dates = 5.times.map { |index| (Date.new(2026, 12, 31) - index).strftime('%b %d, %Y') }
      positions = dates.map { |date| payload['markdown'].index(date) }
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'retains a proved reference collection when its resources discuss codes and legal sections' do
    introduction = 'Government code and reference tools stay in this authored collection introduction.'
    html = dated_reference_page(24).sub('An authored introduction to this complete curated reference collection.', introduction)
    html = html.gsub(/Complete authored description (\d+) discusses comments, privacy and references\./) do
      number = Regexp.last_match(1)
      "Article #{number}. Chapter I. Curated reference #{number} discusses legal provisions, documentation and code examples. " \
        'The description retains its complete explanation of public interfaces, source relationships, usage examples and published references.'
    end
    with_url_page('https://publication.example.test/changes/resources/', html) do |page|
      page.execute(dated_reference_probe_source)
      expect(page.evaluate('window.datedReferenceLegacyLegal()')).to be(true)
      payload = FetchUtil::Extractor.new(reader_mode: true).extract(page)
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include(introduction)
      (1..24).each do |number|
        expect(payload['markdown']).to include("Curated material #{number}", "Curated reference #{number}", "/evidence/#{number}")
      end
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'does not rebuild a positively owned reference index for weaker social-feed inference' do
    with_url_page('https://publication.example.test/changes/resources/', dated_reference_page(4)) do |page|
      page.execute(dated_reference_probe_source)
      source = page.evaluate('document.body.outerHTML')
      expect(page.evaluate('window.datedReferenceSocialRead()')).to eq('calls' => 0, 'same' => true, 'type' => 'list')
      expect(page.evaluate('document.body.outerHTML')).to eq(source)
    end
  end

  it 'retains topic heading levels when materialized phrasing paragraphs wrap their linked labels' do
    html = dated_reference_page(3).gsub(%r{<h3>Published topic (\d+)</h3>}) do
      number = Regexp.last_match(1)
      %(<h3 id="topic-#{number}"><p><a href="/topics/#{number}"><code>Published topic #{number}</code></a></p></h3>)
    end
    with_url_page('https://publication.example.test/changes/resources/', html) do |page|
      source = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: true).extract(page)
      (1..3).each do |number|
        expect(payload['html']).to include(%(<h3 id="topic-#{number}"><p>))
        expect(payload['markdown'].lines.map(&:chomp)).to include(
          "### [`Published topic #{number}`](https://publication.example.test/topics/#{number})"
        )
        expect(payload['markdown']).to include("/materials/#{number}", "/evidence/#{number}")
      end
      expect(payload['contentType']).to eq('list')
      expect(page.evaluate('document.body.outerHTML')).to eq(source)
    end
  end
end
