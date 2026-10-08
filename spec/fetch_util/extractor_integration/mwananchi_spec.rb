# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil Mwananchi extractor integration' do
  include_context 'extractor integration helpers'

  it 'retains reporting while acknowledging the original visible access interface' do
    expect_fixture_article(
      url: 'https://www.mwananchi.co.tz/mw/habari/kitaifa/wizara-ya-habari-yaomba-bajeti-ya-sh525-bilioni-ikibainisha-vipaumbele-tisa-5446352',
      fixture_path: File.expand_path('../../fixtures/mwananchi_article.html', __dir__),
      includes: [
        'Wizara ya Habari yaomba bajeti ya Sh525 bilioni ikibainisha vipaumbele tisa',
        'Miongoni mwa vipaumbele hivyo ni kukamilisha maandalizi ya Tanzania kuwa mwenyeji wa mashindano ya AFCON 2027',
        'Wizara ya Habari, Utamaduni, Sanaa na Michezo imewasilisha bungeni bajeti yake ya Sh525.327 bilioni'
      ],
      excludes: ['Ndiyo, tafadhali!', 'Ingia', 'Jiunge nasi leo usikose habari muhimu'],
      warning_excludes: %w[stale_content empty_extraction short_extraction url_content_mismatch consent_interstitial],
      suspect: true
    )
  end

  it 'preserves the original article declaration and every reporting paragraph' do
    html = fixture_contents(File.expand_path('../../fixtures/mwananchi_article.html', __dir__))
    url = 'https://www.mwananchi.co.tz/mw/habari/kitaifa/wizara-ya-habari-yaomba-bajeti-ya-sh525-bilioni-ikibainisha-vipaumbele-tisa-5446352'
    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      declaration = page.evaluate('document.querySelector("script[type=\"application/ld+json\"]").textContent')
      payload = FetchUtil::Extractor.new.extract(page)
      expected = Nokogiri::HTML(html, nil, 'UTF-8').css('.article-content p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      actual = Nokogiri::HTML.fragment(payload['html']).css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }

      expect(actual & expected).to eq(expected)
      expect(payload['byline']).to eq('Peter Sekela')
      expect(payload['publishedTime']).to eq('2026-05-04T11:15:00Z')
      expect(payload['paywallState']).to eq('detected')
      expect(payload['warnings']).to include('paywall_partial_content')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(page.evaluate('document.querySelector("script[type=\"application/ld+json\"]").textContent')).to eq(declaration)
    end
  end

  it 'preserves reporting on another host through the same shared pipeline' do
    extract_from_url(
      'https://example.com/news/article',
      fixture_contents(File.expand_path('../../fixtures/mwananchi_noop.html', __dir__))
    ) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('The public article body remains available')
      expect(payload['markdown']).to include('Additional reporting gives readers enough detail')
    end
  end
end
