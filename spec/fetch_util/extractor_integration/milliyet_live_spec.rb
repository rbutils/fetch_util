# frozen_string_literal: true

RSpec.describe 'FetchUtil Milliyet live extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Milliyet live article bodies without false multi-topic warnings' do
    html = File.read(File.expand_path('../../fixtures/milliyet_live_article.html', __dir__))
    url = 'https://www.milliyet.com.tr/dunya/live-tarihi-nato-zirvesi-basladi-trump-ankarada-7618835'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Tarihi NATO Zirvesi başladı')
      expect(payload['markdown']).to include('ABD Başkanı Trump Ankara Havalimanı')
      expect(payload['markdown']).to include('Milli Savunma Bakanı Yaşar Güler')
      expect(payload['markdown']).not_to include('Günün en çok okunanları')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
