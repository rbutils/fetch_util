# frozen_string_literal: true

RSpec.describe 'FetchUtil B92 extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts B92 article bodies without false URL mismatch warnings' do
    html = File.read(File.expand_path('../../fixtures/b92_article.html', __dir__))
    url = 'https://www.b92.net/info/svet/248211/preti-pucanje-nato-saveza-na-samitu-u-ankari/vest'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Preti pucanje NATO saveza na samitu u Ankari')
      expect(payload['markdown']).to include('nikada nije pokazivao preteran entuzijazam')
      expect(payload['markdown']).not_to include('Možda vas zanima')
      expect(payload['markdown']).not_to include('Podeli:')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
