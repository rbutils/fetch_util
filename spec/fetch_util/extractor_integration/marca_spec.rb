# frozen_string_literal: true

RSpec.describe 'FetchUtil Marca extraction' do
  include_context 'extractor integration helpers'

  it 'extracts Marca article bodies without false truncation warnings' do
    html = File.read(File.expand_path('../../fixtures/marca_article.html', __dir__))
    url = 'https://www.marca.com/futbol/mundial/cronica/2026/07/07/belgica-acaba-trumpas-cita-espana-cuartos.html'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('# Ni Trump puede evitar lo inevitable')
      expect(payload['markdown']).to include('Bélgica convirtió el ruido en rabia')
      expect(payload['markdown']).to include('La mejor Bélgica del Mundial')
      expect(payload['markdown']).to include('Freese regala el tercero')
      expect(payload['markdown']).not_to include('Power Ranking')
      expect(payload['markdown']).not_to include('Compartir en redes sociales')
      expect(payload['markdown']).not_to include('Suscríbete')
      expect_warnings(payload, exclude: %w[truncated_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
