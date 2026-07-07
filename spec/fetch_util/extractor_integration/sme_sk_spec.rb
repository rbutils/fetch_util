# frozen_string_literal: true

RSpec.describe 'FetchUtil SME.sk extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts SME.sk article bodies without false URL mismatch warnings' do
    expect_fixture_article(
      url: 'https://www.sme.sk/domov/c/generalna-prokuratura-zistila-vo-veci-tragedie-v-gelnici-zavazne-porusenia-zakona',
      fixture_path: File.expand_path('../../fixtures/sme_sk_article.html', __dir__),
      includes: [
        'V kabelke nosila list pre prípad, že zomrie',
        'Prípravné konanie, ktoré predchádzalo tragickej vražde učiteľky',
        'závažné pochybenia'
      ],
      excludes: [],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
