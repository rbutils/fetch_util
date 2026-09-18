# frozen_string_literal: true

RSpec.describe 'FetchUtil Blic extraction' do
  include_context 'extractor integration helpers'

  let(:article_url) do
    'https://www.blic.rs/vesti/drustvo/dramaticno-upozorenje-mup-a-sve-ce-da-vrvi-od-policije-sirom-srbije-pojacava-se/44pr4w6'
  end

  let(:article_html) { fixture_contents(File.expand_path('../../fixtures/blic_article.html', __dir__)) }
  let(:article_paragraphs) do
    [
      'Od pocetka godine u saobracajnim nezgodama stradalo je 195 osoba',
      'Saobracajna policija pojacava kontrole na svim putevima',
      'Dve osobe dnevno u proseku izgube zivot na putevima',
      'Prema recima pukovnika Dejana Stevica iz Uprave saobracajne policije',
      'On je istakao da posebno zabrinjava podatak',
      'Iako statisticki podaci ukazuju na smanjenje broja poginulih',
      'Tokom juna ove godine na putevima je zivot izgubilo 23 lica',
      'Uprava saobracajne policije nastavlja sa pojacanim kontrolama saobracaja'
    ]
  end

  it 'extracts the complete Blic article through shared reader handling' do
    with_url_page(article_url, article_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')

      expect(payload).to include(
        'title' => 'SVE CE DA VRVI OD POLICIJE SIROM SRBIJE! Dramaticno upozorenje MUP-a Srbije',
        'byline' => 'Teodora Boskovski',
        'siteName' => 'Blic',
        'language' => 'sr',
        'contentType' => 'article',
        'readerMode' => true,
        'hostAware' => false,
        'warnings' => [],
        'suspect' => false
      )
      expect(markdown).to include(
        '[Teodora Boskovski](https://www.blic.rs/autori/teodora-boskovski)',
        'Od pocetka godine 195 osoba izgubilo zivot na putevima',
        'Pojacana kontrola saobracaja u Srbiji',
        *article_paragraphs
      )
      expect(payload.fetch('excerpt')).to include('Od pocetka godine u saobracajnim nezgodama')
      positions = article_paragraphs.map { |text| markdown.index(text) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include('Slusaj vest', 'Najnovije vesti', 'Druga vest sa portala Blic')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the complete Blic article when reader mode is disabled' do
    with_url_page(article_url, article_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)
      markdown = payload.fetch('markdown')

      expect(payload).to include(
        'byline' => 'Teodora Boskovski',
        'siteName' => 'Blic',
        'language' => 'sr',
        'contentType' => 'article',
        'readerMode' => false,
        'hostAware' => false,
        'warnings' => [],
        'suspect' => false
      )
      expect(markdown).to include(
        '[Teodora Boskovski](https://www.blic.rs/autori/teodora-boskovski)',
        'Od pocetka godine 195 osoba izgubilo zivot na putevima',
        'Pojacana kontrola saobracaja u Srbiji',
        *article_paragraphs
      )
      positions = article_paragraphs.map { |text| markdown.index(text) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(markdown).not_to include('Slusaj vest', 'Najnovije vesti', 'Druga vest sa portala Blic')
      expect(payload.fetch('excerpt')).to include('Od pocetka godine u saobracajnim nezgodama')
      expect(payload.fetch('html')).to include(
        '<a href="https://www.blic.rs/autori/teodora-boskovski">Teodora Boskovski</a>'
      )
      expect(payload.fetch('html')).not_to include('banner--article', 'wrapperAd', 'InText_1')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'classifies the Blic homepage as a story list instead of an article' do
    sections = 2.times.map do |section_index|
      cards = 3.times.map do |card_index|
        index = (section_index * 3) + card_index + 1
        <<~CARD
          <article class="news news--small">
            <h2><a href="/vesti/drustvo/velika-vest-sa-naslovne-strane-blica-broj-#{index}/44pr4w#{index}">Velika vest sa naslovne strane Blica broj #{index}</a></h2>
            <p>Detalj za naslovnu vest koji opisuje temu i odvaja pravu karticu od navigacije.</p>
          </article>
        CARD
      end.join
      "<section class=\"section\"><h2>Sekcija #{section_index + 1}</h2>#{cards}</section>"
    end.join

    html = <<~HTML
      <html lang="sr">
        <head><title>Blic | Vesti dana iz Srbije, regiona i sveta</title><meta property="og:site_name" content="Blic"></head>
        <body>
          <header><nav><a href="/vesti">Vesti</a><a href="/sport">Sport</a></nav></header>
          <main>#{sections}</main>
        </body>
      </html>
    HTML

    [true, false].each do |reader_mode|
      with_url_page('https://www.blic.rs/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = reader_mode ? extract_payload(page) : extract_payload(page, reader_mode: false)
        markdown = payload.fetch('markdown')

        expect(payload).to include(
          'siteName' => 'Blic',
          'language' => 'sr',
          'contentType' => 'list',
          'contentFormat' => nil,
          'readerMode' => false,
          'hostAware' => false,
          'warnings' => [],
          'suspect' => false
        )
        expect(markdown).to include('## Sekcija 1', '## Sekcija 2')
        expect(markdown.scan('Detalj za naslovnu vest koji opisuje temu i odvaja pravu karticu od navigacije.').length).to eq(6)
        positions = (1..6).map do |index|
          markdown.index(
            "[Velika vest sa naslovne strane Blica broj #{index}](https://www.blic.rs/vesti/drustvo/velika-vest-sa-naslovne-strane-blica-broj-#{index}/44pr4w#{index})"
          )
        end
        expect(positions).to all(be_a(Integer))
        expect(positions).to eq(positions.sort)
        expect(markdown.index('## Sekcija 1')).to be < positions.fetch(0)
        expect(positions.fetch(2)).to be < markdown.index('## Sekcija 2')
        expect(markdown.index('## Sekcija 2')).to be < positions.fetch(3)
        expect(markdown).not_to include('[Vesti]', '[Sport]')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end
end
