# frozen_string_literal: true

RSpec.describe 'FetchUtil France24 extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts France24 article bodies without empty extraction warnings' do
    expect_fixture_article(
      url: 'https://www.france24.com/es/francia/20260707-condena-de-marine-le-pen-lo-que-hay-que-retener',
      fixture_path: File.expand_path('../../fixtures/france24_article.html', __dir__),
      includes: [
        'Con su recurso de casación, ésta es la arriesgada apuesta de Marine Le Pen',
        'Ya no hay ningún escenario en el que no pueda presentarme en 2027',
        'La sentencia del Tribunal de Apelación de París le ha brindado la posibilidad de seguir siendo candidata'
      ],
      excludes: ['Anuncios', 'Compartir', 'Leer también'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end
end
