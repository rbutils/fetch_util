# frozen_string_literal: true

RSpec.describe 'Owned article titles' do
  include_context 'extractor integration helpers'

  it 'prefers the selected article heading over an appended publication name' do
    html = <<~HTML
      <html><head><title>Research across borders - Journal.example</title>
      <meta property="og:site_name" content="www.journal.example"></head><body>
      <article><h1>Research across borders</h1>
      <p>Researchers compared independent measurements from several regions and documented the evidence behind each conclusion. Their report describes the practical limitations and the complete methodology.</p>
      <h2>Supporting evidence</h2><p>The investigators also published a <a href="/data">public dataset</a> so others can reproduce the analysis. These independent records remain important when interpreting the observations.</p></article>
      </body></html>
    HTML
    [false, true].each do |reader_mode|
      with_url_page('https://journal.example/reports/borders', html) do |page|
        result = FetchUtil::Extractor.new(reader_mode: reader_mode).extract(page)
        expect(result['title']).to eq('Research across borders')
        expect(result['markdown']).to start_with('# Research across borders')
        expect(result['markdown']).not_to include(' - Journal.example')
        expect(result['markdown']).to include('[public dataset](https://journal.example/data)')
      end
    end
  end

  it 'preserves a genuine title extension that is not the publication name' do
    html = <<~HTML
      <html><head><title>Research across borders - A new method</title>
      <meta property="og:site_name" content="Journal.example"></head><body>
      <article><h1>Research across borders</h1>
      <p>Researchers compared independent measurements from several regions and documented the evidence behind each conclusion. Their report describes the practical limitations and the complete methodology.</p>
      <h2>Supporting evidence</h2><p>The investigators published independent records with additional context, including the assumptions and the measurements used to reproduce their careful analysis.</p></article>
      </body></html>
    HTML
    with_url_page('https://journal.example/reports/method', html) do |page|
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(result['title']).to eq('Research across borders - A new method')
      expect(result['markdown']).to include('A new method')
    end
  end

  it 'does not leave an enrichment-generated publication suffix as article prose' do
    html = <<~HTML
      <html><head><title>League match review - Sports.example</title>
      <meta property="og:site_name" content="Sports.example"></head><body>
      <article><h1>League match review</h1><p>North Club played South Club in the league competition. The complete match report describes the players, the decisive moments, and the tactical choices made by each manager throughout the game.</p>
      <table><tr><th>Team</th><th>Score</th></tr><tr><td>North Club</td><td>2</td></tr><tr><td>South Club</td><td>1</td></tr></table>
      <h2>Post-match analysis</h2><p>The independent analysis considers the evidence in detail and explains the key differences between the teams. All observations and qualifications remain part of the article.</p></article></body></html>
    HTML
    with_url_page('https://sports.example/sport/league-match', html) do |page|
      result = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(result['title']).to eq('League match review')
      expect(result['markdown'].scan(/^# League match review$/).length).to eq(1)
      expect(result['markdown']).not_to include(' - Sports.example', "\n- Sports.example")
      expect(result['markdown']).to include('Post-match analysis', 'North Club')
    end
  end

  it 'restores the uniquely source-owned H1 when a reader demotes it to H2' do
    html = <<~HTML
      <html><head><title>Getting started</title></head><body><main><article>
        <h1>Getting started</h1>
        <h3>Quick start</h3><p>Create the first project and verify that its preview is available.</p>
        <h3>Basic usage</h3><p>Use the command line to build and publish the complete project.</p>
        <h3>Directory structure</h3><p>The project keeps layouts and content in distinct directories.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://docs.example/getting-started', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const Reader = function() {};
          Reader.prototype.parse = function() {
            const article = document.querySelector('main article');
            return {title: document.title, content: '<article>' + article.innerHTML.replace('<h1>', '<h2>').replace('</h1>', '</h2>') + '</article>', textContent: article.textContent};
          };
          window.Readability = Reader;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS

      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('html')).to match(%r{<h1>Getting started</h1>})
      expect(payload.fetch('html')).not_to include('<h2>Getting started</h2>')
      expect(payload.fetch('markdown')).to start_with("# Getting started\n")
      expect(payload.fetch('markdown')).to include('Quick start', 'Basic usage', 'Directory structure')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'removes a publication-owned suffix when restoring a demoted source H1' do
    html = <<~HTML
      <html><head><title>Conteudo Exclusivo | VEJA</title></head><body><main><article>
        <h1>Conteudo Exclusivo</h1>
        <p>A primeira parte da reportagem apresenta o contexto público com informações verificáveis e uma explicação completa para os leitores.</p>
        <p>O segundo parágrafo documenta as decisões, as fontes consultadas e as consequências práticas discutidas pela reportagem.</p>
        <p>A conclusão preserva o restante do conteúdo público e diferencia a matéria de recomendações ou chamadas promocionais.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://veja.abril.com.br/brasil/conteudo-exclusivo', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const Reader = function() {};
          Reader.prototype.parse = function() {
            const article = document.querySelector('main article');
            return {title: document.title, siteName: location.hostname,
              content: '<article>' + article.innerHTML.replace('<h1>', '<h2>').replace('</h1>', '</h2>') + '</article>',
              textContent: article.textContent};
          };
          window.Readability = Reader;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS

      expect(payload.fetch('title')).to eq('Conteudo Exclusivo')
      expect(payload.fetch('html')).to include('<h1>Conteudo Exclusivo</h1>')
      expect(payload.fetch('markdown')).to start_with("# Conteudo Exclusivo\n")
      expect(payload.fetch('markdown')).not_to include('| VEJA')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a genuine title extension when a reader demotes the source H1' do
    html = <<~HTML
      <html><head><title>Research across borders - A new method</title></head><body><main><article>
        <h1>Research across borders</h1>
        <p>Researchers compared independent measurements from several regions and documented the evidence behind each conclusion in the report.</p>
        <p>The investigators also published the assumptions, complete methodology, and public records used to reproduce the analysis.</p>
        <p>A final section explains the new method and why it changes how the measurements should be interpreted by other researchers.</p>
      </article></main></body></html>
    HTML

    with_url_page('https://journal.example/reports/borders', html) do |page|
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const Reader = function() {};
          Reader.prototype.parse = function() {
            const article = document.querySelector('main article');
            return {title: document.title, siteName: location.hostname,
              content: '<article>' + article.innerHTML.replace('<h1>', '<h2>').replace('</h1>', '</h2>') + '</article>',
              textContent: article.textContent};
          };
          window.Readability = Reader;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS

      expect(payload.fetch('title')).to eq('Research across borders - A new method')
      expect(payload.fetch('html')).to include('<h2>Research across borders</h2>')
      expect(payload.fetch('markdown')).to include('A new method')
    end
  end

  it 'restores a uniquely owned H1 in an article directly under the body' do
    html = <<~HTML
      <html><head><title>Public notice across borders</title></head><body>
        <article><h1>Public notice across borders</h1>
          <p>The opening paragraph reports the complete public notice and describes the independent meetings that led to this announcement.</p>
          <p>The second paragraph documents the decisions, the evidence for each decision, and the practical consequences for residents.</p>
          <p>The third paragraph preserves the public article rather than a short subscription prompt or an unrelated recommendation.</p>
          <div class="paywall-content">Continue reading with full access</div>
        </article>
      </body></html>
    HTML

    with_url_page('https://journal.example/reports/public-notice', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      extractor_for(true).__send__(:inject_assets, page)
      payload = page.evaluate <<~JS
        (() => {
          const Reader = function() {};
          Reader.prototype.parse = function() {
            const article = document.querySelector('body > article');
            return {title: document.title, content: '<article>' + article.innerHTML.replace('<h1>', '<h2>').replace('</h1>', '</h2>') + '</article>', textContent: article.textContent};
          };
          window.Readability = Reader;
          return window.FetchUtilExtract.extract({reader_mode: true});
        })()
      JS

      expect(payload.fetch('html')).to include('<h1>Public notice across borders</h1>')
      expect(payload.fetch('html')).not_to include('<h2>Public notice across borders</h2>')
      expect(payload.fetch('markdown')).to include('The opening paragraph reports', 'The third paragraph preserves')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'uses an external H1 only when it owns the complete selected article body' do
    root = File.expand_path('../../..', __dir__)
    html = File.read(File.join(root, 'spec/fixtures/focal_title_csdn_060.html'))

    with_url_page('https://blog.csdn.net/csdnnews/article/details/162627987', html) do |page|
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      probe_source = source.sub(
        '})(window);', 'global.externalTitleProbe = articleTitleFromSelectedExternalBodyHeading;'
      )
      page.add_script_tag(content: "#{probe_source} })(window);")
      diagnostics = page.evaluate <<~JS
        (() => {
          const metadata = {
            title: document.title,
            siteName: location.hostname,
            excerpt: document.querySelector('meta[name="description"]').content
          };
          const content = {contentType: 'article', html: document.querySelector('main article').outerHTML};
          return externalTitleProbe(content, metadata, document.title);
        })()
      JS
      expect(diagnostics).to eq('Java即将放弃Intel Mac：JDK 27起不再续命')

      payload = extract_payload(page)
      expect(payload.fetch('title')).to eq('Java即将放弃Intel Mac：JDK 27起不再续命')
      expect(payload.fetch('markdown')).to start_with('# Java即将放弃Intel Mac：JDK 27起不再续命')
      expect(payload.fetch('markdown')).to include('Intel 版 Mac 的退场', '现代硬件')
      expect(payload.fetch('siteName')).to eq('blog.csdn.net')
      expect(payload.fetch('publishedTime')).to include('2026-07-06')
      expect(payload.fetch('byline')).to eq('csdnnews')
      expect(payload.fetch('markdown')).to include('登录后阅读全文')
      expect(payload.fetch('html')).to include('登录后阅读全文')

      selected_html = page.evaluate <<~JS
        (() => {
          const selected = document.querySelector('main article').cloneNode(true);
          const gate = selected.querySelector('.readall_box');
          const paragraph = document.createElement('p');
          paragraph.textContent = gate.textContent;
          gate.replaceWith(paragraph);
          return selected.outerHTML;
        })()
      JS
      metadata = {
        title: 'Java即将放弃Intel Mac：JDK 27起不再续命-CSDN博客',
        siteName: 'blog.csdn.net',
        excerpt: 'Intel 版 Mac 的退场又迎来一个标志性节点。'
      }
      selected_content = { contentType: 'article', html: selected_html }
      expected_title = 'Java即将放弃Intel Mac：JDK 27起不再续命'
      declared_title = 'Java即将放弃Intel Mac：JDK 27起不再续命-CSDN博客'
      expect(page.evaluate("externalTitleProbe(#{JSON.generate(selected_content)}, #{JSON.generate(metadata)}, #{JSON.generate(declared_title)})"))
        .to eq(expected_title)

      selected_with_foreign_material = selected_content.merge(
        html: selected_html.sub('</article>', '<aside>Unowned recommendation material</aside></article>')
      )
      expect(page.evaluate("externalTitleProbe(#{JSON.generate(selected_with_foreign_material)}, #{JSON.generate(metadata)}, #{JSON.generate(declared_title)})"))
        .to eq(declared_title)
    end
  end

  it 'requires a local attributed article header and a matching declared title prefix' do
    html = <<~HTML
      <html><head><title>Owned article title - Publisher</title></head><body><main>
        <div class="title-box"><h1>Owned article title</h1></div>
        <div class="article-bar-top"><time datetime="2026-10-02">October 2, 2026</time>
          <a rel="author" href="/authors/reporter">Reporter</a></div>
        <article><p>First complete source paragraph records the verified event, its context, and the details needed to understand the report.</p>
          <p>Second complete source paragraph preserves the remaining evidence, the source attribution, and the consequences for readers.</p></article>
      </main></body></html>
    HTML
    with_url_page('https://publisher.example/articles/report', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      page.add_script_tag(content: source.sub('})(window);', 'global.externalTitleProbe = articleTitleFromSelectedExternalBodyHeading; })(window);'))
      selected = page.evaluate('document.querySelector("main article").outerHTML')
      content = { contentType: 'article', html: selected }
      metadata = {
        canonicalUrl: nil,
        title: 'Owned article title - Publisher',
        siteName: 'Publisher',
        excerpt: 'First complete source paragraph records the verified event, its context, and the details needed to understand the report.'
      }
      probe = lambda do |declared_title = metadata.fetch(:title)|
        page.evaluate("externalTitleProbe(#{JSON.generate(content)}, #{JSON.generate(metadata)}, #{JSON.generate(declared_title)})")
      end
      expect(probe.call).to eq('Owned article title')

      page.evaluate <<~JS
        (() => {
          document.querySelector('.title-box').remove();
          document.querySelector('main').insertAdjacentHTML(
            'beforeend', '<aside><h1>Owned article title</h1></aside>'
          );
        })()
      JS
      expect(probe.call).to eq('Owned article title - Publisher')
      page.evaluate <<~JS
        (() => {
          const aside = document.querySelector('main > aside');
          if (aside) aside.remove();
          document.querySelector('main').insertAdjacentHTML(
            'afterbegin', '<div class="title-box"><h1>Owned article title</h1></div>'
          );
        })()
      JS

      page.evaluate("document.querySelector('main').insertAdjacentHTML('beforeend', '<aside><h1>Unrelated navigation</h1></aside>')")
      expect(probe.call).to eq('Owned article title - Publisher')
      page.evaluate("(() => { const aside = document.querySelector('main > aside'); if (aside) aside.remove(); })()")

      page.evaluate("document.querySelector('main').insertAdjacentHTML('beforeend', '<article><h1>Related article</h1><p>Separate material.</p></article>')")
      expect(probe.call).to eq('Owned article title - Publisher')
      page.evaluate("document.querySelector('main > article:last-of-type').remove()")

      page.evaluate(
        "document.querySelector('main > .article-bar-top').insertAdjacentHTML('beforebegin', " \
        "'<section><h2>Editorial note</h2><p>This material belongs to another record.</p></section>')"
      )
      expect(probe.call).to eq('Owned article title - Publisher')
      page.evaluate("document.querySelector('main > section').remove()")

      page.evaluate(
        "document.querySelector('main article').insertAdjacentHTML('beforeend', " \
        "'<article><h1>Nested foreign record</h1><p>Separate record content.</p></article>')"
      )
      expect(probe.call).to eq('Owned article title - Publisher')
      page.evaluate("document.querySelector('main article article').remove()")

      expect(probe.call('Contradictory title - Publisher')).to eq('Contradictory title - Publisher')
    end
  end

  it 'does not promote an H2 when multiple articles or a different title undermine ownership' do
    html = <<~HTML
      <html><head><title>Getting started</title></head><body><main>
        <article><h1>Getting started</h1><p>The first independent project explains setup in detail.</p><p>It also documents the complete local build process.</p></article>
        <article><h1>Related guide</h1><p>A different article introduces another workflow.</p></article>
      </main></body></html>
    HTML

    with_url_page('https://docs.example/getting-started', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, 'websieve', entry))
      end.join("\n")
      page.add_script_tag(content: source.sub('})(window);', 'global.readerHeadingProbe = sourceOwnedReaderHeadlineContent; })(window);'))
      selected = '<article><h2>Getting started</h2><p>The first independent project explains setup in detail.</p>' \
                 '<p>It also documents the complete local build process.</p></article>'
      candidate = { html: selected, title: 'Getting started', contentType: 'article', readerMode: true }
      expect(page.evaluate("readerHeadingProbe(#{JSON.generate(candidate)})").fetch('html')).to eq(selected)
      page.evaluate("document.querySelectorAll('main article')[1].remove()")
      expect(page.evaluate("readerHeadingProbe(#{JSON.generate(candidate)})").fetch('html')).to include('<h1>Getting started</h1>')
      page.evaluate("document.body.insertAdjacentHTML('beforeend', '<article><h1>Another source</h1></article>')")
      expect(page.evaluate("readerHeadingProbe(#{JSON.generate(candidate)})").fetch('html')).to eq(selected)
      page.evaluate("document.body.lastElementChild.remove()")
      different_title = candidate.merge(title: 'Another guide')
      expect(page.evaluate("readerHeadingProbe(#{JSON.generate(different_title)})").fetch('html')).to eq(selected)
    end
  end
end
