# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Material with a CTA-only layout marker' do
  include_context 'extractor integration helpers'

  def publication_page(engine, content)
    article = if engine == 'WordPress'
                <<~HTML
                  <main><article id="post-17"><header><h1 class="entry-title">Published research notes</h1></header>
                  <div class="entry-content" itemprop="articleBody">#{content}</div></article></main>
                HTML
              else
                <<~HTML
                  <main class="md-main"><article class="md-content__inner md-typeset">
                  <h1>Published research notes</h1>#{content}</article></main>
                HTML
              end
    <<~HTML
      <html><head><title>Published research notes</title><meta name="generator" content="#{engine}"></head>
      <body>#{article}</body></html>
    HTML
  end

  %w[WordPress MkDocs].each do |engine|
    it "preserves independent article paragraphs and references with CTA-only markers in #{engine}" do
      program = "measurements = [17, 29]\nprint(measurements)"
      opening = 'The published research notes describe the complete observations and the interpretation of the measurements.'
      first = 'Discuss these measurements in the published discussion notes.'
      second = 'A separate research group also cites the same discussion notes.'
      closing = 'The complete concluding explanation follows both independent references and the original literal program.'
      content = <<~HTML
        <p>#{opening}</p>
        <div class="discussion-cta"><p>Discuss these measurements in the <a href="/discussion/">published discussion notes</a>.</p></div>
        <section class="research_cta"><p>A separate research group also cites the same <a href="/discussion/">discussion notes</a>.</p></section>
        <pre><code>#{program}</code></pre><p>#{closing}</p>
      HTML
      url = 'https://publication.example.test/research/'
      destination = 'https://publication.example.test/discussion/'
      with_url_page(url, publication_page(engine, content)) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        document = Nokogiri::HTML5(payload.fetch('html'))
        references = document.css('a[href]').select { |node| node['href'] == destination }
        expect(references.map(&:text)).to eq(['published discussion notes', 'discussion notes'])
        expect(document.css('p').map(&:text)).to include(opening, first, second, closing)
        expect(document.css('pre code').map(&:text)).to eq([program])
        markdown = payload.fetch('markdown')
        expect(markdown).to include(opening, closing, "```\n#{program}\n```",
                                    "[published discussion notes](#{destination})", "[discussion notes](#{destination})")
        expect(markdown.index("[published discussion notes](#{destination})"))
          .to be < markdown.index("[discussion notes](#{destination})")
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'retains independent promotion evidence and source visibility as negative controls' do
    program = "measurements = [17, 29]\nprint(measurements)"
    opening = 'The research notes publish the complete measurements independently of the subscription and advertising interfaces.'
    closing = 'This final explanation remains after the interfaces and the complete literal program.'
    content = <<~HTML
      <p>#{opening}</p>
      <div class="newsletter-cta"><p>Subscribe to our newsletter for weekly promotions.</p>
      <a href="/newsletter/">Subscribe now</a></div>
      <div class="advertisement-cta"><p>Advertisement from an independent promotional supplier.</p>
      <a href="/advertisement/">Supplier advertisement</a></div>
      <div class="research-cta" hidden><p>Unpublished research discussion.</p><a href="/hidden/">Hidden notes</a></div>
      <pre><code>#{program}</code></pre><p>#{closing}</p>
    HTML
    with_url_page('https://publication.example.test/controls/', publication_page('WordPress', content)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      document = Nokogiri::HTML5(payload.fetch('html'))
      expect(document.css('pre code').map(&:text)).to eq([program])
      expect(document.css('p').map(&:text)).to include(opening, closing)
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        expect(value).not_to include('/newsletter/', '/advertisement/', '/hidden/', 'Unpublished research discussion.')
      end
      expect(payload.fetch('markdown')).to include("```\n#{program}\n```", opening, closing)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
