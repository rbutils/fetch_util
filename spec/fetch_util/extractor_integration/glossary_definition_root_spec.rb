# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "surfaces dictionary definitions and dedupes repeated senses" do
    html = <<~HTML
      <html>
        <head>
          <title>Definition of lantern | Example Dictionary</title>
          <meta property="og:site_name" content="Example Dictionary">
          <meta name="description" content="Definition of lantern: a portable lamp with a protective case.">
        </head>
        <body>
          <nav>Browse nearby words Word of the day Top lookups</nav>
          <main>
            <h1>lantern</h1>
            <section class="entry senses">
              <p class="term">lantern</p>
              <p class="desc">A portable lamp with a protective case and transparent sides.</p>
              <p class="desc">A portable lamp with a protective case and transparent sides.</p>
              <p class="desc">A room at the top of a lighthouse containing the light.</p>
            </section>
          </main>
          <aside>Cite this entry Browse nearby words Popular in grammar</aside>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/dictionary/lantern", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("# lantern")
      expect(markdown.scan("A portable lamp with a protective case and transparent sides").size).to eq(1)
      expect(markdown).to include("A room at the top of a lighthouse containing the light")
      expect(markdown).not_to include("Browse nearby words")
      expect(markdown).not_to include("Cite this entry")
    end
  end

  it "keeps citation database definitions while dropping source and reference noise" do
    html = <<~HTML
      <html>
        <head>
          <title>Alembic definition - Reference Database</title>
          <meta property="og:site_name" content="Reference Database">
          <meta property="og:type" content="website">
        </head>
        <body>
          <header>Reference home Search Browse by source</header>
          <main>
            <article class="database-entry definition-record">
              <h1>Alembic</h1>
              <div class="source-panel">Sources References Citation MLA APA Chicago Export BibTeX</div>
              <dl>
                <dt>noun</dt>
                <dd>A distilling apparatus formerly used in alchemy.</dd>
                <dd>A distilling apparatus formerly used in alchemy.</dd>
                <dd>Something that refines, transforms, or purifies.</dd>
              </dl>
            </article>
          </main>
          <footer>Cited by Reference links Browse database Citation tools</footer>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/reference/alembic", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("# Alembic")
      expect(markdown.scan("A distilling apparatus formerly used in alchemy").size).to eq(1)
      expect(markdown).to include("Something that refines, transforms, or purifies")
      expect(markdown).not_to include("Export BibTeX")
      expect(markdown).not_to include("Citation tools")
    end
  end

  it "leads with ordered dictionary senses while retaining examples and etymology" do
    html = <<~HTML
      <html>
        <head>
          <title>ruby - Example Dictionary</title>
          <meta property="og:site_name" content="Example Dictionary">
        </head>
        <body>
          <main id="mw-content-text">
            <h1>ruby</h1>
            <p><span class="headword-line"><strong class="headword">ruby</strong> (plural rubies)</span></p>
            <ol>
              <li>A clear, deep, red variety of corundum, valued as a precious stone.
                <ul class="wikt-quote-container"><li>A long quotation about gemstones.</li></ul>
              </li>
              <li>A deep red colour.</li>
              <li>The tincture red or gules.</li>
            </ol>
            <section class="examples"><h2>Examples of ruby in a Sentence</h2><p>The ring contained a ruby.</p></section>
            <section class="etymology"><h2>Etymology</h2><p>Middle English, from Anglo-French rubi.</p></section>
          </main>
          <aside>Word of the Day Top Lookups More from Example Dictionary</aside>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/dictionary/ruby", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("# ruby")
      expect(markdown).to match(/A clear, deep, red variety.*A deep red colour.*The tincture red or gules/m)
      expect(markdown.index("A clear, deep, red variety")).to be < markdown.index("Examples of ruby in a Sentence")
      expect(markdown).to include("Examples of ruby in a Sentence")
      expect(markdown).to include("The ring contained a ruby")
      expect(markdown).to include("Middle English, from Anglo-French")
      expect(markdown).not_to include("Word of the Day")
    end
  end

  it "preserves every accepted pronunciation and definition beyond presentation caps" do
    html = fixture_contents('spec/fixtures/glossary_over_cap.html')

    with_url_page('https://example.test/dictionary/wayfinder', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).to include(
        'regional /ˈweɪˌfaɪndər/', 'An aid used by explorers to maintain a planned course.'
      )
      expect(payload['html']).to include('An aid used by explorers to maintain a planned course.')
      expect(payload['markdown'].index('/weɪfaɪndər/')).to be < payload['markdown'].index('regional /')
      expect(payload['markdown'].index('A person who finds')).to be < payload['markdown'].index('An aid used')
    end
  end

  it "does not claim non-glossary article pages" do
    html = <<~HTML
      <html>
        <head>
          <title>How citation indexes changed research</title>
          <meta name="description" content="A reported article about research tools and scholarly publishing.">
        </head>
        <body>
          <article>
            <h1>How citation indexes changed research</h1>
            <p>Citation indexes began as reference tools, but researchers soon used them to discover relationships between journals, fields, and authors.</p>
            <p>The article explains the history through interviews and archival examples rather than defining a term.</p>
          </article>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/articles/citation-index-history", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("How citation indexes changed research")
      expect(markdown).to include("researchers soon used them to discover relationships")
      expect(markdown).not_to include("A reported article about research tools")
    end
  end
end
