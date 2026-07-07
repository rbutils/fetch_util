# frozen_string_literal: true

RSpec.describe 'FetchUtil SME.sk extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts SME.sk article bodies without false URL mismatch warnings' do
    html = File.read(File.expand_path('../../fixtures/sme_sk_article.html', __dir__))
    url = 'https://www.sme.sk/domov/c/generalna-prokuratura-zistila-vo-veci-tragedie-v-gelnici-zavazne-porusenia-zakona'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('V kabelke nosila list pre prípad, že zomrie')
      expect(payload['markdown']).to include('Prípravné konanie, ktoré predchádzalo tragickej vražde učiteľky')
      expect(payload['markdown']).to include('závažné pochybenia')
      expect(payload['markdown']).not_to include('SME Audio')
      expect(payload['markdown']).not_to include('Playlist')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
