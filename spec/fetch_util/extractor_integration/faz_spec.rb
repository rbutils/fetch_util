# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'classifies the FAZ homepage as a story list' do
    html = fixture_contents(File.expand_path('../../fixtures/faz_homepage.html', __dir__))
    url = 'https://www.faz.net/'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('Kernstück der gemeinsamen Verteidigung')
      expect(payload['markdown']).to include('TKMS bekommt Zuschlag für Milliarden-Auftrag aus Kanada')
      expect(payload['markdown']).to include('TRUMP, INFANTINO UND BALOGUN : War es das wert?')
      expected = Nokogiri::HTML(html, nil, 'UTF-8').css('main article a').map do |link|
        [link.text.strip, URI.join(url, link['href']).to_s]
      end
      positions = expected.map do |label, destination|
        expect(payload['markdown']).to include(label)
        expect(payload['markdown'].scan("](#{destination})").length).to eq(1)
        payload['markdown'].index(destination)
      end
      expect(positions).to eq(positions.sort)
      expect(payload['warnings']).to be_empty
    end
  end

  it 'extracts public FAZ article bodies without false list or paywall warnings' do
    expect_fixture_article(
      url: 'https://www.faz.net/aktuell/wirtschaft/unternehmen/tkms-kanadas-u-boot-milliardendeal-mit-deutschland-201005300.html',
      fixture_path: File.expand_path('../../fixtures/faz_article.html', __dir__),
      includes: ['Kanada hat sich entschieden. Mit dem deutschen Marinekonzern TKMS', 'Die Zeit bis zum Stapellauf läuft.'],
      excludes: ['MEHR ZUM THEMA'],
      warning_excludes: %w[multi_topic_page paywall_partial_content]
    )
  end

  it 'preserves complete long reporting and its unchanged public-access metadata' do
    url = 'https://www.faz.net/aktuell/wirtschaft/unternehmen/neuer-hafenplan-201007321.html'
    html = fixture_contents(File.expand_path('../../fixtures/faz_public_long_article.html', __dir__))
    source = Nokogiri::HTML(html, nil, 'UTF-8')
    paragraphs = source.css('article > p').map(&:text)

    with_url_page(url, html) do |page|
      access_metadata = page.evaluate('document.scripts[0].textContent')
      payload = FetchUtil::Extractor.new.extract(page)
      result = Nokogiri::HTML.fragment(payload['html'], 'UTF-8')
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Kommunen legen neuen Hafenplan vor')
      expect(payload['byline']).to eq('Miriam Vogel')
      expect(payload['publishedTime']).to eq('2026-10-07T08:30:00+02:00')
      expect(payload['hostAware']).to be(false)
      selected_paragraphs = result.css('p').map(&:text)
      positions = paragraphs.map { |paragraph| selected_paragraphs.index(paragraph) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(payload['markdown']).to include(
        '## Finanzierung und Zeitplan',
        '[öffentliche Übersicht zum Hafenplan](https://www.faz.net/dokumente/hafenplan-2026.pdf)',
        'decision_month = "November"', '| Abschnitt | Vorgesehener Beginn |'
      )
      expect(result.css('tr').map { |row| row.css('th, td').map(&:text) }).to eq(
        [['Abschnitt', 'Vorgesehener Beginn'], %w[Zufahrt 2027], %w[Uferweg 2028]]
      )
      expect(payload['warnings']).not_to include('paywall_partial_content', 'empty_extraction')
      expect(page.evaluate('document.scripts[0].textContent')).to eq(access_metadata)
    end
  end
end
