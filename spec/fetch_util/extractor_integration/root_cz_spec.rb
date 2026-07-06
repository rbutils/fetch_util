# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration for Root.cz articles' do
  include_context 'extractor integration helpers'

  it 'extracts Root.cz article bodies without comment and action chrome' do
    html = <<~HTML
      <html lang="cs">
        <head>
          <title>Klávesnice osmibitových počítačů Atari: až překvapivě komplikovaná problematika - Root.cz</title>
          <meta property="og:site_name" content="Root.cz">
          <meta name="description" content="Práce s klávesnicí osmibitových domácích mikropočítačů Atari.">
        </head>
        <body class="design-page--root-cz">
          <div class="layout-main main">
            <nav><a href="/clanky/">Články</a><a href="/zpravicky/">Zprávičky</a></nav>
            <div class="design-tile">
              <h1 class="design-title">Klávesnice osmibitových počítačů Atari: až překvapivě komplikovaná problematika</h1>
              <div class="design-impressum">
                <a class="design-impressum__author" href="/autori/pavel-tisnovsky/">Pavel Tišnovský</a>
                <div class="design-impressum__cell--additional">
                  <span class="comments__count comments__count--new">Počet nových komentářů 1</span>
                  <a class="comments__link">PŘIDEJTE NÁZOR</a>
                  <div class="support-box">Líbí se vám článek? Podpořte redakci</div>
                  <ul class="design-list--social-networks-share"><li>Sdílet</li><li>Sdílejte na Facebooku</li></ul>
                </div>
              </div>
              <div class="mdl-article-perex">
                <div class="design-article__text">
                  <p>U mnoha typů počítačů je práce s klávesnicí mnohdy až absurdně komplikovaná.</p>
                  <a href="https://news.google.com/">Přidat mezi oblíbené zdroje na Googlu</a>
                </div>
              </div>
              <div class="detail__article">
                <div class="layout-article-content">
                  <p>V dnešním článku se budeme věnovat zdánlivě jednoduchému tématu, kterým je práce s klávesnicí osmibitových domácích mikropočítačů Atari.</p>
                  <p>Ve skutečnosti se však jedná o dosti komplikované téma, protože některé klávesy jsou zapojeny a zpracovávány specifickým způsobem.</p>
                  <div class="design-advert-placeholder--article-intext-1">REKLAMA Baterka v telefonu nevydrží celý výlet.</div>
                  <h2>Rozdělení kláves do skupin na základě jejich funkce a zapojení</h2>
                  <p>Standardní klávesy se používaly při programování, v textových editorech, v tabulkovém procesoru VisiCalc a také v dalších aplikacích.</p>
                  <p>Klávesy Start, Select a Option se ovšem čtou jinak než běžné klávesy v matici, takže demonstrační program musí kombinovat více registrů.</p>
                </div>
              </div>
              <div class="b-thumbs-rating-wrap">BYL PRO VÁS ČLÁNEK PŘÍNOSNÝ? +1 Líbí Nelíbí</div>
              <div class="comments comments--detail"><a>PŘIDEJTE NÁZOR</a></div>
            </div>
          </div>
        </body>
      </html>
    HTML

    url = 'https://www.root.cz/clanky/klavesnice-osmibitovych-pocitacu-atari-az-prekvapive-komplikovana-problematika/'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('práce s klávesnicí osmibitových domácích mikropočítačů Atari')
      expect(payload['markdown']).to include('Klávesy Start, Select a Option se ovšem čtou jinak')
      expect(payload['markdown']).not_to include('Počet nových komentářů')
      expect(payload['markdown']).not_to include('PŘIDEJTE NÁZOR')
      expect(payload['markdown']).not_to include('Líbí se vám článek')
      expect(payload['markdown']).not_to include('Podpořte redakci')
      expect(payload['markdown']).not_to include('Sdílet')
      expect(payload['markdown']).not_to include('REKLAMA')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
    end
  end
end
