# frozen_string_literal: true

RSpec.describe 'FetchUtil Mwananchi extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Mwananchi article bodies without paywall or stale-content warnings' do
    expect_fixture_article(
      url: 'https://www.mwananchi.co.tz/mw/habari/kitaifa/wizara-ya-habari-yaomba-bajeti-ya-sh525-bilioni-ikibainisha-vipaumbele-tisa-5446352',
      fixture_path: File.expand_path('../../fixtures/mwananchi_article.html', __dir__),
      includes: [
        'Wizara ya Habari yaomba bajeti ya Sh525 bilioni ikibainisha vipaumbele tisa',
        'Miongoni mwa vipaumbele hivyo ni kukamilisha maandalizi ya Tanzania kuwa mwenyeji wa mashindano ya AFCON 2027',
        'Wizara ya Habari, Utamaduni, Sanaa na Michezo imewasilisha bungeni bajeti yake ya Sh525.327 bilioni'
      ],
      excludes: ['Ndiyo, tafadhali!', 'Ingia', 'Jiunge nasi leo usikose habari muhimu'],
      warning_excludes: %w[paywall_partial_content stale_content empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
