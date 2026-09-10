# frozen_string_literal: true

RSpec.describe 'FetchUtil 20minutos live extractor integration' do
  include_context 'extractor integration helpers'

  it 'preserves every visible live entry without hidden history or page controls' do
    expect_fixture_article(
      url: 'https://www.20minutos.es/nacional/incendios-espana-directo-un-amplio-dispositivo-trabaja-para-mantener-perimetro-incendio-castellon_7010836_6.html',
      fixture_path: File.expand_path('../../fixtures/20minutos_live_article.html', __dir__),
      includes: [
        'Extinguido el incendio forestal en Villanueva del Río Segura',
        'ha quedado estabilizado pasada la medianoche',
        'Controlado el incendio forestal de Soneja (Castellón)',
        'El incendio de La Bisbal (Girona) se da por controlado tras quemar 2.200 hectáreas'
      ],
      excludes: [
        'Este parte histórico todavía no es visible',
        'Último minuto',
        'Cargar más'
      ],
      warning_excludes: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
