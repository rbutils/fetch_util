# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Agora/Wyborcza articles' do
  include_context 'extractor integration helpers'

  it 'extracts the Wyborcza public article teaser behind the AdBlock shell and keeps the paywall warning' do
    html = fixture_contents(File.expand_path('../../fixtures/agora_wyborcza_article.html', __dir__))

    extract_from_url('https://kalisz.wyborcza.pl/kalisz/7,181359,32893183,co-dwie-godziny-pociag-do-berlina-co-godzine-do-warszawy-cpk.html', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Linia "Igrek" Kolei Dużych Prędkości ma powstać do 2035 roku')
      expect(payload['markdown']).to include('Powstanie tu estakada obwodnicy Kolei Dużych Prędkości')
      expect(payload['markdown']).not_to include('Wyłącz AdBlocka')
      expect(payload['markdown']).not_to include('putBanDFP')
      expect_warnings(payload, include: 'paywall_partial_content', exclude: %w[truncated_content url_content_mismatch consent_interstitial])
    end
  end

  it 'extracts free Gazeta.pl article bodies without AdBlock or paywall false positives' do
    html = <<~HTML
      <html lang="pl">
        <head>
          <title>Rozmowa o pracy i rodzinie</title>
          <meta property="og:site_name" content="Gazeta.pl">
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "NewsArticle",
              "headline": "Rozmowa o pracy i rodzinie",
              "datePublished": "2026-06-24T17:42:00+02:00"
            }
          </script>
        </head>
        <body>
          <div id="info-adblock"><h1>Wyłącz AdBlocka/uBlocka</h1></div>
          <main>
            <section class="main_wrapper">
              <div class="top_section">
                <div class="article-title-wrapper"><h1>Rozmowa o pracy i rodzinie</h1></div>
                <div class="author_section">24 czerwca 2026, 17:42</div>
                <div class="business_type_label">ZAWIERA PŁATNĄ WSPÓŁPRACĘ</div>
                <div id="gazeta_article_lead">Jesteś bardzo blisko związana ze swoimi rodzicami i rodziną.</div>
                <div id="article-gallery">
                  <figure>
                    <img src="/img/ewa.jpg" alt="Ewa Chodakowska">
                    <figcaption>Gazeta.pl</figcaption>
                  </figure>
                  <button type="button">Otwórz galerię</button>
                </div>
              </div>
              <div class="bottom_section">
                <section class="art_content">
                <p>Nie ukrywam, że ostatnio pracujemy razem i to jest trudne, bo tematy się nie kończyły.</p>
                <p>Nie było urodzin, uroczystości, rocznic, wakacji ani świąt Bożego Narodzenia bez pracy.</p>
                <script>putBanDFP({slot: "007-CONTENTBOARD"})</script>
                <p>Potrafiliśmy stworzyć coś uniwersalnego, co sprawdzało się na bardzo szeroką skalę.</p>
                  <div class="related-links"><a href="/kobieta/polecane">Polecany artykuł</a></div>
                </section>
              </div>
            </section>
            <aside class="right_rail">Wybór redakcji</aside>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://kobieta.gazeta.pl/kobieta/7,201097,32869586,nie-bylo-urodzin-rocznic-ani-swiat-bez-pracy-te-tematy-sie.html', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Rozmowa o pracy i rodzinie')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to eq('2026-06-24T17:42:00+02:00')
      expect(payload['markdown']).to include('ZAWIERA PŁATNĄ WSPÓŁPRACĘ')
      expect(payload['markdown']).to include('Jesteś bardzo blisko związana ze swoimi rodzicami')
      expect(payload['markdown']).to include('![Ewa Chodakowska](https://kobieta.gazeta.pl/img/ewa.jpg)')
      expect(payload['markdown']).to include('Gazeta.pl')
      expect(payload['markdown']).to include('Nie było urodzin, uroczystości, rocznic')
      expect(payload['markdown']).not_to include('Wyłącz AdBlocka')
      expect(payload['markdown']).not_to include('putBanDFP')
      expect(payload['markdown']).not_to include('Otwórz galerię')
      expect(payload['markdown']).not_to include('Polecany artykuł')
      expect(payload['markdown']).not_to include('Wybór redakcji')
      expect_warnings(payload, exclude: %w[paywall_partial_content truncated_content url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
