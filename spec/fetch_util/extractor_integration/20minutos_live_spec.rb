# frozen_string_literal: true

RSpec.describe 'FetchUtil 20minutos live extractor integration' do
  include_context 'extractor integration helpers'

  it 'preserves every visible live entry without hidden history or page controls' do
    url = 'https://www.20minutos.es/nacional/incendios-espana-directo-un-amplio-dispositivo-trabaja-para-mantener-perimetro-incendio-castellon_7010836_6.html'
    html = fixture_contents(File.expand_path('../../fixtures/20minutos_live_article.html', __dir__))
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
      expect(payload['title']).to include('Incendios en España, en directo')
      expect(payload['publishedTime']).to eq('08/07/2026')
      expect(payload['excerpt']).to start_with('En plena ola de calor, numerosos incendios')
      expect(markdown).to include('ha quedado estabilizado pasada la medianoche')
      titles.each { |title| expect(markdown.scan(title).length).to eq(1) }
      expect(titles.map { |title| markdown.index(title) }).to eq(titles.map { |title| markdown.index(title) }.sort)
      %w[01:26 23:54 23:24].each { |timestamp| expect(markdown).to include(timestamp) }
      expect(markdown).not_to include('Este parte histórico todavía no es visible', 'Último minuto', 'Cargar más')
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
