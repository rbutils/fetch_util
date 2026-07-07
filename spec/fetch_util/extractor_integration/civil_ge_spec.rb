# frozen_string_literal: true

RSpec.describe 'FetchUtil Civil.ge extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Civil.ge article bodies instead of sidebar lists' do
    html = File.read(File.expand_path('../../fixtures/civil_ge_article.html', __dir__))
    url = 'https://civil.ge/archives/743770'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Giorgi Bakhuashvili, who reportedly served as a personal bodyguard')
      expect(payload['markdown']).to include('According to RFE/RL’s Georgian Service')
      expect(payload['markdown']).not_to include('MFA’s Newly Created Diplomatic Academy')
      expect(payload['markdown']).not_to include('Read Next')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
