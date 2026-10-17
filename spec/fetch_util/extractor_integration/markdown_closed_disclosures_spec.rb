# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Closed disclosures in Markdown' do
  include_context 'extractor integration helpers'

  it 'keeps closed disclosure summaries and open content without exposing closed programs or resources' do
    with_url_page('https://docs.publication.example.test/disclosures/', <<~HTML) do |page|
      <html><head><title>Disclosure resources</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main><article class="md-content__inner md-typeset"><h1>Disclosure resources</h1>
      <p>The published guide has independently open and closed sections with complete source-owned resources.</p>
      <details><summary>Closed examples</summary><p>Closed authored explanation.</p>
        <img alt="Closed illustration" src="https://images.example.test/closed.webp"><pre>closed program value</pre></details>
      <details open><summary>Open examples</summary><p>Open authored explanation.</p>
        <img alt="Open illustration" src="https://images.example.test/open.webp"><pre>open program value</pre></details>
      <p>Disclosure state comes from the original document and does not authorize opening any closed examples.</p>
      </article></main></body></html>
    HTML
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Closed examples', 'Open examples', 'Open authored explanation.')
      expect(markdown).to include('https://images.example.test/open.webp', 'open program value')
      expect(markdown).not_to include('Closed authored explanation.', 'closed.webp', 'closed program value')
      expect(payload.fetch('html')).to include('<details>', 'Closed authored explanation.', 'closed.webp', 'closed program value')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves separate summary boundaries without opening adjacent closed disclosures' do
    with_url_page('https://docs.publication.example.test/disclosure-boundaries/', <<~HTML) do |page|
      <html><head><title>Disclosure boundaries</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main><article class="md-content__inner md-typeset"><h1>Disclosure boundaries</h1>
      <p>The published guide has distinct visible questions and a deliberately open complete example.</p>
      <details><summary>First visible question</summary><p>First closed answer.</p></details>
      <details><summary>Second visible question</summary><p>Second closed answer.</p>
        <a href="https://resources.example.test/closed">Closed resource</a></details>
      <details open><summary>Open visible question</summary><p>Open authored answer.</p>
        <pre><code class="language-html">&lt;details&gt;&lt;summary&gt;Literal question&lt;/summary&gt;Literal answer&lt;/details&gt;</code></pre>
        <a href="https://resources.example.test/open">Open resource</a></details>
      <p>These physically separate questions keep their complete reading order and original disclosure state.</p>
      </article></main></body></html>
    HTML
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      blocks = markdown.split(/\n(?:[ \t]*\n)+/).map(&:strip)
      expect(blocks).to include('First visible question', 'Second visible question',
                                'Open visible question', 'Open authored answer.')
      expect(blocks.index('First visible question')).to be < blocks.index('Second visible question')
      expect(markdown).to include('<details><summary>Literal question</summary>Literal answer</details>')
      expect(markdown).to include('[Open resource](https://resources.example.test/open)')
      expect(markdown).not_to include('First closed answer.', 'Second closed answer.', '/closed')
      expect(payload.fetch('html')).to include('First closed answer.', 'Second closed answer.', '/closed', '<details open')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
