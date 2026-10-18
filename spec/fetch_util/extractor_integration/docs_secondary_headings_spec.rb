# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration - secondary documentation headings' do
  include_context 'extractor integration helpers'

  %w[starlight stldocs].each do |framework|
    it "preserves every authored secondary H1 in #{framework} documentation" do
      root_class = framework == 'starlight' ? 'sl-markdown-content' : 'stldocs-content'
      sidebar_class = framework == 'starlight' ? '' : 'stldocs-sidebar'
      body_class = framework == 'starlight' ? '' : 'stldocs-root'
      html = <<~HTML
        <html><head><title>Published examples | Documentation</title>
          <meta name="generator" content="Astro v5.0.0">
          <meta property="og:site_name" content="Starlight">
        </head><body class="#{body_class}">
          <aside id="starlight__sidebar" class="#{sidebar_class}"><h1>Navigation heading</h1></aside>
          <main data-pagefind-body><article class="#{root_class}">
            <h1 id="published">Published examples</h1>
            <p>The complete introduction explains how to run each independently published example.</p>
            <section><h1 id="first-example"><a href="/first/">Example</a></h1>
              <p>The first example retains its complete explanation and <a href="/resources/">resources</a>.</p>
              <pre><code>SELECT 'first' AS label;
        SELECT 1 AS value;</code></pre>
            </section>
            <section><h1 id="second-example"><a href="/second/">Example</a></h1>
              <p>The second example is a different physical section with the same heading label.</p>
              <pre><code>SELECT 'second' AS label;
        SELECT 2 AS value;</code></pre>
            </section>
            <section hidden><h1>Hidden heading</h1><p>Hidden program explanation.</p></section>
          </article></main>
        </body></html>
      HTML

      with_url_page('https://docs.publication.example.test/examples/', html) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract(page)
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
        expect(payload['title']).to eq('Published examples')
        document = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expect(document.css('h1').map(&:text)).to eq(['Published examples', 'Example', 'Example'])
        expect(document.css('h1 a').map { |link| [link.text, link['href']] }).to eq(
          [
            ['Example', 'https://docs.publication.example.test/first/'],
            ['Example', 'https://docs.publication.example.test/second/']
          ]
        )
        expect(document.css('pre').map(&:text)).to eq(
          [
            "SELECT 'first' AS label;\nSELECT 1 AS value;",
            "SELECT 'second' AS label;\nSELECT 2 AS value;"
          ]
        )
        expect(payload.fetch('markdown')).to include(
          '[Example](https://docs.publication.example.test/first/)',
          '[Example](https://docs.publication.example.test/second/)',
          'The first example retains its complete explanation and',
          'The second example is a different physical section with the same heading label.',
          "SELECT 'first' AS label;\nSELECT 1 AS value;",
          "SELECT 'second' AS label;\nSELECT 2 AS value;"
        )
        expect(payload.fetch('html') + payload.fetch('markdown')).not_to include('Navigation heading', 'Hidden heading', 'Hidden program explanation.')
      end
    end
  end
end
