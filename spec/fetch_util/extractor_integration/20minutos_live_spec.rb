# frozen_string_literal: true

RSpec.describe 'FetchUtil 20minutos live extractor integration' do
  include_context 'extractor integration helpers'

  it 'preserves every visible live entry without hidden history or page controls' do
    url = 'https://www.20minutos.es/nacional/incendios-espana-directo-un-amplio-dispositivo-trabaja-para-mantener-perimetro-incendio-castellon_7010836_6.html'
    html = fixture_contents(File.expand_path('../../fixtures/20minutos_live_article.html', __dir__))
    additional_entries = (4..12).map do |index|
      <<~HTML
        <article class="c-detail--mam__minute-container">
          <time>#{format("%02d", index)}:15</time>
          <h2>Parte visible del incendio #{index}</h2>
          <p>La brigada #{index} continúa los trabajos de vigilancia y comunica información verificada sobre el perímetro del incendio a los vecinos de la zona.</p>
        </article>
      HTML
    end.join
    html = html.sub('<div class="c-detail--mam__live__module"', "#{additional_entries}<div class=\"c-detail--mam__live__module\"")
    html = html.sub('<article class="c-detail c-detail--mam"',
                    '<div class="c-ticker"><a href="/internacional/otro-directo">Un discurso ajeno al incendio</a></div><article class="c-detail c-detail--mam"')
    titles = [
      'Extinguido el incendio forestal en Villanueva del Río Segura',
      'Controlado el incendio forestal de Soneja (Castellón)',
      'El incendio de La Bisbal (Girona) se da por controlado tras quemar 2.200 hectáreas'
    ]

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect_content_type(payload, 'article')
      expect(payload).to include('readerMode' => false, 'hostAware' => true)
      expect(payload['title']).to include('Incendios en España, en directo')
      expect(payload['publishedTime']).to eq('08/07/2026')
      expect(payload['excerpt']).to start_with('En plena ola de calor, numerosos incendios')
      expect(markdown).to include('ha quedado estabilizado pasada la medianoche')
      titles.each { |title| expect(markdown.scan(title).length).to eq(1) }
      expect(titles.map { |title| markdown.index(title) }).to eq(titles.map { |title| markdown.index(title) }.sort)
      additional_titles = (4..12).map { |index| "Parte visible del incendio #{index}" }
      additional_titles.each { |title| expect(markdown.scan(title).length).to eq(1) }
      expect(additional_titles.map { |title| markdown.index(title) }).to eq(additional_titles.map { |title| markdown.index(title) }.sort)
      %w[01:26 23:54 23:24].each { |timestamp| expect(markdown).to include(timestamp) }
      expect(markdown).not_to include('Este parte histórico todavía no es visible', 'Último minuto', 'Cargar más')
      expect(markdown).not_to include('Un discurso ajeno al incendio')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not end a liveblog lead at the decimal mark in a visible area measurement' do
    url = 'https://www.20minutos.es/nacional/incendios-espana-directo-un-amplio-dispositivo-trabaja-para-mantener-perimetro-incendio-castellon_7010836_6.html'
    html = fixture_contents(File.expand_path('../../fixtures/20minutos_live_article.html', __dir__))
    html = html.sub('En plena ola de calor, numerosos incendios han puesto en jaque a los servicios de extinción en buena parte de España.',
                    'El incendio arrasó 7.000 hectáreas de monte y las brigadas mantuvieron la vigilancia durante la noche. ' \
                    'Esta actualización añade contexto sobre la respuesta pública.')

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['excerpt']).to eq('El incendio arrasó 7.000 hectáreas de monte y las brigadas mantuvieron la vigilancia durante la noche.')
      expect(payload['markdown']).to include('Esta actualización añade contexto sobre la respuesta pública.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
