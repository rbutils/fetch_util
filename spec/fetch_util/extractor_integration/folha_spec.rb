# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts the public Folha article body without false paywall warnings' do
    expect_fixture_article(
      url: 'https://www1.folha.uol.com.br/esporte/2026/07/fifa-rejeita-e-chama-de-inadmissivel-recurso-belga-sobre-caso-balogun-na-copa.shtml',
      fixture_path: File.expand_path('../../fixtures/folha_article.html', __dir__),
      includes: [
        'A comissão de apelação da [Fifa](https://www1.folha.uol.com.br/folha-topicos/fifa/) rejeitou o recurso da Bélgica',
        'O presidente dos EUA, Donald Trump, confirmou que telefonou'
      ],
      excludes: ['Minha Folha', 'Leia resumo', 'Compartilhe'],
      warning_excludes: %w[truncated_content paywall_partial_content]
    )
  end
end
