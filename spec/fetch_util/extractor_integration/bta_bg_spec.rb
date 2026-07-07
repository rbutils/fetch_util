# frozen_string_literal: true

RSpec.describe 'FetchUtil BTA.bg extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts BTA article bodies without false URL mismatch warnings' do
    html = File.read(File.expand_path('../../fixtures/bta_bg_article.html', __dir__))
    url = 'https://www.bta.bg/bg/news/economy/1162530-svetovnite-investitsii-narastvat-s-6-na-sto-do-1-6-triliona-dolara-prez-2025-g-'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Световните инвестиции нарастват с 6 на сто')
      expect(payload['markdown']).to include('Преките чуждестранни инвестиции (ПЧИ) в света са нараснали')
      expect(payload['markdown']).to include('инвестициите се концентрират все повече')
      expect(payload['markdown']).not_to include('СВЪРЗАНИ НОВИНИ')
      expect(payload['markdown']).not_to include('unctad.org/press-material')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
