# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts the public Folha article body without false paywall warnings' do
    expect_fixture_article(
      url: 'https://www1.folha.uol.com.br/esporte/2026/07/fifa-rejeita-e-chama-de-inadmissivel-recurso-belga-sobre-caso-balogun-na-copa.shtml',
      fixture_path: File.expand_path('../../fixtures/folha_article.html', __dir__),
      includes: [
        'Jogador americano recebeu cartão vermelho em confronto contra a Bósnia e teve suspensão anulada pela entidade',
        'A comissão de apelação da [Fifa](https://www1.folha.uol.com.br/folha-topicos/fifa/) rejeitou o recurso da Bélgica',
        'A entidade considerou o recurso inadmissível e afirmou que a Federação Belga de Futebol',
        'A apenas algumas horas da partida entre Bélgica e Estados Unidos',
        'O presidente dos EUA, Donald Trump, confirmou que telefonou'
      ],
      excludes: ['Minha Folha', 'Leia resumo', 'Compartilhe', 'A newsletter da Folha'],
      warning_excludes: %w[truncated_content paywall_partial_content]
    )
  end

  it 'retains every source-owned subtitle and public paragraph without mutating the page' do
    url = 'https://www1.folha.uol.com.br/esporte/2026/07/fifa-rejeita-e-chama-de-inadmissivel-recurso-belga-sobre-caso-balogun-na-copa.shtml'
    html = fixture_contents(File.expand_path('../../fixtures/folha_article.html', __dir__))

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      subtitles = page.evaluate("Array.from(document.querySelectorAll('[itemprop=alternativeHeadline] li'), node => node.textContent.trim())")
      paragraphs = page.evaluate("Array.from(document.querySelectorAll('.c-news__body p'), node => node.textContent.trim())")
      payload = extract_payload(page)
      retained_text = Nokogiri::HTML.fragment(payload.fetch('html')).text.gsub(/\s+/, ' ').strip

      expect(payload).to include('contentType' => 'article', 'hostAware' => true)
      (subtitles + paragraphs).each do |text|
        expect(retained_text.scan(text).length).to eq(1)
      end
      expect(payload.fetch('markdown')).not_to include('Leia resumo', 'A newsletter da Folha')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
