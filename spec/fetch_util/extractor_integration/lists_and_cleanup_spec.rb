# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "collapses list pages into agent-friendly bullets" do
    html = <<~HTML
      <html>
        <head><title>Example News</title></head>
        <body>
          <main>
            <table class="itemlist">
              <tr class="athing"><td><a href="https://example.com/a">First story about Ruby agents</a></td></tr>
              <tr><td>120 points | 45 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/b">Second story about fetch pipelines</a></td></tr>
              <tr><td>98 points | 18 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/c">Third story about browser automation</a></td></tr>
              <tr><td>75 points | 9 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/d">Fourth story about markdown cleanup</a></td></tr>
              <tr><td>40 points | 5 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/e">Fifth story about structured extraction</a></td></tr>
              <tr><td>21 points | 2 comments</td></tr>
              <tr class="athing"><td><a href="https://example.com/f">Sixth story about heuristics</a></td></tr>
              <tr><td>19 points | 1 comment</td></tr>
              <tr class="athing"><td><a href="https://example.com/g">Seventh story about ranking content</a></td></tr>
              <tr><td>11 points | discuss</td></tr>
              <tr class="athing"><td><a href="https://example.com/h">Eighth story about content types</a></td></tr>
              <tr><td>8 points | discuss</td></tr>
            </table>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ft.com/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["readerMode"]).to eq(false)
      expect(payload["markdown"]).to include("- [First story about Ruby agents](https://example.com/a)")
      expect(payload["markdown"]).not_to include("<table")
    end
  end

  it "keeps opaque id detail pages as articles and collapses duplicated responsive prose" do
    plot = "After a banker is sentenced to life in Shawshank Prison, " \
           "he forms an unlikely friendship with a seasoned inmate and clings to hope amid cruelty and corruption."
    html = <<~HTML
      <html>
        <head><title>The Shawshank Redemption - Example Movies</title></head>
        <body>
          <main>
            <h1>The Shawshank Redemption</h1>
            <p data-testid="plot">
              <span role="presentation" data-testid="plot-xs_to_m"><span>#{plot}</span></span>
              <span role="presentation" data-testid="plot-l"><span>#{plot}</span></span>
              <span role="presentation" data-testid="plot-xl"><span>#{plot}</span></span>
            </p>
            <section>
              <h2>Top Cast</h2>
              <a href="/name/nm0000209/">Tim Robbins</a>
              <a href="/name/nm0000151/">Morgan Freeman</a>
              <a href="/name/nm0348409/">Bob Gunton</a>
            </section>
            <section>
              <h2>User Reviews</h2>
              <a href="/title/tt0111161/reviews/?featured=rw1">Prepare to be moved</a>
              <a href="/title/tt0111161/reviews/?featured=rw2">This is how movies should be made</a>
              <a href="/title/tt0111161/reviews/?featured=rw3">Eternal Hope</a>
            </section>
            <section>
              <h2>More Like This</h2>
              <a href="/title/tt0068646/">The Godfather</a>
              <a href="/title/tt0108052/">Schindler's List</a>
              <a href="/title/tt0110912/">Pulp Fiction</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.example-movies.test/title/tt0111161/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"].scan(plot).length).to eq(1)
      expect(payload["markdown"]).to include("Top Cast")
    end
  end

  it "removes cookie dialog chrome when real pinterest results are present" do
    html = <<~HTML
      <html>
        <head><title>Pinterest</title></head>
        <body>
          <div role="dialog" aria-modal="true" class="cookie-modal">
            <h2>Cookie Settings</h2>
            <p>We use cookies to personalize advertising and measure performance.</p>
            <button>Accept all cookies</button>
          </div>
          <main>
            <a href="/pin/1/" aria-label="ruby programming poster with examples"></a>
            <a href="/pin/2/" aria-label="ruby cheatsheet for arrays and hashes"></a>
            <a href="/pin/3/" aria-label="ruby metaprogramming diagram and notes"></a>
            <a href="/pin/4/" aria-label="ruby on rails guide for forms"></a>
            <a href="/pin/5/" aria-label="ruby blocks and enumerators visual guide"></a>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.pinterest.com/search/pins/?q=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("ruby programming poster with examples")
      expect(payload["warnings"]).not_to include("consent_interstitial")
      expect(payload["markdown"]).not_to include("Cookie Settings")
    end
  end

  it "prefers repeated homepage cards over footer stubs on portal-like homepages" do
    html = <<~HTML
      <html>
        <head><title>CalcioMercato</title></head>
        <body>
          <main>
            <section class="hero-grid">
              <article class="news-card"><h2><a href="/news/a">Milan accelera sul nuovo attaccante</a></h2><p>Dettagli sul vertice di mercato.</p></article>
              <article class="news-card"><h2><a href="/news/b">Inter prepara l'offerta per il centrocampista</a></h2><p>Le cifre dell'operazione.</p></article>
              <article class="news-card"><h2><a href="/news/c">Napoli studia due rinforzi in difesa</a></h2><p>I nomi in lista.</p></article>
              <article class="news-card"><h2><a href="/news/d">Juventus, dialoghi aperti per il rinnovo</a></h2><p>Ultimi aggiornamenti.</p></article>
            </section>
          </main>
          <footer>
            <p>Copyright 2026 CalcioMercato</p>
            <a href="/privacy">Privacy</a>
          </footer>
        </body>
      </html>
    HTML

    with_url_page("https://www.calciomercato.com/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("Milan accelera sul nuovo attaccante")
      expect(payload["markdown"]).not_to include("Copyright 2026")
    end
  end

  it "keeps short CJK card titles when building list markdown" do
    html = <<~HTML
      <html>
        <head><title>中国社会科学网</title></head>
        <body>
          <main>
            <article><h2><a href="/a">办好人民满意的教育</a></h2><p>教育是国之大计。</p></article>
            <article><h2><a href="/b">推进中国式现代化</a></h2><p>理论研究持续深化。</p></article>
            <article><h2><a href="/c">建设哲学社会科学</a></h2><p>学术成果不断涌现。</p></article>
            <article><h2><a href="/d">文化传承与创新</a></h2><p>传统与现代结合。</p></article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("办好人民满意的教育")
      expect(payload["markdown"]).to include("文化传承与创新")
    end
  end

  it "downgrades homepage card grids to list mode even when about text is long" do
    html = <<~HTML
      <html>
        <head><title>Calciomercato Live: News, Trattative e Trasferimenti</title></head>
        <body>
          <header>
            <nav>
              <a href="/privacy">Privacy</a>
              <a href="/chi-siamo">Chi siamo</a>
            </nav>
          </header>
          <section class="news-grid">
            <article class="news-card"><h2><a href="/news/a">Marotta manda un messaggio alla squadra</a></h2><p>Ultime dichiarazioni e retroscena.</p></article>
            <article class="news-card"><h2><a href="/news/b">Milan, cessione da 24 milioni a un passo</a></h2><p>Accordo vicino per il trasferimento.</p></article>
            <article class="news-card"><h2><a href="/news/c">Lukaku verso l'addio: spunta una nuova destinazione</a></h2><p>Il club valuta la prossima mossa.</p></article>
            <article class="news-card"><h2><a href="/news/d">Kessie torna nel mirino di Inter e Juve</a></h2><p>Le ultime sul duello di mercato.</p></article>
          </section>
          <section class="about-box">
            <h2>Chi siamo</h2>
            <p>Calciomercato.it e' una testata giornalistica dedicata all'informazione calcistica con news, approfondimenti, video e aggiornamenti sul mercato italiano ed estero.</p>
            <p>Il sito e' il prodotto di punta di una realta' editoriale digitale specializzata nella copertura quotidiana di Serie A, coppe e trasferimenti.</p>
            <p>Il gruppo sviluppa contenuti editoriali, social e multimediali rivolti a tifosi, appassionati e addetti ai lavori.</p>
            <p>La redazione segue club italiani e campionati internazionali con focus su trattative, interviste e analisi.</p>
            <p>Copyright 2026 - Tutti i diritti riservati.</p>
          </section>
        </body>
      </html>
    HTML

    with_url_page("https://www.calciomercato.it/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["markdown"]).to include("Marotta manda un messaggio alla squadra")
      expect(payload["markdown"]).to include("Kessie torna nel mirino di Inter e Juve")
      expect(payload["markdown"]).not_to include("Calciomercato.it e' una testata")
      expect(payload["markdown"]).not_to include("Chi siamo")
    end
  end

  it "cleans malformed markdown from image-led card grids" do
    html = <<~HTML
      <html>
        <head><title>Daily Section</title></head>
        <body>
          <main>
            <article>
              <h1>Daily Section</h1>
              <p>Lead coverage and analysis from the day.</p>
              <ul class="card-grid">
                <li>
                  <a href="/world/one">
                    <img src="/one.jpg" alt="">
                    <h3>First headline from the card grid</h3>
                  </a>
                </li>
                <li>
                  <a href="/world/two">
                    <img src="/two.jpg" alt="Reporter at border [US side.]">
                    <h3>Second headline from the card grid</h3>
                  </a>
                </li>
              </ul>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/international", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("- [First headline from the card grid](https://example.test/world/one)")
      expect(payload["markdown"]).to include("- [Second headline from the card grid](https://example.test/world/two)")
      expect(payload["markdown"]).not_to include("- !###")
      expect(payload["markdown"]).not_to match(/\]\([^)]*\)\]/)
    end
  end

  it "cleans orphan bracket fragments from nested card-grid links" do
    html = <<~HTML
      <html>
        <head><title>Mission Cards</title></head>
        <body>
          <main>
            <article>
              <h1>Mission Cards</h1>
              <section class="card-grid">
                <div class="card">
                  <a href="/facts"><img src="/folding.jpg" alt=""></a>
                  <div>
                    <a href="/facts"><h3>Folding Design</h3></a>
                    <p>So big it has to fold origami-style to fit in the rocket.</p>
                  </div>
                </div>
                <div class="card">
                  <a href="/blog/one"><figure><img src="/one.jpg" alt=""></figure></a>
                  <div>
                    <a href="/blog/one"><p>Webb Detects Methane on Interstellar Comet</p></a>
                    <p>A short science update from the observatory.</p>
                  </div>
                </div>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://science.example/mission/webb/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("### [Folding Design](https://science.example/facts)")
      expect(markdown).to include("[Webb Detects Methane on Interstellar Comet](https://science.example/blog/one)")
      expect(markdown).not_to match(/^\s*\[\s*$/)
      expect(markdown).not_to match(%r{^\s*\]\(https?://[^)]+\)\[?\s*$})
    end
  end

  it "does not repeat sibling docs card text in every list item" do
    html = <<~HTML
      <html>
        <head><title>Hugo Documentation</title></head>
        <body>
          <main>
            <section class="docs-grid">
                <a class="a--block group border" href="/about/"><h3>About</h3><p>Learn about Hugo and its features, privacy protections, and security model.</p></a>
                <a class="a--block group border" href="/commands/"><h3>CLI</h3><p>Use the command line interface (CLI) to manage your project.</p></a>
                <a class="a--block group border" href="/configuration/"><h3>Configuration</h3><p>Configure your site.</p></a>
                <a class="a--block group border" href="/content-management/"><h3>Content management</h3><p>Hugo makes managing large static sites easy with support for archetypes, content types, menus, cross references, summaries, and more.</p></a>
                <a class="a--block group border" href="/contribute/"><h3>Contribute</h3><p>Contribute to development, documentation, and themes.</p></a>
                <a class="a--block group border" href="/tools/"><h3>Developer tools</h3><p>Third-party tools to help you create and manage sites.</p></a>
                <a class="a--block group border" href="/functions/"><h3>Functions</h3><p>Use these functions within your templates and archetypes.</p></a>
                <a class="a--block group border" href="/getting-started/"><h3>Getting started</h3><p>How to get started with Hugo.</p></a>
                <a class="a--block group border" href="/host-and-deploy/"><h3>Host and deploy</h3><p>Services and tools to host and deploy your site.</p></a>
                <a class="a--block group border" href="/hugo-modules/"><h3>Hugo modules</h3><p>Use Hugo modules to manage the content, presentation, and behavior of your site.</p></a>
                <a class="a--block group border" href="/hugo-pipes/"><h3>Hugo Pipes</h3><p>Use asset pipelines to transform and optimize images, stylesheets, and JavaScript.</p></a>
                <a class="a--block group border" href="/installation/"><h3>Installation</h3><p>Install Hugo on macOS, Linux, Windows, BSD, and on any machine that can run the Go compiler tool chain.</p></a>
                <a class="a--block group border" href="/methods/"><h3>Methods</h3><p>Use these methods within your templates.</p></a>
                <a class="a--block group border" href="/quick-reference/"><h3>Quick reference</h3><p>Use these quick reference guides for quick access to key information.</p></a>
                <a class="a--block group border" href="/render-hooks/"><h3>Render hooks</h3><p>Create render hook templates to override the rendering of Markdown to HTML.</p></a>
                <a class="a--block group border" href="/shortcodes/"><h3>Shortcodes</h3><p>Insert elements such as videos, images, and social media embeds into your content using Hugo's embedded shortcodes.</p></a>
                <a class="a--block group border" href="/templates/"><h3>Templates</h3><p>Create templates to render your content, resources, and data.</p></a>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://gohugo.io/", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("Content management")
      expect(markdown).to include("Hugo makes managing large static sites easy")
      expect(markdown.scan("Content management").length).to be <= 2
      expect(markdown.scan("Hugo modules").length).to be <= 2
      expect(markdown).not_to include("AboutLearn about Hugo")
    end
  end

  it "does not duplicate nested layout table content when converting comments" do
    html = <<~HTML
      <html>
        <head><title>Example thread</title></head>
        <body>
          <center>
            <table id="hnmain">
              <tr><td>
                <table><tr><td><span class="pagetop"><b>Hacker News</b><a href="/newest">new</a> | <a href="/front">past</a></span></td></tr></table>
              </td></tr>
              <tr><td>
                <table class="fatitem">
                  <tr class="athing submission" id="1"><td class="title"><span class="titleline"><a href="http://ycombinator.com/">Y Combinator</a></span></td></tr>
                  <tr><td class="subtext"><span class="score">57 points</span> by <a class="hnuser">pg</a> <span class="age">on Oct 9, 2006</span> | <a>3 comments</a></td></tr>
                </table>
                <table class="comment-tree">
                  <tr class="athing comtr" id="15"><td><table><tr><td class="default"><span class="comhead">sama on Oct 9, 2006 | next [–]</span><div class="comment"><div class="commtext c00">the rising star of venture capital</div></div></td></tr></table></td></tr>
                  <tr class="athing comtr" id="17"><td><table><tr><td class="default"><span class="comhead">pg on Oct 9, 2006 | parent | next [–]</span><div class="comment"><div class="commtext c00">Is there anywhere to eat on Sandhill Road?</div></div></td></tr></table></td></tr>
                  <tr class="athing comtr" id="1079"><td><table><tr><td class="default"><span class="comhead">dmon on Feb 25, 2007 | root | parent | next [–]</span><div class="comment"><div class="commtext c00">sure</div></div></td></tr></table></td></tr>
                </table>
              </td></tr>
            </table>
          </center>
        </body>
      </html>
    HTML

    with_url_page("https://news.ycombinator.com/item?id=1", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"].scan("the rising star of venture capital").length).to eq(1)
      expect(payload["markdown"].scan("Is there anywhere to eat on Sandhill Road?").length).to eq(1)
      expect(payload["markdown"]).not_to include("Hacker Newsnew | past")
    end
  end
end
