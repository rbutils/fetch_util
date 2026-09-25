# frozen_string_literal: true

RSpec.describe 'FetchUtil focal article author links' do
  include_context 'extractor integration helpers'

  def focal_author_page(author_markup)
    <<~HTML
      <html><head><title>Community housing review</title><meta name="author" content="Alex Morgan">
        <meta property="og:type" content="article">
        <link rel="canonical" href="https://publisher.example/articles/housing-review-123456">
        <script type="application/ld+json">
          {"@type":"Article","headline":"Community housing review",
           "url":"https://publisher.example/articles/housing-review-123456"}
        </script>
      </head><body><main><article><h1>Community housing review</h1>
        #{author_markup}
        <p>Residents reviewed the housing proposal and asked planners to publish the assumptions behind each projected cost.</p>
        <p>The committee compared transport access, energy efficiency, and the long-term maintenance budgets in neighboring districts.</p>
        <p>Its report explains the remaining trade-offs and the dates when residents can submit further comments.</p>
      </article></main></body></html>
    HTML
  end

  def author_widget(path = '/authors/alex-morgan', attributes: '')
    <<~HTML
      <div class="widget" #{attributes}><address class="byline__author">
        <a rel="author" title="Alex Morgan" href="#{path}">Alex Morgan</a>
      </address></div>
    HTML
  end

  it 'restores the uniquely owned visible author destination without copying a related author' do
    authors = "#{author_widget}<aside>#{author_widget("/authors/unrelated")}</aside>"
    with_url_page('https://publisher.example/articles/housing-review-123456', focal_author_page(authors)) do |page|
      original = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload['readerMode']).to be(false)
      expect(payload['byline']).to eq('Alex Morgan')
      expect(payload['html']).to include('href="https://publisher.example/authors/alex-morgan"')
      expect(payload['markdown'].scan('[Alex Morgan](https://publisher.example/authors/alex-morgan)').length).to eq(1)
      expect(payload['markdown']).not_to include('/authors/unrelated')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'rejects hidden, related-only, foreign-origin, and ambiguous author destinations' do
    [
      author_widget(attributes: 'hidden'),
      "<aside>#{author_widget}</aside>",
      "<div class='related-stories'>#{author_widget}</div>",
      author_widget('https://other.example/authors/alex-morgan'),
      "#{author_widget}#{author_widget("/authors/another-alex-morgan")}"
    ].each do |authors|
      with_url_page('https://publisher.example/articles/housing-review-123456', focal_author_page(authors)) do |page|
        payload = extract_payload(page)
        expect(payload['readerMode']).to be(false)
        expect(payload['markdown']).not_to include('/authors/')
        expect(payload['markdown']).to include('Residents reviewed the housing proposal', 'Its report explains the remaining trade-offs')
      end
    end
  end
end
