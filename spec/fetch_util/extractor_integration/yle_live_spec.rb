# frozen_string_literal: true

RSpec.describe 'FetchUtil Yle live extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts only the selected Yle live article item' do
    html = File.read(File.expand_path('../../fixtures/yle_live_article.html', __dir__))
    url = 'https://yle.fi/a/74-20235117/64-3-304362'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Trump on saapunut Ankaraan')
      expect(payload['markdown']).to include('Yhdysvaltain presidentti Donald Trump on saapunut Turkin pääkaupunkiin Ankaraan')
      expect(payload['markdown']).to include('Lähde: Reuters')
      expect(payload['markdown']).not_to include('Rutte: Naton ja EU:n tiivistettävä yhteistyötä')
      expect(payload['markdown']).not_to include('Yle seuraa tiistaina alkavaa Nato-kokousta')
      expect(payload['markdown']).not_to include('Videosoitin')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
