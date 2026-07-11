# frozen_string_literal: true

RSpec.describe 'Polish portal homepage fidelity' do
  include_context 'extractor integration helpers'

  def fixture(name)
    fixture_contents(File.expand_path("../../fixtures/#{name}.html", __dir__))
  end

  it 'preserves every marked WP region and card in DOM order' do
    with_url_page('https://wp.pl/', fixture('fidelity_wp_homepage')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      wp_titles = [
        'Mostek otwiera trasę', 'Boisko dostaje miękkie światło', 'Łucznicy ćwiczą',
        'Wioślarze liczą', 'Klub pieszych', 'Warsztat szyje', 'Skład herbat',
        'Zegarmistrz naprawia', 'Stolarze rysują', 'Warzywniak waży', 'Mapa pokazuje',
        'Mała drukarka', 'Głośnik zapamiętuje', 'Programista porządkuje', 'Gra planszowa',
        'Księgarnia wymienia', 'Ogrodnik rozdaje', 'Plan ciszy', 'Lista rzeczy',
        'Jak przechować miętę'
      ]
      expect(wp_titles.sum { |title| result['markdown'].scan(title).length }).to eq(20)
      expect(result['markdown']).to include('Krótka ścieżka łączy dwa spokojne zakątki.')
      expect(result['markdown']).to include('## Okazje na dziś', '## Kartki z sąsiedztwa', '## Porady z podwórka')
      expect(result['markdown']).not_to include('Jak przechować miętę przez noc wersja mobilna', 'Porada bez odnośnika', 'Narzędzia')
      expect(result['markdown']).not_to include('FID:chrome-ad', 'FID:chrome-sidebar', 'FID:chrome-footer')
      expect(result['markdown'].scan(%r{https?://[^)]+/wp/advice-01}).length).to eq(1)
      expect(result['markdown'].index('Ruch na świeżym powietrzu')).to be < result['markdown'].index('Pracownie i handel')
      expect(result['markdown'].index('Pracownie i handel')).to be < result['markdown'].index('Pomysły cyfrowe')
      expect(result['markdown'].index('Pomysły cyfrowe')).to be < result['markdown'].index('Okazje na dziś')
      expect(result['markdown'].index('Okazje na dziś')).to be < result['markdown'].index('Kartki z sąsiedztwa')
      expect(result['markdown'].index('Kartki z sąsiedztwa')).to be < result['markdown'].index('Porady z podwórka')
    end
  end

  it 'preserves Onet named sections and each accepted card in DOM order' do
    with_url_page('https://onet.pl/', fixture('fidelity_onet_homepage')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      expect(result['warnings']).not_to include('multi_topic_page')
      expect(result['suspect']).to eq(false)
      onet_titles = [
        'Latarnie dostały', 'Biblioteka otwiera', 'Targ wraca', 'Biegacze wybierają',
        'Młodzi szachiści', 'Sobotni turniej', 'Piekarnia testuje', 'Rzemieślnicy wymieniają',
        'Sklep naprawia', 'Ceramicy pokazują', 'Kuchnia pachnie', 'Muzycy stroją',
        'Czujnik deszczu', 'Planszówka dostaje', 'Robot pomaga'
      ]
      expect(onet_titles.sum { |title| result['markdown'].scan(title).length }).to eq(15)
      expect(result['markdown']).not_to include('Wybór redakcji', 'Stopka testowa')
      expect(result['markdown'].index('## Wieści z okolicy')).to be < result['markdown'].index('## Ruch i boisko')
      expect(result['markdown'].index('## Ruch i boisko')).to be < result['markdown'].index('## Małe interesy')
    end
  end

  it 'recognizes current and legacy Onet regions without promoting card labels' do
    with_url_page('https://onet.pl/', fixture('fidelity_onet_regions')) do |page|
      result = extract_payload(page, reader_mode: false)

      expected_regions = [
        'NAJLEPSZE W PREMIUM', 'WIADOMOŚCI', 'SPORT', 'BIZNES', 'OFERTY',
        'TECHNOLOGIE GRY', 'NAJLEPSZE PREMIUM:'
      ]
      expected_cards = %w[
        premium-01 premium-02?edition=morning news-01 news-02 sport-01 business-01
        offers-01 offers-02?edition=evening tech-01 tech-02 premium-03
      ]

      expect(result['contentType']).to eq('list')
      actual_regions = result['markdown'].lines.grep(/^## /).map { |line| line.delete_prefix('## ').strip }
      card_urls = result['markdown'].scan(%r{\]\((https?://[^)]+)\)}).flatten
      actual_cards = card_urls.map { |url| url.sub(%r{\Ahttps?://[^/]+}, '').split('/').last }
      expect(actual_regions).to eq(expected_regions)
      expect(actual_cards).to eq(expected_cards)
      expect(card_urls.grep(/premium-02\?edition=morning/).length).to eq(1)
      expect(card_urls.grep(/offers-02\?edition=evening/).length).to eq(1)
      expect(result['markdown']).not_to include(
        'FID:card-heading-is-not-a-region', 'FID:utility-ad', 'FID:utility-footer',
        'FID:onet-premium-01 mobile'
      )
      expect(card_urls.tally.values).to all(eq(1))
    end
  end

  it 'preserves populated Onet DynamicRightFeed continuations after named regions' do
    with_url_page('https://onet.pl/', fixture('fidelity_onet_continuation')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      expect(result['warnings']).not_to include('multi_topic_page')
      expect(result['suspect']).to eq(false)
      expect(result['markdown']).to include('## More from Onet')
      expect(result['markdown']).to include(
        'BIZNES',
        'https://www.onet.pl/informacje/tu-stolica/schorowani-mieszkancy-czekaja-gigantyczne-kolejki-do-waznej-instytucji/glczdww,30bc1058'
      )
      expect(result['markdown'].scan(/FID:onet-continuation-\d+/)).to eq(
        %w[FID:onet-continuation-01 FID:onet-continuation-02 FID:onet-continuation-03]
      )
      expect(result['markdown']).not_to include('FID:onet-continuation-utility', 'FID:onet-continuation-ad')
      expect(result['markdown'].scan(%r{/onet/continuation-duplicate}).length).to eq(1)
      expect(result['markdown'].index('FID:onet-business-01')).to be < result['markdown'].index('## More from Onet')
    end
  end

  it 'keeps www roots with their site-specific homepage owners' do
    [
      ['https://www.wp.pl/', 'fidelity_wp_homepage'],
      ['https://www.onet.pl/', 'fidelity_onet_homepage']
    ].each do |url, fixture_name|
      extract_from_url(url, fixture(fixture_name), reader_mode: false) do |payload|
        expect(payload['contentType']).to eq('list')
        expect(payload['hostAware']).to eq(true)
      end
    end
  end

  it 'does not let descendant roots or article paths acquire homepage ownership' do
    [
      ['https://news.wp.pl/', 'fidelity_wp_homepage'],
      ['https://wp.pl/wiadomosci/example', 'fidelity_wp_homepage'],
      ['https://news.onet.pl/', 'fidelity_onet_homepage'],
      ['https://onet.pl/wiadomosci/example', 'fidelity_onet_homepage']
    ].each do |url, fixture_name|
      extract_from_url(url, fixture(fixture_name), reader_mode: false) do |payload|
        expect(payload['hostAware']).not_to eq(true)
      end
    end
  end

  it 'keeps the Onet root owner ahead of article-shaped markup' do
    html = fixture('fidelity_onet_homepage').sub(
      '</body>',
      '<article><h1>Article-shaped root noise</h1><p>Not a route.</p></article></body>'
    )

    extract_from_url('https://onet.pl/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['hostAware']).to eq(true)
      expect(payload['markdown']).not_to include('Article-shaped root noise')
    end
  end
end
