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
      different_title = candidate.merge(title: 'Another guide')
      expect(page.evaluate("readerHeadingProbe(#{JSON.generate(different_title)})").fetch('html')).to eq(selected)
    end
  end
end
