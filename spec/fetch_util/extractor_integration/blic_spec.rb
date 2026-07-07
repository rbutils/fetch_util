# frozen_string_literal: true

RSpec.describe 'FetchUtil Blic extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Blic article bodies without article chrome or mismatch warnings' do
    html = File.read(File.expand_path('../../fixtures/blic_article.html', __dir__))
    url = 'https://www.blic.rs/vesti/drustvo/dramaticno-upozorenje-mup-a-sve-ce-da-vrvi-od-policije-sirom-srbije-pojacava-se/44pr4w6'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Dve osobe dnevno u proseku izgube zivot na putevima')
      expect(payload['markdown']).to include('Pojacana kontrola saobracaja u Srbiji')
      expect(payload['markdown']).not_to include('Slusaj vest')
      expect(payload['markdown']).not_to include('Najnovije vesti')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end

  it 'classifies the Blic homepage as a story list instead of an article' do
    cards = Array.new(5) do |index|
      <<~CARD
        <article class="news news--small">
          <h2><a href="/vesti/drustvo/velika-vest-sa-naslovne-strane-blica-broj-#{index}/44pr4w#{index}">Velika vest sa naslovne strane Blica broj #{index + 1}</a></h2>
          <p>Detalj za naslovnu vest koji opisuje temu i odvaja pravu karticu od navigacije.</p>
        </article>
      CARD
    end.join

    html = <<~HTML
      <html lang="sr">
        <head><title>Blic | Vesti dana iz Srbije, regiona i sveta</title><meta property="og:site_name" content="Blic"></head>
        <body>
          <header><nav><a href="/vesti">Vesti</a><a href="/sport">Sport</a></nav></header>
          <main><section class="section">#{cards}</section></main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.blic.rs/', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['markdown']).to include('Velika vest sa naslovne strane Blica broj 1')
      expect(payload['markdown']).not_to include('[Vesti]')
      expect(payload['warnings']).not_to include('url_content_mismatch')
    end
  end
end
