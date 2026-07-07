# frozen_string_literal: true

RSpec.describe 'FetchUtil Trend.az extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Trend article bodies without false truncation warnings' do
    html = File.read(File.expand_path('../../fixtures/trend_article.html', __dir__))
    url = 'https://www.trend.az/business/green-economy/4204857.html'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# Uzbekistan presents green energy experience in Tajikistan')
      expect(payload['markdown']).to include('Uzbekistan presented its experience in renewable energy development')
      expect(payload['markdown']).to include('Participants discussed global trends in renewable energy development')
      expect(payload['markdown']).not_to include('Latest Premium Azerbaijan Politics Economy')
      expect(payload['markdown']).not_to include('Follow Trend on Whatsapp')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
