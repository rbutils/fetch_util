# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Aktuality.sk articles' do
  include_context 'extractor integration helpers'

  it 'extracts public Aktuality article bodies without shop and recommendation chrome' do
    html = <<~HTML
      <html lang="sk">
        <head>
          <title>Republike hrozí vyšetrovanie zo strany Európskej únie. Obviňujú ich z nenávisti a chcú im odobrať peniaze</title>
          <meta property="og:site_name" content="Aktuality.sk">
          <link rel="canonical" href="https://www.aktuality.sk/clanok/1SfqLZq/republike-hrozi-vysetrovanie-zo-strany-europskej-unie-obvinuju-ich-z-nenavisti-a-chcu-im-odobrat-peniaze/">
        </head>
        <body>
          <main>
            <article id="article">
              <h1 id="article-headline" itemprop="headline"><span>Republike hrozí vyšetrovanie zo strany Európskej únie. Obviňujú ich z nenávisti a chcú im odobrať peniaze</span></h1>
              <div id="article-content" class="article-content">
                <div class="save-article">Uložiť článok</div>
                <div id="perex-id" class="article-perex introtext">
                  <div id="bw_premium_article" class="beyondwords-player">Listen to this article 6 min</div>
                  <span itemprop="description">Takmer 300-stranová správa bruselského úradu opisuje nenávistný slovník a kontakty na Rusko. Vyšetrovanie môže ESN pripraviť o milióny z európskych peňazí.</span>
                </div>
                <div itemprop="articleBody" id="articleContent">
                  <div id="tp-inline-template"><div class="tp-container-inner"><iframe src="https://buy-eu.piano.io/checkout/template/cacheableShow.html"></iframe></div></div>
                  <p>Európsky parlament dnes v Štrasburgu rozhodoval o spustení oficiálneho vyšetrovania euroskeptickej strany Európa suverénnych národov (ESN), ktorej členom je aj slovenské hnutie Republika.</p>
                  <p>Dôvodom sú vážne podozrenia z porušovania základných hodnôt Európskej únie, ku ktorým patrí úcta k ľudskej dôstojnosti, demokracii a právam menšín.</p>
                  <div class="article-object article-object-link"><strong>Prečítajte si tiež:</strong><a href="/clanok/related">Mazurekove nadávky môžu pripraviť európsku krajnú pravicu o peniaze</a></div>
                  <p>Europoslanci návrh na vyšetrovanie schválili v tajnom hlasovaní počtom 414 hlasov za a 224 hlasov proti. Osemnásť poslancov sa zdržalo hlasovania.</p>
                </div>
              </div>
            </article>
            <aside>
              <a href="https://obchod.aktuality.sk/radicova">Radičová</a>
              <a href="https://obchod.aktuality.sk/kniha-fico-2/">Fico - Posadnutý pomstou</a>
            </aside>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.aktuality.sk/clanok/1SfqLZq/republike-hrozi-vysetrovanie-zo-strany-europskej-unie-obvinuju-ich-z-nenavisti-a-chcu-im-odobrat-peniaze/'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Takmer 300-stranová správa bruselského úradu')
      expect(payload['markdown']).to include('Európsky parlament dnes v Štrasburgu rozhodoval')
      expect(payload['markdown']).not_to include('Radičová')
      expect(payload['markdown']).not_to include('Posadnutý pomstou')
      expect(payload['markdown']).not_to include('Listen to this article')
      expect(payload['markdown']).not_to include('Prečítajte si tiež')
      expect(payload['markdown']).not_to include('piano.io')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page])
    end
  end
end
