# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts public Abril article bodies without false paywall warnings' do
    expect_fixture_article(
      url: 'https://veja.abril.com.br/esporte/fifa-rejeita-pedido-da-belgica-para-rever-decisao-sobre-o-atacante-americano/',
      fixture_path: File.expand_path('../../fixtures/abril_article.html', __dir__),
      includes: [
        'A Fifa rejeitou o questionamento da Belgica sobre a elegibilidade de Folarin Balogun',
        'O presidente da Fifa, Gianni Infantino, afirmou ter discutido com Donald Trump'
      ],
      excludes: ['Compartilhe essa materia', 'LEIA MAIS', 'Publicidade'],
      warning_excludes: %w[truncated_content paywall_partial_content empty_extraction short_extraction consent_interstitial]
    )
  end

  it 'keeps the paywall warning when Abril shows exclusive-content copy' do
    html = <<~HTML
      <!doctype html>
      <html lang="pt-BR">
        <head>
          <title>Conteudo Exclusivo | VEJA</title>
          <meta property="article:content_tier" content="premium">
        </head>
        <body>
          <article>
            <h1>Conteudo Exclusivo</h1>
            <section class="content readme-audima">
              <p>Esta reportagem apresenta o contexto publico inicial, com informacoes suficientes para formar um resumo curto da noticia antes da area restrita.</p>
              <p>O texto visivel explica os principais atores, a decisao em analise e os pontos conhecidos pelo publico ate o momento da publicacao.</p>
              <p>Conteudo Exclusivo: continue lendo com sua assinatura VEJA para acessar a integra da reportagem.</p>
            </section>
          </article>
        </body>
      </html>
    HTML

    url = 'https://veja.abril.com.br/politica/conteudo-exclusivo/'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Esta reportagem apresenta o contexto publico inicial')
      expect_warnings(payload, include: 'paywall_partial_content')
    end
  end
end
