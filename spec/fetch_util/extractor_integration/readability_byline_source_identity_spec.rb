# frozen_string_literal: true

require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil reparsed paragraph attribution ownership' do
  include_context 'extractor integration helpers'

  def reader_credit_page(credit_tag: 'span', hidden: false)
    primary_records = (1..4).map do |section|
      stories = (1..3).map do |record|
        "<article><h3><a href='/reports/#{section}/#{record}/'>Independent report #{section}-#{record}</a></h3>" \
          "<p>The complete independently authored reporting paragraph for section #{section} record #{record} remains visible.</p></article>"
      end.join
      "<section><h2>Reporting section #{section}</h2>#{stories}</section>"
    end.join
    records = [[307, 'Ari Lens'], [308, 'Bo Frame']].map do |number, name|
      <<~HTML
        <section class="publication-record"><div class="cover-column">
          <a href="/issues/issue-#{number}/"><img src="/assets/cover-#{number}.jpg" alt="Publication number #{number}"></a>
          <#{credit_tag} class="publication-author"#{hidden ? ' style="display:none"' : ""}>Cover | #{name}</#{credit_tag}>
          <button><a href="/issues/">All publications</a></button>
        </div><div class="contents-column"><h1>Issue #{number}</h1>
          <h2><a href="/issues/issue-#{number}/river/">River report #{number}</a></h2>
          <p>Complete reporting about the independent river project in publication #{number} stays in its own paragraph.</p>
          <h2><a href="/issues/issue-#{number}/forest/">Forest report #{number}</a></h2>
          <p>Complete reporting about the independent forest project in publication #{number} stays in its own paragraph.</p>
        </div></section>
      HTML
    end.join
    <<~HTML
      <!doctype html><html><head><title>Publication catalogue</title>
      <link rel="canonical" href="https://publication.example.test/"></head>
      <body><main><h1>Publication catalogue</h1>#{primary_records}#{records}
      <pre>first_code()

      last_code()</pre></main></body></html>
    HTML
  end

  [['inline_credit', 'span', false], ['paragraph_credit', 'p', false], ['hidden_credit', 'span', true]].each do |name, tag, hidden|
    it "retains local #{name} material without borrowing its page attribution" do
      with_url_page('https://publication.example.test/', reader_credit_page(credit_tag: tag, hidden: hidden)) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract_payload(page, reader_mode: true)
        parser = "import sys\nfrom markdown_it import MarkdownIt\nprint(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
        parsed, error, status = Open3.capture3('python', '-c', parser, stdin_data: payload.fetch('markdown'))
        raise "independent Markdown parser failed: #{error}" unless status.success?

        native = Nokogiri::HTML5.fragment(payload.fetch('html'))
        markdown = Nokogiri::HTML5.fragment(parsed)
        credits = ['Cover | Ari Lens', 'Cover | Bo Frame']
        occurrences = ->(text) { credits.map { |credit| text.scan(Regexp.new(Regexp.escape(credit))).length } }
        expected = hidden ? [0, 0] : [1, 1]
        expect(occurrences.call(native.text)).to eq(expected)
        expect(occurrences.call(markdown.text)).to eq(expected)
        expect(markdown.css('pre').map { |node| node.text.delete_suffix("\n") }).to include("first_code()\n\nlast_code()")
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
        expect(payload['byline']).to be_nil
      end
    end
  end

  def paragraph_author_page(name:, declared: false, profile: false)
    author = profile ? "<a rel='author' href='/authors/rae-reader/'>#{name}</a>" : name
    meta = declared ? "<meta name='author' content='#{name}'>" : ''
    <<~HTML
      <!doctype html><html><head><title>Current reporting</title>#{meta}
      <link rel="canonical" href="https://publication.example.test/current-report/"></head><body>
      <main><article><header><h1>Current reporting</h1><p class="author">#{author}</p></header>
      <p>The complete introductory reporting explains how the local river project was investigated with independent source documents and interviews.</p>
      <p>The complete second paragraph retains its <a href="/sources/river/">declared source reference</a> and its own reporting context.</p>
      <pre>first_code()

      last_code()</pre>
      <p>The complete final paragraph records the outcome and the remaining reporting questions in their original order.</p>
      </article></main></body></html>
    HTML
  end

  [
    ['an explicit publisher declaration', { name: 'Rae Reader', declared: true }],
    ['a physically owned article-header paragraph', { name: 'Rae Reader' }],
    ['a physically owned author-profile reference', { name: 'Rae Reader', profile: true }]
  ].each do |label, options|
    it "retains #{label} and the complete reporting material" do
      with_url_page('https://publication.example.test/current-report/', paragraph_author_page(**options)) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract_payload(page, reader_mode: true)
        expect(payload['byline']).to eq('Rae Reader')
        expect(payload['title']).to eq('Current reporting')
        expect(payload['publishedTime']).to be_nil
        expect(payload.fetch('markdown')).to include(
          'complete introductory reporting', 'complete second paragraph', 'complete final paragraph',
          'https://publication.example.test/sources/river/', "first_code()\n\nlast_code()"
        )
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end

  def reader_byline_identity_probe
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    closing = '})(window);'
    raise 'ambiguous private probe boundary' unless source.scan(closing).length == 1

    source.sub(closing, <<~JAVASCRIPT)
      global.probeReaderBylineIdentity = function(mode) {
        var before = document.body.outerHTML;
        var clone = safeReadableDocumentClone(), sourceClones = new Map();
        pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, sourceClones);
        var marker = markReadabilityExcerptSources(clone);
        var identities = markReadabilitySourceNodeProvenance(clone, sourceClones, marker);
        var ownSource = document.querySelector('[data-own]'), foreignSource = document.querySelector('[data-foreign]');
        if (mode === 'duplicate-token') {
          sourceClones.get(foreignSource).setAttribute('data-fetchutil-reader-source-paragraph',
            sourceClones.get(ownSource).getAttribute('data-fetchutil-reader-source-paragraph'));
        }
        var resolve = inferredBylineSourceResolver(sourceClones, identities, marker);
        var reparsed = document.implementation.createHTMLDocument('');
        reparsed.body.innerHTML = clone.body.innerHTML;
        var own = reparsed.querySelector('[data-own]'), foreign = reparsed.querySelector('[data-foreign]');
        if (mode === 'changed-text') foreign.textContent += ' different';
        if (mode === 'changed-id') foreign.id += '-different';
        if (mode === 'changed-token') foreign.setAttribute('data-fetchutil-reader-source-paragraph', marker + ':unknown');
        if (mode === 'changed-tag') {
          var replacement = reparsed.createElement('div');
          Array.from(foreign.attributes).forEach(function(attribute) { replacement.setAttribute(attribute.name, attribute.value); });
          replacement.textContent = foreign.textContent;
          foreign.replaceWith(replacement);
          foreign = replacement;
        }
        var unmarked = reparsed.createElement('p');
        unmarked.className = 'author';
        unmarked.textContent = 'Rae Reader';
        return {ownMapped: resolve(own) === ownSource, foreignMapped: resolve(foreign) === foreignSource,
          ownEligible: inferredArticleBylineNode(resolve(own)), foreignEligible: inferredArticleBylineNode(resolve(foreign)),
          foreignRejected: resolve(foreign) === null, ownRejected: resolve(own) === null,
          unmarkedUnchanged: resolve(unmarked) === unmarked,
          directSourceUnchanged: resolve(sourceClones.get(ownSource)) === ownSource,
          unchanged: before === document.body.outerHTML};
      };
      })(window);
    JAVASCRIPT
  end

  def with_reader_byline_identity_page
    html = <<~HTML
      <title>Current reporting</title><main>
      <article><header><h1>Current reporting</h1><p data-own id="shared" class="author">Rae Reader</p></header>
      <p>The complete independently authored reporting remains in this source article.</p></article>
      <section><div><a href="/issues/issue-307/"><img src="/cover.jpg" alt="Issue 307"></a>
      <p data-foreign id="shared" class="author">Rae Reader</p></div>
      <div><h1>Issue 307</h1><h2><a href="/issues/issue-307/river/">River report</a></h2>
      <p>The independent publication keeps its own complete reporting and credit.</p></div></section></main>
    HTML
    with_url_page('https://publication.example.test/current-report/', html) do |page|
      page.add_script_tag(content: reader_byline_identity_probe)
      yield page
    end
  end

  it 'preserves distinct physical ownership across reparsing with equal names and duplicate source ids' do
    with_reader_byline_identity_page do |page|
      value = page.evaluate('probeReaderBylineIdentity("exact")')
      expect(value.values_at('ownMapped', 'foreignMapped', 'ownEligible', 'foreignEligible', 'unchanged')).to eq([true, true, true, false, true])
    end
  end

  it 'rejects changed private paragraph text, id, token or tag without borrowing its clone context' do
    with_reader_byline_identity_page do |page|
      %w[changed-text changed-id changed-token changed-tag].each do |mode|
        value = page.evaluate("probeReaderBylineIdentity(#{mode.to_json})")
        expect(value.values_at('foreignRejected', 'foreignEligible', 'ownMapped', 'ownEligible', 'unchanged')).to eq([true, false, true, true, true])
      end
    end
  end

  it 'rejects ambiguous private tokens while preserving the source document' do
    with_reader_byline_identity_page do |page|
      value = page.evaluate('probeReaderBylineIdentity("duplicate-token")')
      expect(value.values_at('ownRejected', 'foreignRejected', 'ownEligible', 'foreignEligible', 'unchanged')).to eq([true, true, false, false, true])
    end
  end

  it 'preserves the existing direct-source and unmarked-node paths' do
    with_reader_byline_identity_page do |page|
      value = page.evaluate('probeReaderBylineIdentity("exact")')
      expect(value.values_at('directSourceUnchanged', 'unmarkedUnchanged', 'unchanged')).to eq([true, true, true])
    end
  end
end
