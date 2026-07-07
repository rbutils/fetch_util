# frozen_string_literal: true

RSpec.describe 'FetchUtil Clarin extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Clarin article bodies without related sidebar content' do
    expect_fixture_article(
      url: 'https://www.clarin.com/economia/' \
           'luis-caputo-1400-van-militar-atraso-cambiario-pueden-militar-preocupacion-1500_0_DBPd3pCuSd.html',
      fixture_path: File.expand_path('../../fixtures/clarin_article.html', __dir__),
      includes: ['El ministro de Economía Luis Caputo le restó importancia a la suba', 'Si en $1400 te van a militar atraso cambiario'],
      excludes: ['Mirá también', 'Newsletter Clarín', 'Te puede interesar', 'Inteligencia Artificial'],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
