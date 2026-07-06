# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts the public Folha article body without false paywall warnings' do
    html = File.read(File.expand_path('../../fixtures/folha_article.html', __dir__))

    url = 'https://www1.folha.uol.com.br/esporte/2026/07/fifa-rejeita-e-chama-de-inadmissivel-recurso-belga-sobre-caso-balogun-na-copa.shtml'

    extract_from_url(url, html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('A comissão de apelação da [Fifa](https://www1.folha.uol.com.br/folha-topicos/fifa/) rejeitou o recurso da Bélgica')
      expect(payload['markdown']).to include('O presidente dos EUA, Donald Trump, confirmou que telefonou')
      expect(payload['markdown']).not_to include('Minha Folha')
      expect(payload['markdown']).not_to include('Leia resumo')
      expect(payload['markdown']).not_to include('Compartilhe')
      expect(payload['warnings']).not_to include('truncated_content')
      expect(payload['warnings']).not_to include('paywall_partial_content')
    end
  end
end
