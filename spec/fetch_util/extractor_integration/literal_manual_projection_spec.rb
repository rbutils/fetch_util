# frozen_string_literal: true

require 'cgi'

RSpec.describe 'FetchUtil physical literal manual projection' do
  include_context 'extractor integration helpers'

  def literal_probe_source
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.literalProjectionProbe = withComposedDomRead(function() {
        var source = document.querySelector('#source');
        var projected = physicalLiteralCodeProjection(source);
        return projected ? { text: projected.textContent, html: projected.outerHTML,
          elements: projected.querySelectorAll('*').length } : null;
      });
      })(window);
    JS
    source.sub('})(window);', export)
  end

  it 'preserves every literal token and line without cloning presentation-only spans or changing the source' do
    tokens = (1..240).map { |number| "<span class=\"token\">value#{number}</span> = transform(#{number});\n" }.join
    html = "<html><body><div id=\"source\" class=\"highlight\"><pre class=\"language-python\">#{tokens}</pre>" \
           '<button class="copybutton" title="Copy" aria-label="Copy code to clipboard"><svg aria-hidden="true"></svg></button></div></body></html>'
    with_url_page('https://publication.example.test/reference/literal', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      expected = page.evaluate("document.querySelector('pre').textContent")
      page.add_script_tag(content: literal_probe_source)
      projected = page.evaluate('window.literalProjectionProbe({})')
      expect(projected.fetch('text')).to eq(expected)
      expect(projected.fetch('elements')).to eq(2)
      (1..240).each { |number| expect(projected.fetch('html')).to include("value#{number} = transform(#{number});") }
      expect(projected.fetch('html')).to include('language-python')
      expect(projected.fetch('html')).not_to include('copybutton', '<button')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'declines hidden, clipped, reference-bearing, identified, interactive and nonliteral tokens' do
    tokens = [
      '<span hidden>private</span>', '<span style="display:none">private</span>',
      '<span style="visibility:hidden">private</span>', '<span style="opacity:0">private</span>',
      '<span style="overflow:hidden">clipped</span>', '<span aria-hidden="true">private</span>',
      '<span id="fragment">identified</span>', '<span role="button">control</span>',
      '<a href="/source">source reference</a>', '<button>published control</button>', '<br>'
    ]
    tokens.each do |token|
      with_url_page('https://publication.example.test/reference/literal', "<div id=\"source\"><pre>visible #{token}</pre></div>") do |page|
        before = page.evaluate('document.body.innerHTML')
        page.add_script_tag(content: literal_probe_source)
        expect(page.evaluate('window.literalProjectionProbe({})')).to be_nil
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'checks enclosing source visibility once while retaining all independently proved programs' do
    programs = (1..240).map { |number| "<div><pre><span>published_example_#{number}();</span></pre></div>" }.join
    with_url_page('https://publication.example.test/reference/literal', "<article id=\"source\">#{programs}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      page.evaluate(<<~JS)
        (() => {
          var original = window.getComputedStyle;
          window.bodyStyleReads = 0;
          window.getComputedStyle = function(node, pseudo) {
            if (node === document.body) window.bodyStyleReads++;
            return original.call(window, node, pseudo);
          };
        })()
      JS
      page.add_script_tag(content: literal_probe_source.sub('physicalLiteralCodeProjection(source)', 'physicalManualVisibilityClone(source)'))
      projected = page.evaluate('window.literalProjectionProbe({})')
      (1..240).each { |number| expect(projected.fetch('html')).to include("published_example_#{number}();") }
      expect(page.evaluate('window.bodyStyleReads')).to be < 10
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps authored prose outside code and declines composed content' do
    cases = [
      '<div id="source"><p>Authored explanation.</p><pre><span>value(source);</span></pre></div>',
      '<div id="source"><pre><span>value(source);</span></pre><button class="copybutton">Publish correction</button></div>',
      '<div id="source"><pre><span>value(source);</span></pre><button class="copybutton" title="Copy"><a href="/source">Published source</a></button></div>',
      '<div id="source"><pre><span>value(source);</span></pre><button class="copybutton" title="Copy">Published correction</button></div>',
      '<div id="source"><pre><span>value(source);</span><sample-widget></sample-widget></pre></div>'
    ]
    cases.each do |body|
      with_url_page('https://publication.example.test/reference/literal', body) do |page|
        before = page.evaluate('document.body.innerHTML')
        page.add_script_tag(content: literal_probe_source)
        expect(page.evaluate('window.literalProjectionProbe({})')).to be_nil
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'declines a complete prose chapter before querying all of its programs' do
    programs = (1..240).map { |number| "<p>Authored section #{number}.</p><pre>example_#{number}();</pre>" }.join
    with_url_page('https://publication.example.test/reference/literal', "<div id=\"source\">#{programs}</div>") do |page|
      page.add_script_tag(content: literal_probe_source)
      page.evaluate(<<~JS)
        (() => {
          var chapter = document.getElementById('source');
          window.chapterProgramQueries = 0;
          var query = chapter.querySelectorAll;
          chapter.querySelectorAll = function(selector) {
            window.chapterProgramQueries++;
            return query.call(this, selector);
          };
        })()
      JS
      expect(page.evaluate('window.literalProjectionProbe({})')).to be_nil
      expect(page.evaluate('window.chapterProgramQueries')).to eq(0)
      expect(page.evaluate("document.getElementById('source').querySelectorAll('pre').length")).to eq(240)
    end
  end

  it 'preserves whole sections exactly while pruning each proved literal program only once' do
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.literalProgramProbe = withComposedDomRead(function() {
        var node = document.querySelector('#source');
        var originalImport = Document.prototype.importNode;
        var deepSourceImports = 0;
        Document.prototype.importNode = function(source, deep) {
          if (deep && source.isConnected && source.ownerDocument === document) deepSourceImports++;
          return originalImport.apply(this, arguments);
        };
        function render(visible) {
          var root = document.createElement('div');
          root.appendChild(visible);
          var clean = cleanClone(root);
          cleanupAgentRoot(clean);
          materializeHttpAttributes(clean, false, false);
          return {html: clean.innerHTML, markdown: markdownFor(clean.innerHTML, false, true, true).trim()};
        }
        try {
          var ordinary = visibilityPrunedClone(node, document);
          var ordinaryImports = deepSourceImports;
          deepSourceImports = 0;
          var projected = physicalManualVisibilityClone(node);
          var projectedImports = deepSourceImports;
          return {actual: render(projected), expected: render(ordinary),
            ordinaryImports: ordinaryImports, projectedImports: projectedImports};
        } finally {
          Document.prototype.importNode = originalImport;
        }
      });
      })(window);
    JS
    probe = source.sub('})(window);', export)
    programs = [
      ['language-python', (1..240).map { |number| "value#{number} = transform(#{number});" }.join("\n")],
      ['language-text', "literal ``` delimiter\nhttps://publication.example.test/code/(source)\ncomplete final line"],
      ['', "\nfirst line\n\nlast line\n"]
    ]
    programs.each do |language, text|
      tokens = text.split("\n", -1).map { |line| "<span>#{CGI.escapeHTML(line)}</span>" }.join("\n")
      body = '<section id="source"><h2>Complete language instruction</h2><p>Authored explanation with ' \
             '<a href="/reference/source">a published reference</a>.</p><div class="highlight">' \
             "<pre class=\"#{language}\">#{tokens}</pre>" \
              '<button class="copybutton" title="Copy" aria-label="Copy code to clipboard">' \
              '<svg aria-hidden="true"><path d="M0 0L1 1"></path></svg></button></div>' \
             '<table><tr><td>Authored field</td><td>Complete value</td></tr></table></section>'
      with_url_page('https://publication.example.test/reference/literal', body) do |page|
        before = page.evaluate('document.body.innerHTML')
        FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
        page.add_script_tag(content: probe)
        result = page.evaluate('window.literalProgramProbe({})')
        expect(result.fetch('actual')).to eq(result.fetch('expected'))
        expect(result.fetch('ordinaryImports')).to be_positive
        expect(result.fetch('projectedImports')).to eq(0)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'keeps complete source maps and ordinary visibility for uncertain or clipped code' do
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.literalFallbackProbe = withComposedDomRead(function() {
        var node = document.querySelector('#source');
        var ordinary = visibilityPrunedClone(node, document);
        var projected = physicalManualVisibilityClone(node);
        var map = new WeakMap();
        var mapped = visibilityPrunedClone(node, document, map, false, function(source) {
          return source.matches('pre') ? physicalLiteralCodeProjection(source) : null;
        });
        return {ordinary: ordinary.outerHTML, projected: projected.outerHTML,
          mapped: mapped.outerHTML, mappedToken: map.has(node.querySelector('span'))};
      });
      })(window);
    JS
    probe = source.sub('})(window);', export)
    tokens = ['<span>complete literal</span>', '<span hidden>hidden literal</span><span>visible literal</span>',
              '<span style="visibility:hidden">hidden literal</span><span>visible literal</span>',
              '<span style="display:block;overflow:hidden;width:0;height:0">clipped literal</span><span>visible literal</span>',
              '<span id="reference">fragment destination</span>', '<span><a href="/reference">published reference</a></span>']
    tokens.each do |token|
      with_url_page('https://publication.example.test/reference/literal', "<section id=\"source\"><pre>#{token}</pre></section>") do |page|
        before = page.evaluate('document.body.innerHTML')
        page.add_script_tag(content: probe)
        result = page.evaluate('window.literalFallbackProbe({})')
        if token == tokens.first
          expect(result.fetch('mapped')).to eq(result.fetch('ordinary'))
          expect(result.fetch('mappedToken')).to be(true)
        else
          expect(result.fetch('projected')).to eq(result.fetch('ordinary'))
        end
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'retains exact unusual physical topology outside proved literal programs' do
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    export = <<~JS
      window.literalTopologyProbe = withComposedDomRead(function() {
        var node = document.querySelector('#source');
        var ordinary = visibilityPrunedClone(node, document);
        var imports = 0;
        var original = Document.prototype.importNode;
        Document.prototype.importNode = function(source, deep) {
          if (deep && source === node) imports++;
          return original.apply(this, arguments);
        };
        try {
          var projected = physicalManualVisibilityClone(node);
          var expectedProgram = ordinary.querySelector('pre').textContent;
          var actualProgram = projected.querySelector('pre').textContent;
          ordinary.querySelector('pre').replaceChildren();
          projected.querySelector('pre').replaceChildren();
          return { ordinary: ordinary.outerHTML, projected: projected.outerHTML,
            expectedProgram: expectedProgram, actualProgram: actualProgram, imports: imports };
        } finally { Document.prototype.importNode = original; }
      });
      })(window);
    JS
    body = '<section id="source"><table><tr><td>Published field</td></tr></table>' \
           '<pre><span>complete_program(source);</span></pre></section>'
    with_url_page('https://publication.example.test/reference/literal', body) do |page|
      page.evaluate(<<~JS)
        (() => {
          var paragraph = document.createElement('p');
          paragraph.textContent = 'Published explanation retains its unusual physical placement.';
          document.querySelector('table').appendChild(paragraph);
        })()
      JS
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: source.sub('})(window);', export))
      result = page.evaluate('window.literalTopologyProbe({})')
      expect(result.fetch('projected')).to eq(result.fetch('ordinary'))
      expect(result.fetch('projected')).to include('Published explanation')
      expect(result.fetch('actualProgram')).to eq(result.fetch('expectedProgram'))
      expect(result.fetch('actualProgram')).to eq('complete_program(source);')
      expect(result.fetch('imports')).to eq(0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'uses the ordinary native copy contract when a physical owner contains mutable controls' do
    export = <<~JS
      window.literalStateProbe = withComposedDomRead(function() {
        var node = document.querySelector('#source');
        function state(copy) {
          return { html: copy.outerHTML, input: copy.querySelector('input').value,
            textarea: copy.querySelector('textarea').value, selected: copy.querySelector('select').value };
        }
        return { actual: state(physicalManualVisibilityClone(node)), expected: state(visibilityPrunedClone(node, document)) };
      }); })(window);
    JS
    body = '<section id="source"><input value="initial"><textarea>initial</textarea><select>' \
           '<option>first</option><option>second</option></select><pre><span>source_value();</span></pre></section>'
    with_url_page('https://publication.example.test/reference/state', body) do |page|
      page.evaluate("(() => { document.querySelector('input').value='published current';" \
                    "document.querySelector('textarea').value='complete current';" \
                    "document.querySelector('select').value='second'; })()")
      page.add_script_tag(content: literal_probe_source.sub(/window.literalProjectionProbe =.*\}\)\(window\);/m, export))
      result = page.evaluate('window.literalStateProbe({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('actual').values).to include('published current', 'complete current')
      expect(page.evaluate("document.querySelector('select').value")).to eq('second')
    end
  end
end
