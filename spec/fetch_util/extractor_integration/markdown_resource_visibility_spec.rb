# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Markdown resource visibility' do
  include_context 'extractor integration helpers'

  it 'retains HTTP images with author-empty alternatives without inventing labels or changing literal programs' do
    with_url_page('https://docs.publication.example.test/resources/', <<~HTML) do |page|
      <html><head><title>Image resources</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main><article class="md-content__inner md-typeset"><h1>Image resources</h1>
      <p>The complete published image resources belong to this documentation and have intentionally empty alternatives.</p>
      <p><img alt="" src="https://images.example.test/illustration.webp"></p>
      <pre><code>![](https://images.example.test/literal.webp)</code></pre>
      <p>The original literal program and source image attributes must remain unchanged in every extraction.</p>
      </article></main></body></html>
    HTML
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('![](https://images.example.test/illustration.webp)')
      expect(payload.fetch('markdown')).to match(%r{```[^\n]*\n!\[\]\(https://images\.example\.test/literal\.webp\)\n```})
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
