RSpec.describe 'FetchUtil Blick extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Blick live tickers through shared article ownership' do
    url = 'https://www.blick.ch/ausland/was-wuerde-ein-verlust-pokrowsks-fuer-die-ukraine-bedeuten-id17193095.html'
    html = fixture_contents(File.expand_path('../../fixtures/blick_article.html', __dir__))
    included = [
      'Darum gehts',
      'Russland greift die Ukraine unvermindert an',
      'Gleichzeit häufen sich Nato-Luftraumverletzungen',
      'Experten sind sich sicher: Putin testet das Bündnis',
      'Trump geht auf Distanz zu Putin',
      'Ende des Livetickers',
      'An dieser Stelle beenden wir unseren Liveticker zum Ukrainekrieg',
      'US-Präsident Donald Trump hatte vor den Genfer Ukraine-Verhandlungen mit einem Ultimatum am Donnerstag gedroht.'
    ]
    excluded = [
      'Externe Inhalte',
      'Möchtest du diesen und weitere externe Beiträge'
    ]

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)

      expect(payload).to include(
        'title' => 'Krieg in der Ukraine: die aktuellen Entwicklungen im Liveticker - Blick',
        'byline' => 'Blick Newsdesk',
        'contentType' => 'article',
        'contentFormat' => 'liveblog',
        'hostAware' => false,
        'readerMode' => true,
        'suspect' => true,
        'warnings' => ['multi_topic_page']
      )
      included.each { |text| expect(payload['markdown']).to include(text) }
      %w[html markdown textContent].each do |field|
        excluded.each { |text| expect(payload[field]).not_to include(text) }
      end
      expect(payload['markdown']).to include(
        '[Blick Newsdesk](https://www.blick.ch/autoren/blick-news-id20762787.html)'
      )
      expect(payload['excerpt']).to start_with(
        'Darum gehts KI-generiert, redaktionell geprüft Russland greift die Ukraine unvermindert an'
      )
      expect(payload['excerpt'].length).to eq(280)
      %w[
        containerPiano1 containerPiano2 CMPPlaceholder__Wrapper-sc-b34bbfca-0
        EmbeddedContent__StyledEmbeddedContentContainer-sc-5c959b4b-0
      ].each { |marker| expect(payload['html']).not_to include(marker) }
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves article media on subdomain query and fragment routes' do
    url = 'https://sport.blick.ch/fussball/lagebericht-id20000000.html?edition=late#update'
    fixture = fixture_contents(File.expand_path('../../fixtures/blick_article.html', __dir__))
    html = fixture.sub(
      '</article>',
      <<~HTML
        <figure>
          <img src="https://cdn.blick.ch/frontline-map.jpg" alt="Frontline map">
          <figcaption>Verified frontline map</figcaption>
        </figure>
        </article>
      HTML
    )

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)

      expect(payload).to include(
        'contentType' => 'article',
        'contentFormat' => 'liveblog',
        'hostAware' => false,
        'readerMode' => true
      )
      expect(payload['markdown']).to include(
        'https://cdn.blick.ch/frontline-map.jpg',
        'Frontline map',
        'Verified frontline map'
      )
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
