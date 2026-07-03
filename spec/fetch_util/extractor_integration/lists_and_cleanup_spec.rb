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
end
