# frozen_string_literal: true

RSpec.describe 'FetchUtil complete materialized manual sections' do
  include_context 'extractor integration helpers'

  def manual_source(body, title: 'Language reference manual')
    <<~HTML
      <html lang="en"><head><title>#{title}</title><meta property="og:title" content="#{title}">
      <meta name="author" content="Unrelated global maintainer"><meta name="date" content="2001-01-01"></head>
      <body><nav><a href="/foreign-navigation">Unrelated navigation</a></nav>#{body}
      <footer>Unrelated site footer</footer></body></html>
    HTML
  end

  def manual_sections
    (1..160).map do |number|
      <<~HTML
        <section id="section-#{number}"><h2>Complete section #{number}<a style="visibility:hidden" href="#section-#{number}">#</a></h2>
        <p>Published instruction #{number} retains every source value and <a href="/references/#{number}">reference #{number}</a>.</p>
        <div class="highlight"><pre>value#{number} = transform(#{number})</pre></div>
        <table><tr><th>Field #{number}</th><th>Value</th></tr><tr><td>source#{number}</td><td>result#{number}</td></tr></table>
        <section hidden><h3>Hidden answer #{number}</h3><pre>hidden#{number}</pre></section></section>
      HTML
    end.join
  end

  it 'retains all ordered article sections, literal examples, tables and references' do
    body = "<article><section><h1>Language reference manual</h1><p>Visible reporting lead.</p>#{manual_sections}</section></article>"
    extract_from_url('https://publication.example.test/reference/manual', manual_source(body)) do |payload|
      (1..160).each do |number|
        %w[html markdown].each do |format|
          expect(payload[format]).to include("Complete section #{number}", "value#{number} = transform(#{number})")
          expect(payload[format]).to include("source#{number}", "result#{number}", "/references/#{number}")
          expect(payload[format]).not_to include("Hidden answer #{number}", "hidden#{number}")
        end
      end
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['excerpt']).to eq('Visible reporting lead.')
      expect(payload['markdown']).not_to include('Unrelated navigation', 'Unrelated site footer')
      order = payload['markdown'].scan(/Complete section (\d+)/).flatten.map(&:to_i)
      expect(order).to eq((1..160).to_a)
    end
  end

  it 'keeps every generated chapter, preface, appendix and authored callout' do
    chapters = (1..120).map do |number|
      <<~HTML
        <div class="chapter"><div class="titlepage"><h2 class="title">Published chapter #{number}</h2></div>
        <p>Complete generated instruction #{number} includes <a href="/resources/#{number}">its resource</a>.</p>
        <pre class="programlisting">build#{number}(source#{number});</pre></div>
      HTML
    end.join
    callout = <<~HTML
      <div class="sidebar"><div class="titlepage"><h3 class="title">Authored side note</h3></div>
      <p>The author discusses privacy in this source-owned technical explanation.</p><pre>callout(source);</pre>
      <a href="/callout/source">Published callout reference</a></div>
    HTML
    chapters = chapters.sub('</div>', "</div>#{callout}")
    body = <<~HTML
      <div class="book"><div class="titlepage"><h1 class="title">ExampleBuild 2.3.1</h1></div>
      <div class="preface"><h2>Published preface</h2><p>Complete preface instruction.</p></div>#{chapters}
      <div class="appendix"><h2>Published appendix</h2><p>Complete appendix instruction.</p><pre class="screen">appendix(source);</pre></div></div>
    HTML
    extract_from_url('https://publication.example.test/manual/build', manual_source(body, title: 'ExampleBuild 2.3.1')) do |payload|
      (1..120).each do |number|
        %w[html markdown].each do |format|
          expect(payload[format]).to include("Published chapter #{number}", "build#{number}(source#{number});", "/resources/#{number}")
        end
      end
      expect(payload['markdown']).to include('Published preface', 'Published appendix', 'Authored side note')
      expect(payload['markdown']).to include('callout(source);', '/callout/source', 'source-owned technical explanation')
    end
  end

  it 'retains structural whitespace without constructing documents for whitespace-only section boundaries' do
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.manualWhitespaceProbe = withComposedDomRead(function() {
        var original = document.implementation.createHTMLDocument;
        var documents = 0;
        document.implementation.createHTMLDocument = function() {
          documents++;
          return original.apply(this, arguments);
        };
        try {
          var content = physicalStandaloneManualContent(collectMetadata());
          return { documents: documents, html: content.html, markdown: content.markdown };
        } finally { document.implementation.createHTMLDocument = original; }
      });
      })(window);
    JS
    sections = (1..120).map do |number|
      "<section><h2>Instruction #{number}</h2><p>Published explanation #{number}.</p><div class=\"highlight\"><pre>value#{number}(source);</pre></div></section>"
    end.join
    compact = manual_source("<article><h1>Language reference manual</h1>#{sections}</article>")
    spaced = compact.gsub('</section><section>', "</section>\n  \t<section>")
    results = [compact, spaced].map do |html|
      with_url_page('https://publication.example.test/reference/manual', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
        page.add_script_tag(content: source.sub('})(window);', export))
        result = page.evaluate('window.manualWhitespaceProbe({})')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        result
      end
    end
    expect(results[1].fetch('documents')).to eq(results[0].fetch('documents'))
    expect(results[1].fetch('html')).to include("\n  \t")
    expect(results[1].fetch('markdown')).to eq(results[0].fetch('markdown'))
    expect(results[1].fetch('markdown')).to include('```')
    expect(results[1].fetch('markdown')).not_to include('<article>', '<section>')
    (1..120).each { |number| expect(results[1].fetch('markdown')).to include("Instruction #{number}", "value#{number}(source);") }
  end

  it 'declines foreign, hidden, ambiguous and nontechnical standalone owners' do
    valid = manual_source(
      '<article><h1>Language reference manual</h1><section><h2>Instruction</h2>' \
      '<p>Published prose.</p><div class="highlight"><pre>value(source);</pre></div></section></article>'
    )
    cases = [
      valid.sub('<article>', '<article hidden>'),
      valid.sub('</article>', '</article><article><h1>Other owner</h1></article>'),
      valid.sub('<title>Language reference manual</title>', '<title>Foreign identity</title>'),
      valid.gsub('Language reference manual', 'Published reporting'),
      valid.sub('class="highlight"', ''),
      valid.sub('<article>', '<aside><article>').sub('</article>', '</article></aside>')
    ]
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source = source.sub('})(window);', 'global.hasStandaloneManual = function() { return !!physicalStandaloneManualContent({title: document.title}); }; })(window);')
    cases.each do |html|
      with_url_page('https://publication.example.test/reference/manual', html) do |page|
        page.add_script_tag(content: source)
        expect(page.evaluate('hasStandaloneManual()')).to be false
      end
    end
  end

  it 'reuses only unchanged complete manual material and keeps changed-input and HTTP attribute policies' do
    body = '<article onclick="run()" style="color:red"><h1>Language reference manual</h1><section><h2>Complete instruction</h2>' \
            '<p>Published instruction retains its complete <a href="/reference">source reference</a>.</p>' \
            '<p>Contact <a href="mailto:maintainer@example.test">the maintainer</a> for context.</p>' \
            '<p>Keep the <a href="javascript:run()">unsafe label</a> as authored text.</p>' \
            '<div class="highlight"><pre>value(source);</pre></div></section></article>'
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.manualFinalizationProbe = withComposedDomRead(function(options) {
        var metadata = collectMetadata();
        var content = physicalStandaloneManualContent(metadata);
        if (options.changeHtml) content.html += '<button onclick="run()" style="color:red">Sign in</button>';
        if (options.changeTitle) content.title = 'Different current title';
        var calls = 0;
        var materializedCalls = 0;
        var titleEvidenceCalls = 0;
        var formatRootCalls = 0;
        var detectingFormat = false;
        var sanitized = null;
        var original = sanitizedHtml;
        var originalMaterialized = materializedHtml;
        var originalTitleEvidence = articleTitleFromDeclaredDescription;
        var originalFormat = detectContentFormat;
        var originalRoot = multiTopicExtractionRoot;
        sanitizedHtml = function(html, previews) {
          if (html === content.html) calls++;
          var cleaned = original(html, previews);
          if (html === content.html) sanitized = cleaned;
          return cleaned;
        };
        materializedHtml = function(html, mailto) {
          if (html === content.html) materializedCalls++;
          return originalMaterialized(html, mailto);
        };
        articleTitleFromDeclaredDescription = function() {
          titleEvidenceCalls++;
          return originalTitleEvidence.apply(this, arguments);
        };
        detectContentFormat = function() {
          detectingFormat = true;
          try { return originalFormat.apply(this, arguments); }
          finally { detectingFormat = false; }
        };
        multiTopicExtractionRoot = function() {
          if (detectingFormat) formatRootCalls++;
          return originalRoot.apply(this, arguments);
        };
        try {
          var result = finalizeExtractResult(content, metadata, pageReadableText(), null, null);
          return { calls: calls, materializedCalls: materializedCalls, titleEvidenceCalls: titleEvidenceCalls,
            formatRootCalls: formatRootCalls, contentFormat: result.contentFormat,
            sanitized: sanitized, html: result.html, markdown: result.markdown };
        } finally {
          sanitizedHtml = original;
          materializedHtml = originalMaterialized;
          articleTitleFromDeclaredDescription = originalTitleEvidence;
          detectContentFormat = originalFormat;
          multiTopicExtractionRoot = originalRoot;
        }
      });
      })(window);
    JS

    with_url_page('https://publication.example.test/reference/manual', manual_source(body)) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: source.sub('})(window);', export))
      unchanged = page.evaluate('window.manualFinalizationProbe({changeHtml:false})')
      changed = page.evaluate('window.manualFinalizationProbe({changeHtml:true})')
      changed_title = page.evaluate('window.manualFinalizationProbe({changeTitle:true})')

      expect(unchanged.fetch('calls')).to eq(0)
      expect(changed.fetch('calls')).to eq(1)
      expect(changed.fetch('sanitized')).not_to include('Sign in')
      expect(unchanged.fetch('materializedCalls')).to eq(0)
      expect(changed.fetch('materializedCalls')).to eq(1)
      expect(unchanged.fetch('titleEvidenceCalls')).to eq(0)
      expect(changed.fetch('titleEvidenceCalls')).to be_positive
      expect(changed_title.fetch('titleEvidenceCalls')).to be_positive
      expect(unchanged.fetch('contentFormat')).to be_nil
      expect(unchanged.fetch('formatRootCalls')).to eq(0)
      expect(changed.fetch('formatRootCalls')).to be_positive
      expect(changed_title.fetch('formatRootCalls')).to be_positive
      [unchanged, changed, changed_title].each do |result|
        expect(result.fetch('html')).not_to include('onclick=', 'style=', 'mailto:', 'javascript:')
        %w[html markdown].each do |format|
          expect(result.fetch(format)).to include('Published instruction', '/reference', 'value(source);')
          expect(result.fetch(format)).to include('the maintainer', 'unsafe label')
        end
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end

    liveblog = '<script type="application/ld+json">{"@context":"https://schema.org","@type":"LiveBlogPosting"}</script>'
    with_url_page('https://publication.example.test/reference/manual', manual_source(body).sub('</head>', "#{liveblog}</head>")) do |page|
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: source.sub('})(window);', export))
      result = page.evaluate('window.manualFinalizationProbe({})')
      expect(result.fetch('contentFormat')).to eq('liveblog')
      expect(result.fetch('html')).to include('Published instruction', '/reference', 'value(source);')
    end
  end
end
