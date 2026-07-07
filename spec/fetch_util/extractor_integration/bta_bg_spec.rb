# frozen_string_literal: true

RSpec.describe 'FetchUtil BTA.bg extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts BTA article bodies without false URL mismatch warnings' do
    # BTA.bg's profile scopes the Bulgarian article body and avoids false slug mismatch warnings.
    expect_fixture_article(
      url: 'https://www.bta.bg/bg/news/economy/1162530-svetovnite-investitsii-narastvat-s-6-na-sto-do-1-6-triliona-dolara-prez-2025-g-',
      fixture_path: File.expand_path('../../fixtures/bta_bg_article.html', __dir__),
      includes: [
        'Световните инвестиции нарастват с 6 на сто',
        'Преките чуждестранни инвестиции (ПЧИ) в света са нараснали',
        'инвестициите се концентрират все повече'
      ],
      excludes: ['СВЪРЗАНИ НОВИНИ', 'unctad.org/press-material'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
