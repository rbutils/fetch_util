# frozen_string_literal: true

RSpec.describe 'FetchUtil 20minutos live extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts only the selected live entry without multi-topic warnings' do
    expect_fixture_article(
      url: 'https://www.20minutos.es/nacional/incendios-espana-directo-un-amplio-dispositivo-trabaja-para-mantener-perimetro-incendio-castellon_7010836_6.html',
      fixture_path: File.expand_path('../../fixtures/20minutos_live_article.html', __dir__),
      includes: [
        'Extinguido el incendio forestal en Villanueva del Río Segura',
        'ha quedado estabilizado pasada la medianoche'
      ],
      excludes: [
        'Controlado el incendio forestal de Soneja (Castellón)',
        'El incendio de La Bisbal (Girona) se da por controlado tras quemar 2.200 hectáreas'
      ],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
