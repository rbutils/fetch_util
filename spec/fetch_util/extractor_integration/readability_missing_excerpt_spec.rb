# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned Reader excerpts' do
  include_context 'extractor integration helpers'

  def missing_excerpt_probe(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    page.add_script_tag(content: source.sub('})(window);', 'window.__missingExcerptProof = sourceOwnedReaderMissingExcerpt; })(window);'))
  end

  it 'uses only a complete visible first paragraph when one source article owns the heading and Reader body' do
    lead = 'The opening paragraph reports the complete verified result, its original source context, and the purpose of the public article.'
    paragraphs = (1..12).map do |index|
      "<p>Published detail #{index} documents the original observation with enough substantive context to retain the whole report.</p>"
    end.join
    html = <<~HTML
      <html><body><main><div class="publication">
        <h1>Public article with a complete opening</h1>
        <figure><figcaption>Photograph of the published document</figcaption></figure>
        <div class="article-body"><p>#{lead}</p>#{paragraphs}</div>
      </div></main></body></html>
    HTML

    with_url_page('https://reports.example/complete-opening', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      missing_excerpt_probe(page)
      article = { title: 'Public article with a complete opening', excerpt: nil,
                  content: "<div><p>#{lead}</p>#{paragraphs}</div>" }
      result = page.evaluate("window.__missingExcerptProof(#{JSON.generate(article)}, null)")

      expect(result).to eq(lead)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not fabricate an excerpt from ambiguous, unrelated, credited, or already summarized content' do
    caption = 'The photo credit describes a photograph of the newsroom and the original image supplier.'
    lead = 'The first real paragraph reports verified public facts in a complete and source-owned article sentence.'
    next_paragraph = 'The following paragraph supplies additional independently corroborated source facts for readers.'
    html = <<~HTML
      <main><div class="publication"><h1>Public article</h1>
        <figure><p>#{caption}</p></figure>
        <p>#{lead}</p><p>#{next_paragraph}</p>
        <p>A third source paragraph establishes the remaining publication details and context.</p>
      </div></main>
    HTML

    with_url_page('https://reports.example/public-article', html) do |page|
      missing_excerpt_probe(page)
      selected = "<div><p>#{lead}</p><p>#{next_paragraph}</p></div>"
      article = { title: 'Public article', excerpt: nil, content: selected }
      expect(page.evaluate("window.__missingExcerptProof(#{JSON.generate(article)}, null)")).to eq(lead)
      expect(page.evaluate("window.__missingExcerptProof(#{JSON.generate(article.merge(excerpt: "Existing summary"))}, null)")).to be_nil
      expect(page.evaluate("window.__missingExcerptProof(#{JSON.generate(article)}, {excerpt: 'Metadata summary'})")).to be_nil
      unrelated = article.merge(content: "<div><p>#{caption}</p><p>#{next_paragraph}</p></div>")
      expect(page.evaluate("window.__missingExcerptProof(#{JSON.generate(unrelated)}, null)")).to be_nil
      page.evaluate("document.querySelector('.publication').insertAdjacentHTML('afterend', '<h1>A second article</h1>')")
      expect(page.evaluate("window.__missingExcerptProof(#{JSON.generate(article)}, null)")).to be_nil
    end
  end
end
