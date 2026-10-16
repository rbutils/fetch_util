# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Generated technical reference runtime', :integration do
  include_context 'extractor integration helpers'

  def generated_reference_page
    sections = (1..160).map do |index|
      <<~HTML
        <section><h2 id="operation-#{index}"><a href="#operation-#{index}">Operation #{index}</a></h2>
        <p>Complete explanation #{index} describes every operand, constraint and observable effect of this operation.</p>
        <dl><dt><a href="#operation-#{index}"><code>operation_#{index}</code></a></dt>
        <dd><p>Complete definition #{index} retains its authored wording and <a href="/source/#{index}">source #{index}</a>.</p>
        <p>Set <code>ENGINE_CONFIG_FILE</code> to select <code>engine.toml</code> for the complete operation.</p>
        <p>Sign in selects the documented credential operation.</p></dd></dl>
        <pre><code class="language-text">operation_#{index}(value)
        complete_example_#{index}</code></pre></section>
      HTML
    end.join
    <<~HTML
      <!doctype html><html lang="en" itemscope itemtype="https://schema.org/WebPage"><head>
      <title>Commands | Example Engine</title><meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.6">
      <link rel="canonical" href="https://reference.example.test/commands/">
      <script id="site-declaration" type="application/ld+json">{"@context":"https://schema.org","@type":"WebSite",
      "name":"Example Engine","url":"https://reference.example.test","datePublished":"2001-01-01T00:00:00Z"}</script>
      <style>.dynamic-sensitive { color: black; }</style></head><body>
      <header><nav>Example Engine navigation</nav></header><main><aside><nav>Reference navigation</nav></aside>
      <article class="md-content__inner md-typeset"><h1>CLI Reference</h1>
      <p class="dynamic-sensitive">The complete technical reference belongs to this current document.</p>#{sections}
      <aside class="md-source-file"><span class="md-source-file__fact"><span class="md-icon" title="Last update"></span>
      <span class="git-revision-date-localized-plugin-date" title="May 4, 2024 12:31:38 UTC">May 4, 2024</span></span></aside></article>
      </main><footer>Example Engine reference resources</footer></body></html>
    HTML
  end

  def reference_task_probe(page, body)
    preparation = FetchUtil::Extractor.new.__send__(:owned_preparation_call)
    page.evaluate(<<~JS)
      (() => {
        const originalClone = Node.prototype.cloneNode, originalCreate = document.createElement;
        const task = #{preparation};
        #{body}
      })()
    JS
  end

  it 'matches the ordinary complete renderer while retaining all terms, links and programs' do
    with_url_page('https://reference.example.test/commands/', generated_reference_page) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.body.innerHTML')
      ordinary = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      calls = []
      allow(page).to receive(:command).and_wrap_original do |original, method, **parameters|
        calls << method
        original.call(method, **parameters)
      end
      actual = FetchUtil::Extractor.new.extract(page)
      expect(actual).to eq(ordinary)
      expect(calls.count('HeapProfiler.collectGarbage')).to eq(2)
      expect(actual.fetch('title')).to eq('CLI Reference')
      expect(actual.fetch('publishedTime')).to be_nil
      expect(actual.fetch('html').scan('<dt>').length).to eq(160)
      expect(actual.fetch('html').scan('<pre').length).to eq(160)
      expect(actual.fetch('markdown')).to include('[`operation_160`](https://reference.example.test/commands/#operation-160)', 'complete_example_160')
      expect(actual.fetch('markdown').scan('ENGINE_CONFIG_FILE').length).to eq(160)
      expect(actual.fetch('markdown').scan('Sign in selects the documented credential operation.').length).to eq(160)
      expect(actual.fetch('html')).to include('May 4, 2024 12:31:38 UTC')
      expect(actual.fetch('markdown')).to include('May 4, 2024')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'proves the generated owner before cloning and prepares the existing renderer only once' do
    with_url_page('https://reference.example.test/commands/', generated_reference_page) do |page|
      inject_standalone_extractor(page)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('article'), before = document.body.innerHTML;
          const originalImport = Document.prototype.importNode;
          let clones = 0;
          Document.prototype.importNode = function(node, deep) {
            if (node === root) clones++;
            return originalImport.call(this, node, deep);
          };
          try {
            const task = #{FetchUtil::Extractor.new.__send__(:owned_preparation_call)};
            const initial = clones;
            task.prepare();
            const prepared = clones;
            task.prepare();
            const repeated = clones;
            return {owned: task.owned, initial, prepared, repeated, payload: task.finish(), unchanged: before === document.body.innerHTML};
          } finally { Document.prototype.importNode = originalImport; }
        })()
      JS
      expect(result).to include('owned' => true, 'initial' => 0, 'unchanged' => true)
      expect(result.fetch('prepared')).to be_positive
      expect(result.fetch('repeated')).to eq(result.fetch('prepared'))
      expect(result.fetch('payload').fetch('html').scan('<pre').length).to eq(160)
    end
  end

  it 'falls back to complete current material when the source changes after preparation' do
    with_url_page('https://reference.example.test/commands/', generated_reference_page) do |page|
      inject_standalone_extractor(page)
      result = reference_task_probe(page, <<~JS)
        task.prepare();
        const preparedScopesRestored = Node.prototype.cloneNode === originalClone && document.createElement === originalCreate;
        const paragraph = document.createElement('p');
        paragraph.textContent = 'Newly published technical definition must be preserved.';
        document.querySelector('article').appendChild(paragraph);
        const payload = task.finish();
        let consumed = false;
        try { task.finish(); } catch (error) { consumed = /already been consumed/.test(error.message); }
        return {owned: task.owned, preparedScopesRestored, consumed, payload};
      JS
      expect(result).to include('owned' => true, 'preparedScopesRestored' => true, 'consumed' => true)
      expect(result.fetch('payload').fetch('markdown')).to include('Newly published technical definition', 'complete_example_160')
      expect(result.fetch('payload').fetch('markdown')).to include('The complete technical reference belongs')
    end
  end

  it 'invalidates prepared work after CSSOM changes even when serialized source is unchanged' do
    with_url_page('https://reference.example.test/commands/', generated_reference_page) do |page|
      inject_standalone_extractor(page)
      result = reference_task_probe(page, <<~JS)
        task.prepare();
        const before = document.documentElement.outerHTML;
        document.styleSheets[0].insertRule('.dynamic-sensitive { color: blue; }', 0);
        const unchangedMarkup = before === document.documentElement.outerHTML;
        const root = document.querySelector('article'), originalImport = Document.prototype.importNode;
        let clones = 0, payload;
        Document.prototype.importNode = function(node, deep) {
          if (node === root) clones++;
          return originalImport.call(this, node, deep);
        };
        try { payload = task.finish(); }
        finally { Document.prototype.importNode = originalImport; }
        const ordinary = window.FetchUtilExtract.extract({reader_mode: true});
        return {owned: task.owned, unchangedMarkup, clones, payload, ordinary,
          restored: Node.prototype.cloneNode === originalClone && document.createElement === originalCreate};
      JS
      expect(result).to include('owned' => true, 'unchangedMarkup' => true, 'restored' => true)
      expect(result.fetch('clones')).to be_positive
      expect(result.fetch('payload')).to eq(result.fetch('ordinary'))
      expect(result.fetch('payload').fetch('html').scan('<pre').length).to eq(160)
    end
  end

  it 'declines conflicting, incomplete, foreign and unbounded framework owners' do
    with_url_page('https://reference.example.test/commands/', generated_reference_page) do |page|
      inject_standalone_extractor(page)
      result = page.evaluate(<<~JS)
        (() => {
          const before = document.body.innerHTML, article = document.querySelector('article');
          const canonical = document.querySelector('link[rel=canonical]'), generator = document.querySelector('meta[name=generator]');
          const site = document.querySelector('#site-declaration'), originalSite = site.textContent;
          const probe = () => { const task = #{FetchUtil::Extractor.new.__send__(:owned_preparation_call)}; const owned = task.owned; task.dispose(); return owned; };
          const values = [probe()];
          const foreignSite = JSON.parse(originalSite); foreignSite.url = 'https://foreign.example.test';
          site.textContent = JSON.stringify(foreignSite); values.push(probe()); site.textContent = originalSite;
          canonical.href = 'https://foreign.example.test/commands/'; values.push(probe()); canonical.href = location.href;
          generator.content = 'Other generator'; values.push(probe()); generator.content = 'mkdocs-1.6.1';
          article.hidden = true; values.push(probe()); article.hidden = false;
          const outside = document.createElement('p'); outside.textContent = 'Separate published reporting.';
          document.body.appendChild(outside); values.push(probe()); outside.remove();
          const competing = document.createElement('article'); competing.textContent = 'Another independent article.';
          document.querySelector('main').appendChild(competing); values.push(probe()); competing.remove();
          const declarations = document.createElement('script'); declarations.type = 'application/ld+json';
          declarations.textContent = JSON.stringify({'@type':'NewsArticle', headline:'Another current report'});
          document.head.appendChild(declarations); values.push(probe()); declarations.remove();
          values.push(probe());
          return {values, unchanged: before === document.body.innerHTML};
        })()
      JS
      expect(result.fetch('values')).to eq([true, false, false, false, false, false, false, false, true])
      expect(result.fetch('unchanged')).to be(true)
    end
  end
end
