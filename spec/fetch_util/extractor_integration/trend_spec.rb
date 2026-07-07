# frozen_string_literal: true

RSpec.describe 'FetchUtil Trend.az extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Trend article bodies without false truncation warnings' do
    expect_fixture_article(
      url: 'https://www.trend.az/business/green-economy/4204857.html',
      fixture_path: File.expand_path('../../fixtures/trend_article.html', __dir__),
      includes: [
        '# Uzbekistan presents green energy experience in Tajikistan',
        'Uzbekistan presented its experience in renewable energy development',
        'Participants discussed global trends in renewable energy development'
      ],
      excludes: ['Latest Premium Azerbaijan Politics Economy', 'Follow Trend on Whatsapp'],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial]
    )
  end
end
