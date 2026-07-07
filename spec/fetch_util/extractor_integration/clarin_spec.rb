# frozen_string_literal: true

RSpec.describe 'FetchUtil Clarin extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Clarin article bodies without related sidebar content' do
    html = File.read(File.expand_path('../../fixtures/clarin_article.html', __dir__))
    url = 'https://www.clarin.com/economia/' \
          'luis-caputo-1400-van-militar-atraso-cambiario-pueden-militar-preocupacion-1500_0_DBPd3pCuSd.html'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('El ministro de Economía Luis Caputo le restó importancia a la suba')
      expect(payload['markdown']).to include('Si en $1400 te van a militar atraso cambiario')
      expect(payload['markdown']).not_to include('Mirá también')
      expect(payload['markdown']).not_to include('Newsletter Clarín')
      expect(payload['markdown']).not_to include('Te puede interesar')
      expect(payload['markdown']).not_to include('Inteligencia Artificial')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
