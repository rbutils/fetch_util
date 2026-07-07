# frozen_string_literal: true

RSpec.describe 'FetchUtil 24ur extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts 24ur article bodies without social consent chrome or false URL mismatch warnings' do
    html = File.read(File.expand_path('../../fixtures/24ur_article.html', __dir__))
    url = 'https://www.24ur.com/sport/kosarka/oranzni-kosarkarski-zmaji-po-notah-novega-organizatorja.html'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Anthony Cowan')
      expect(payload['markdown']).to include('prvič oblekel zeleno-oranžni dres Cedevite Olimpije')
      expect(payload['markdown']).to include('organizatorja igre')
      expect(payload['markdown']).not_to include('Za ogled potrebujemo tvojo privolitev')
      expect(payload['markdown']).not_to include('Omogoči piškotke')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
