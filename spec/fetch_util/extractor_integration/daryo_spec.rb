# frozen_string_literal: true

RSpec.describe 'FetchUtil Daryo extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Daryo article bodies without source or comments chrome' do
    html = File.read(File.expand_path('../../fixtures/daryo_article.html', __dir__))
    url = 'https://daryo.uz/2026/07/07/kuniga-bir-marta-qozogistonda-transport-vositalari-kirishiga-cheklov-ornatildi'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Qozog‘iston yonilg‘i-moylash materiallarining chegaradan noqonuniy olib chiqib ketilishining oldini olish')
      expect(payload['markdown']).to include('Vazir o‘rinbosarining so‘zlariga ko‘ra')
      expect(payload['markdown']).not_to include('Manba: Tengrinews')
      expect(payload['markdown']).not_to include('Izoh qoldirish uchun')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
