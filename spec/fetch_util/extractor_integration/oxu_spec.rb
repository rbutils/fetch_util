# frozen_string_literal: true

RSpec.describe 'FetchUtil Oxu extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Oxu article bodies from the post-detail layout without false truncation or stale warnings' do
    expect_fixture_article(
      url: 'https://oxu.az/dunya/alyaskada-yoxa-cixan-teyyareden-xeber-var',
      fixture_path: File.expand_path('../../fixtures/oxu_article.html', __dir__),
      includes: [
        'Dünən Alyaskada radarların ekranından itən',
        'hava gəmisinin göyərtəsində olanların hamısı həlak olub',
        'Xatırladaq ki, "Cessna 208B Grand Caravan"'
      ],
      excludes: ['A-', 'A+'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial stale_content truncated_content]
    )
  end
end
