# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration for Agora/Wyborcza articles' do
  include_context 'extractor integration helpers'

  it 'extracts the Wyborcza public article teaser behind the AdBlock shell and keeps the paywall warning' do
    html = fixture_contents(File.expand_path('../../fixtures/agora_wyborcza_article.html', __dir__))

    extract_from_url('https://kalisz.wyborcza.pl/kalisz/7,181359,32893183,co-dwie-godziny-pociag-do-berlina-co-godzine-do-warszawy-cpk.html', html) do |payload|
      expect_content_type(payload, 'article')
      source = Nokogiri::HTML(html)
      expect(payload['title']).to eq(source.at_css('main h1').text)
      expect(payload['byline']).to eq('Janusz Jaros')
      expect(payload['markdown']).to include('06.07.2026, 19:05')
      source.css('.mrf-article-body p').each { |paragraph| expect(payload['markdown']).to include(paragraph.text) }
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
      expect(payload['excerpt']).to eq('Jesteś bardzo blisko związana ze swoimi rodzicami i rodziną.')
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

  it 'keeps owned extended headlines and localized access offers distinct from hidden or quoted promotions' do
    html = <<~HTML
      <main>
        <header><h1>Transport planning. Additional routes serve the region</h1><p>07.10.2026, 12:30</p></header>
        <article>
          <p>Planning teams published the timetable and explained how the regional routes connect.</p>
          <div class="content-fadeout">
            <p>Residents reviewed the proposed connections and raised questions about the construction schedule.</p>
            <p>The published report records those questions and the agency responses without omitting the public detail.</p>
          </div>
        </article>
        <section class="subscription-offer">Wybierz prenumeratę, by czytać dalszą część <button>Sprawdź ofertę</button></section>
      </main>
    HTML
    document = "<html><head><title>Transport planning</title></head><body>#{html}</body></html>"
    extract_from_url('https://regional.example/story/transport', document) do |payload|
      expect(payload['title']).to eq('Transport planning. Additional routes serve the region')
      expect(payload['markdown']).to include('07.10.2026, 12:30')
      expect(payload['markdown']).to include('The published report records those questions')
      expect_warnings(payload, include: 'paywall_partial_content')
    end
    [html.sub('class="content-fadeout"', 'class="unlocked-content"'),
     html.sub('class="subscription-offer"', 'class="subscription-offer" hidden'),
     html.sub('<section class="subscription-offer">', '<blockquote><section class="subscription-offer">')
         .sub('</section>', '</section></blockquote>')].each do |negative|
      extract_from_url('https://regional.example/story/transport', "<html><head><title>Transport planning</title></head>#{negative}</html>") do |payload|
        expect_warnings(payload, exclude: 'paywall_partial_content')
      end
    end
  end

  it 'uses a uniquely owned marked intro without adopting an unrelated newsletter lead' do
    html = <<~HTML
      <html><head><title>Evidence from field measurements</title></head><body>
        <article><h1>Evidence from field measurements</h1>
          <div id="story_standfirst">The authored overview explains the complete measurement programme.</div>
          <p>The first report describes the measurement method and the instrument calibration in full.</p>
          <p>The second report explains the observed variations and records the remaining uncertainties.</p>
          <p>The final report identifies the follow-up work and preserves the substantive public conclusions.</p>
        </article>
        <aside><div id="newsletter_lead">Subscribe to our unrelated newsletter for promotional updates.</div></aside>
      </body></html>
    HTML
    extract_from_url('https://field.example/story/evidence', html) do |payload|
      expect(payload['excerpt']).to eq('The authored overview explains the complete measurement programme.')
      expect(payload['markdown']).to include('The final report identifies the follow-up work')
      expect(payload['excerpt']).not_to include('newsletter')
    end
  end
end
