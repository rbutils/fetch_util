# frozen_string_literal: true

RSpec.describe 'FetchUtil Clarin extractor integration' do
  include_context 'extractor integration helpers'

  it 'keeps the complete public article and its source-owned fields through shared extraction' do
    url = 'https://www.clarin.com/economia/' \
          'luis-caputo-1400-van-militar-atraso-cambiario-pueden-militar-preocupacion-1500_0_DBPd3pCuSd.html'
    html = fixture_contents(File.expand_path('../../fixtures/clarin_article.html', __dir__))

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload).to include(
        'contentType' => 'article', 'hostAware' => false,
        'title' => 'Luis Caputo: “Si en $1400 te van a militar atraso cambiario, no te pueden militar preocupación en $1500”',
        'byline' => 'Redacción Clarín', 'publishedTime' => '2026-07-06T23:41:30.000Z',
        'warnings' => []
      )
      expect(payload.fetch('excerpt')).to include('Si en $1400 te van a militar atraso cambiario')
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Redacción Clarín', '07/07/2026 01:41', 'El ministro de Economía Luis Caputo le restó importancia')
      expect(markdown).to include('“Si en $1400 te van a militar atraso cambiario, no te pueden militar preocupación en $1500”, analizó.')
      expect(markdown).to include('Inflación, consumo y la expectativa para 2027', 'El titular del Ministerio de Economía remarcó')
      expect(markdown).not_to include('Mirá también', 'Newsletter Clarín', 'Te puede interesar', 'Inteligencia Artificial', 'SUSCRIBITE PARA COMENTAR')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
