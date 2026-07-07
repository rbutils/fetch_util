# frozen_string_literal: true

RSpec.describe 'FetchUtil B92 extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts B92 article bodies without false URL mismatch warnings' do
    # B92's profile keeps the article body and suppresses Serbian slug/language mismatch noise.
    expect_fixture_article(
      url: 'https://www.b92.net/info/svet/248211/preti-pucanje-nato-saveza-na-samitu-u-ankari/vest',
      fixture_path: File.expand_path('../../fixtures/b92_article.html', __dir__),
      includes: [
        'Preti pucanje NATO saveza na samitu u Ankari',
        'nikada nije pokazivao preteran entuzijazam'
      ],
      excludes: ['Možda vas zanima', 'Podeli:'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
