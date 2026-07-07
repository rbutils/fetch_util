# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Interia articles' do
  include_context 'extractor integration helpers'

  it 'extracts Interia article bodies without reaction, audio, and related chrome' do
    html = <<~HTML
      <html lang="pl">
        <head>
          <title>Polska podpisała porozumienie ws. Patriotów. "Bardzo się mylą" - Interia</title>
          <meta property="og:site_name" content="Interia Wydarzenia">
          <meta name="description" content="Polska podpisała porozumienie dotyczące pocisków Patriot.">
        </head>
        <body>
          <article data-component-0="article" class="article-container">
            <header>
              <h1>Polska podpisała porozumienie ws. Patriotów. "Bardzo się mylą"</h1>
              <div data-component-0="page-info">
                <div data-icon="like"><span>Lubię to</span><img src="https://js.iplsc.com/inpl.emotion/latest/like.svg" alt="like"></div>
                <div data-icon="angry"><span>Zły</span><img src="https://js.iplsc.com/inpl.emotion/latest/angry.svg" alt="angry"></div>
              </div>
              <p data-component-0="paragraph" data-component-1="body" class="ids-paragraph--lead">
                Polska podpisała porozumienie z USA, Niemcami, Holandią oraz Szwecją w sprawie utworzenia w Europie centrum serwisowania pocisków PAC-3 do systemów Patriot.
              </p>
              <div data-component-0="wrapper-group" class="audio-news-player ids-audio-news-player">
                <p>Odsłuchaj artykuł</p>
                <p>02:32 min</p>
                <p>Audio generowane przez AI, może zawierać błędy</p>
              </div>
            </header>
            <div data-component-0="article-content">
              <div data-component-0="contents-list" class="contents-list">
                <h2>W skrócie</h2>
                <ul>
                  <li>Podpisano porozumienie dotyczące utworzenia w Europie centrum serwisowania pocisków PAC-3.</li>
                  <li>Minister obrony narodowej poinformował, że porozumienie przyspieszy serwisowanie pocisków.</li>
                </ul>
              </div>
              <p>Szef MON stwierdził, że porozumienie znacznie zwiększy moce oraz przyspieszy produkcję i serwis pocisków.</p>
              <p>"Tym, którzy od kilku dni straszą, że Polska traci zdolności obronne, udowadniamy, jak bardzo się mylą" - napisał minister.</p>
              <section data-component-0="article-list" class="ids-article-list-section-wrapper">
                <h2>Zobacz również:</h2>
                <article><h2>Przełom ws. rakiet Patriot? Media: Polska podpisze oświadczenie</h2></article>
              </section>
              <p>Podczas szczytu NATO podpisywane są też dokumenty dotyczące pocisków FIM-92 Stinger.</p>
              <div data-component-0="ad-rectangle" class="ids-ads-base">REKLAMA</div>
            </div>
          </article>
        </body>
      </html>
    HTML

    url = 'https://wydarzenia.interia.pl/kraj/news-polska-podpisala-porozumienie-ws-patriotow-bardzo-sie-myla,nId,23510737'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Polska podpisała porozumienie z USA, Niemcami, Holandią oraz Szwecją')
      expect(payload['markdown']).to include('udowadniamy, jak bardzo się mylą')
      expect(payload['markdown']).to include('Podczas szczytu NATO podpisywane są też dokumenty')
      expect(payload['markdown']).not_to include('Lubię to')
      expect(payload['markdown']).not_to include('like.svg')
      expect(payload['markdown']).not_to include('Odsłuchaj artykuł')
      expect(payload['markdown']).not_to include('Audio generowane przez AI')
      expect(payload['markdown']).not_to include('Zobacz również')
      expect(payload['markdown']).not_to include('REKLAMA')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
