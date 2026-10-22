RSpec.describe 'inferred byline heading anchors' do
  include_context 'extractor integration helpers'

  def heading_anchor_paragraphs
    [
      'This complete publication explains the research method, its implementation, and the independent evidence ' \
      'supporting the result. Every relevant qualification remains part of the article.',
      'The implementation is presented with reproducible examples, complete explanations, and explicit references ' \
      'so that readers can evaluate the method and its practical limitations.',
      'The biography describes the contributor and the background to this publication. Its ordinary paragraph ' \
      'remains authored content alongside the section heading and the published method.'
    ]
  end

  def heading_anchor_page(heading, metadata: '')
    <<~HTML
      <html><head><title>A complete research method</title>#{metadata}</head><body><main><article>
        <h1>A complete research method</h1>
        <p>#{heading_anchor_paragraphs[0]}</p><p>#{heading_anchor_paragraphs[1]}</p>
        <pre><code>author = "literal program value"
      return author</code></pre>
        <section>#{heading}<p>#{heading_anchor_paragraphs[2]}</p>
          <p>Read the <a href="/methods/complete">complete method</a> and its independently published evidence.</p>
        </section>
      </article></main></body></html>
    HTML
  end

  def inspect_heading_anchor(heading, expected, metadata: '')
    with_url_page('https://journal.publication.example.test/research/method', heading_anchor_page(heading, metadata: metadata)) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      expect(payload['byline']).to eq(expected)
      heading_anchor_paragraphs.each { |paragraph| expect(payload['markdown']).to include(paragraph) }
      expect(payload['markdown']).to include("author = \"literal program value\"\nreturn author")
      expect(payload['markdown']).to include('[complete method](https://journal.publication.example.test/methods/complete)')
      yield payload if block_given?
    end
  end

  it 'preserves a biography heading whose only marker is its label-derived identifier' do
    inspect_heading_anchor('<h3 id="about-the-author">About the author</h3>', nil) do |payload|
      expect(payload['html']).to include('About the author')
      expect(payload['markdown']).to include('### About the author')
    end
  end

  it 'recognizes underscore-separated section identifiers without guessing a person' do
    inspect_heading_anchor('<h3 id="author_information">Author information</h3>', nil) do |payload|
      expect(payload['markdown']).to include('### Author information')
    end
  end

  it 'does not let punctuation in the heading establish attribution' do
    inspect_heading_anchor('<h3 id="about-the-author">About the author!</h3>', nil) do |payload|
      expect(payload['markdown']).to include('### About the author!')
    end
  end

  it 'retains an identifier that independently names an attribution field' do
    inspect_heading_anchor('<h3 id="author-name">Ari Reader</h3>', 'Ari Reader')
  end

  it 'retains a genuine author class even when the identifier follows the name' do
    inspect_heading_anchor('<h3 id="author-ari-reader" class="author-name">Author Ari Reader</h3>', 'Author Ari Reader')
  end

  it 'retains explicit author semantics on a heading' do
    inspect_heading_anchor('<h3 id="team-author" rel="author">Team Author</h3>', 'Team Author')
  end

  it 'preserves an independently declared author and the complete biography heading' do
    inspect_heading_anchor('<h3 id="about-the-author">About the author</h3>', 'Ari Reader', metadata: '<meta name="author" content="Ari Reader">') do |payload|
      expect(payload['markdown']).to include('### About the author')
    end
  end
end
