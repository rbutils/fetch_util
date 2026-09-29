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

  def focal_author_destinations(markdown)
    markdown.scan(/\[Alex Morgan\]\((\S+?)(?: "Alex Morgan")?\)/).flatten
  end

  def focal_author_candidate(page, payload)
    root = File.expand_path('../../../websieve', __dir__)
    paths = File.readlines(File.join(root, 'manifest.txt'), chomp: true).reject(&:empty?)
    source = paths.map { |path| File.read(File.join(root, path)) }.join("\n")
    probe = source.sub('})(window);', 'window.__focalAuthorCandidate = readerBylineSourceAuthorLink; })(window);')
    page.add_script_tag(content: probe)
    page.evaluate("window.__focalAuthorCandidate(#{payload.to_json}, 'Alex Morgan')")
  end

  it 'restores the uniquely owned visible author destination without copying a related author' do
    authors = "#{author_widget}<aside>#{author_widget("/authors/unrelated")}</aside>"
    with_url_page('https://publisher.example/articles/housing-review-123456', focal_author_page(authors)) do |page|
      original = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload['readerMode']).to be(false)
      expect(payload['byline']).to eq('Alex Morgan')
      expect(payload['html']).to include('href="https://publisher.example/authors/alex-morgan"')
      expect(focal_author_destinations(payload['markdown'])).to eq(['https://publisher.example/authors/alex-morgan'])
      expect(payload['markdown']).not_to include('/authors/unrelated')
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'rejects unsafe author restoration while retaining visible destinations already in the source' do
    [
      [author_widget(attributes: 'hidden'), []],
      ["<aside>#{author_widget}</aside>", []],
      ["<div class='related-stories'>#{author_widget}</div>", ['https://publisher.example/authors/alex-morgan']],
      [author_widget('https://other.example/authors/alex-morgan'), ['https://other.example/authors/alex-morgan']],
      ["#{author_widget}#{author_widget("/authors/another-alex-morgan")}",
       ['https://publisher.example/authors/alex-morgan', 'https://publisher.example/authors/another-alex-morgan']]
    ].each do |authors, visible_destinations|
      with_url_page('https://publisher.example/articles/housing-review-123456', focal_author_page(authors)) do |page|
        original = page.evaluate('document.body.innerHTML')
        payload = extract_payload(page)
        expect(payload['readerMode']).to be(false)
        expect(payload['byline']).to eq('Alex Morgan')
        expect(focal_author_candidate(page, payload)).to be_nil
        expect(focal_author_destinations(payload['markdown'])).to eq(visible_destinations)
        expect(payload['markdown']).to include('Residents reviewed the housing proposal', 'Its report explains the remaining trade-offs')
        expect(page.evaluate('document.body.innerHTML')).to eq(original)
      end
    end
  end
end
