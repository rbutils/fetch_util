# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts public Abril article bodies without false paywall warnings' do
    html = fixture_contents(File.expand_path('../../fixtures/abril_article.html', __dir__))
    url = 'https://veja.abril.com.br/esporte/fifa-rejeita-pedido-da-belgica-para-rever-decisao-sobre-o-atacante-americano/'

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload).to include(
        'title' => 'Fifa rejeita pedido da Belgica para rever decisao sobre o atacante americano',
        'byline' => 'Felipe Carneiro',
        'contentType' => 'article',
        'readerMode' => true,
        'hostAware' => false,
        'warnings' => []
      )
      expect(payload.fetch('excerpt')).to start_with('A Fifa rejeitou o questionamento da Belgica')
      expect(payload.fetch('excerpt')).to end_with('contra os Estados Unidos.')
      expect(payload.fetch('html')).to include('<h1>Fifa rejeita pedido da Belgica',
                                               'O presidente da Fifa, Gianni Infantino',
                                               'deve explicacoes sobre o caso Balogun',
                                               'A Federacao Belga confirmou o recebimento da decisao',
                                               'afirmou ter discutido com Donald Trump')
      [payload.fetch('markdown'), payload.fetch('html')].each do |rendered|
        expect(rendered).not_to include('Compartilhe essa materia', 'LEIA MAIS', 'EM ALTA',
                                        'TUDO SOBRE A COPA', 'Publicidade')
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
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
      expect(payload).to include(
        'title' => 'Conteudo Exclusivo',
        'contentType' => 'article',
        'readerMode' => true,
        'hostAware' => false
      )
      expected_excerpt = 'Esta reportagem apresenta o contexto publico inicial, com informacoes suficientes ' \
                         'para formar um resumo curto da noticia antes da area restrita.'
      expect(payload.fetch('excerpt')).to eq(expected_excerpt)
      expect(payload.fetch('html')).to include('<h1>Conteudo Exclusivo</h1>')
      expect(payload.fetch('markdown')).to include('Esta reportagem apresenta o contexto publico inicial')
      expect_warnings(payload, include: 'paywall_partial_content')
    end
  end
end
