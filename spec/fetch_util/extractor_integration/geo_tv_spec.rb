# frozen_string_literal: true

RSpec.describe 'FetchUtil Geo TV extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Geo TV AMP article bodies without stale content warnings' do
    expect_fixture_article(
      url: 'https://www.geo.tv/amp/292521',
      fixture_path: File.expand_path('../../fixtures/geo_tv_article.html', __dir__),
      includes: [
        'NFC: maneuverings and equity',
        'The 10th NFC has been constituted',
        'The 10th NFC can negotiate vertical sharing ratio'
      ],
      excludes: ['Share by facebook', 'Advertisement'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
