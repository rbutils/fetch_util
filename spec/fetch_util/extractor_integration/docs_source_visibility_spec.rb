# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'fetch_util documentation source visibility', type: :extractor_integration do
  include_context 'extractor integration helpers'

  %w[sphinx readthedocs mkdocs].each do |framework|
    it "prunes hidden source resources before inert cleanup in #{framework}" do
      article = <<~HTML
        <h1>Published package notes</h1>
        <p id="visible-prose">Complete visible instructions retain the <a href="https://reference.publication.example.test/visible">published reference</a> and their closing words.</p>
        <ul><li><a href="https://reference.publication.example.test/available">Available resources</a> remain in their authored list.</li></ul>
        <h2>Literal example</h2>
        <pre id="visible-program"><code>print("before")
        <a id="line-target" style="display:none"></a><a href="https://code.publication.example.test/example#line-target">print("after")</a></code></pre>
        <p style="display:none"><a href="https://hidden.publication.example.test/private">Hidden source reference</a></p>
        <div style="visibility:hidden"><p>Hidden ancestor prose must stay unavailable.</p><pre><code>print("hidden ancestor")</code></pre></div>
        <pre style="display:none"><code>print("hidden program")</code></pre>
        <details><summary>Closed explanation with <a href="https://reference.publication.example.test/summary">summary reference</a></summary><p>Closed answer must not become visible Markdown.</p></details>
        <p>Complete closing notes remain in their original position.</p>
      HTML
      owner = case framework
              when 'sphinx' then %(<div class="document">#{article}</div>)
              when 'readthedocs' then %(<div class="wy-nav-content"><div class="rst-content">#{article}</div></div>)
              else %(<main class="md-main"><article class="md-content__inner md-typeset">#{article}</article></main>)
              end
      html = %(<html><head><title>Published package notes</title><meta name="generator" content="#{framework}"></head><body>#{owner}</body></html>)
      with_url_page('https://manual.publication.example.test/reference/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        program = page.evaluate('document.querySelector("#visible-program").textContent')
        payload = extract(page, reader_mode: false)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        body = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expect(body.at_css('#visible-prose').text).to eq('Complete visible instructions retain the published reference and their closing words.')
        expect(body.css('pre').map(&:text)).to eq([program])
        expect(body.at_css('#line-target')['id']).to eq('line-target')
        expect(body.at_css('#visible-program a[href]')['href']).to eq('https://code.publication.example.test/example#line-target')
        expect(body.at_css('details')).not_to be_nil
        expect(body.at_css('details')['open']).to be_nil
        markdown_body = Nokogiri::HTML5.fragment(payload.fetch('markdown'))
        expect(markdown_body.css('pre code').map(&:text)).to eq([program])
        expect(markdown_body.at_css('pre #line-target')['id']).to eq('line-target')
        expect(payload.fetch('markdown')).to include(
          'https://reference.publication.example.test/visible', 'https://reference.publication.example.test/available',
          'https://reference.publication.example.test/summary', 'https://code.publication.example.test/example#line-target',
          'Complete closing notes'
        )
        expect(payload.fetch('html') + payload.fetch('markdown')).not_to include(
          'hidden.publication.example.test', 'Hidden ancestor prose', 'print("hidden ancestor")', 'print("hidden program")'
        )
        expect(payload.fetch('markdown')).not_to include('Closed answer must not become visible Markdown.')
      end
    end
  end
end
