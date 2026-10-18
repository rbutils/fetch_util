# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'fetch_util preserves a documentation disclosure summary', type: :extractor_integration do
  include_context 'extractor integration helpers'

  [false, true].each do |open|
    it "retains the complete visible summary with disclosure open=#{open}" do
      html = <<~HTML
        <html><head><title>Published release reference</title>
        <meta property="og:site_name" content="HashiCorp Developer"></head><body>
        <nav>Documentation navigation</nav><aside>Reference sidebar</aside>
        <main><article>
        <h1>Published release reference</h1>
        <p>The published reference retains the complete public description and independent resource destinations.</p>
        <details id="release-options" #{open ? "open" : ""}>
          <summary>Release <a href="https://manual.publication.example.test/version-two"><strong>v2 options</strong></a></summary>
          <p>The RELEASE_BODY_TOKEN description includes the complete versioned reporting procedure.</p>
          <p><a href="https://manual.publication.example.test/release-body">Release body resource</a></p>
          <pre><code class="language-python">print("release body")\nprint("complete")</code></pre>
        </details>
        <details style="display:none"><summary>HIDDEN_SUMMARY_TOKEN</summary><p>HIDDEN_BODY_TOKEN</p></details>
        <p>The complete closing publication paragraph remains outside the disclosure.</p>
        <p><a href="https://manual.publication.example.test/guide">Publication guide</a></p>
        </article></main></body></html>
      HTML
      with_url_page('https://manual.publication.example.test/reference/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page, reader_mode: false)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        body = Nokogiri::HTML5.fragment(payload.fetch('html'))
        details = body.at_css('details#release-options')
        expect(details).not_to be_nil
        expect(details.key?('open')).to eq(open)
        summary = details.at_css('summary')
        expect(summary).not_to be_nil
        expect(summary.text).to eq('Release v2 options')
        expect(summary.css('a[href]').map { |link| [link['href'], link.text] }).to eq(
          [['https://manual.publication.example.test/version-two', 'v2 options']]
        )
        markdown = payload.fetch('markdown')
        reading = markdown.gsub('\\_', '_')
        expect(markdown).to include('### Release', '[**v2 options**](https://manual.publication.example.test/version-two)')
        expect(markdown).to include('complete closing publication paragraph', 'https://manual.publication.example.test/guide')
        expect(reading).not_to include('HIDDEN_SUMMARY_TOKEN', 'HIDDEN_BODY_TOKEN', 'Reference sidebar')
        if open
          expect(reading).to include('RELEASE_BODY_TOKEN')
          expect(markdown).to include(
            'https://manual.publication.example.test/release-body',
            "print(\"release body\")\nprint(\"complete\")"
          )
        else
          expect(reading).not_to include('RELEASE_BODY_TOKEN')
          expect(markdown).not_to include(
            'https://manual.publication.example.test/release-body', 'print("release body")'
          )
        end
      end
    end
  end
end
