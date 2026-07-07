# frozen_string_literal: true

RSpec.describe 'FetchUtil B.T. extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts public B.T. Ritzau article bodies without navigation and front-page chrome' do
    html = File.read(File.expand_path('../../fixtures/bt_dk_article.html', __dir__))
    url = 'https://www.bt.dk/samfund/efter-usaedvanligt-dyr-juni-aabner-juli-med-lavere-elpriser'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Efter usædvanligt dyr juni åbner juli med lavere elpriser')
      expect(payload['markdown']).to include('Hedebølge og manglende vindproduktion skabte høje strømpriser')
      expect(payload['markdown']).to include('SVM-regeringen har dog sænket elafgiften')
      expect(payload['markdown']).to include('RITZAU')
      expect(payload['markdown']).not_to include('NavigationSektioner')
      expect(payload['markdown']).not_to include('Front-page teaser should not leak')
      expect(payload['markdown']).not_to include('Log ind og læs')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial multi_topic_page])
    end
  end
end
