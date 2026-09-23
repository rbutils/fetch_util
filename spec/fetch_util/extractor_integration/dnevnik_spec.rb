# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'preserves the public article and flags its visible full-access gate' do
    url = 'https://www.dnevnik.bg/biznes/2026/07/06/4932760_sled_sreshta_mejdu_radev_i_erdogan_dogovorut_s_botash/'
    html = fixture_contents(File.expand_path('../../fixtures/dnevnik_article.html', __dir__))
    paragraphs = Nokogiri::HTML(html).css('article p').map { |node| node.text.strip }
    title = 'След среща между Радев и Ердоган договорът с Боташ е замразен'

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include('contentType' => 'article', 'title' => title,
                                 'byline' => 'Георги Пауновски', 'readerMode' => true, 'hostAware' => false)
      expect(payload['html']).to include("<h1>#{title}</h1>")
      expect(payload['markdown']).to include("# #{title}", '[Георги Пауновски](https://www.dnevnik.bg/author/georgi-paunovski/)')
      expect(payload['excerpt']).to eq(paragraphs.first)
      paragraphs.each { |paragraph| expect(payload['markdown'].scan(paragraph).length).to eq(1) }
      expect(payload['markdown']).not_to include('Дневник и Капитал са сертифицирани', 'Продължете да четете с пълен достъп')
      expect_warnings(payload, include: %w[paywall_partial_content],
                               exclude: %w[url_content_mismatch empty_extraction short_extraction consent_interstitial])
      expect(payload['suspect']).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
