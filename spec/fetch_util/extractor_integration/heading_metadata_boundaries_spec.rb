require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Physical heading metadata word boundaries' do
  include_context 'extractor integration helpers'

  def heading_metadata_page(generator, heading, program)
    introduction = (1..8).map do |number|
      "<p>Section #{number} preserves the complete independently authored publication introduction before its physical title.</p>"
    end.join
    <<~HTML
      <html><head><title>Independent publisher catalogue</title>
      <meta name="generator" content="#{generator}"></head><body><main>
      <article class="md-content__inner md-typeset"><div class="entry-content">
      #{introduction}<h1 class="entry-title">#{heading}</h1>
      <p>The complete article explains deployment ownership and preserves every independent word and resource.</p>
      <p><a href="../reference/">First physical reference</a></p>
      <p><a href="../reference/">Second physical reference</a></p>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
      <p hidden>UNPUBLISHED_HEADING_METADATA_PROSE</p>
      <details><summary>Additional release controls</summary><pre><code>CLOSED_HEADING_METADATA_PROGRAM</code></pre></details>
      </div></article></main></body></html>
    HTML
  end

  def expect_heading_metadata(generator, heading, title)
    program = "const template = \"<h1>Literal<br>markup</h1>\";\nrun(template);  "
    html = heading_metadata_page(generator, heading, program)
    with_url_page('https://publication.example.test/guide/heading-metadata/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('title')).to eq(title)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(native.css('h1').size).to eq(1)
      expect(payload.fetch('markdown').lines.grep(/\A# /).size).to eq(1)
      expect(payload.fetch('markdown')).to include(program)
      visible_programs = native.css('pre').reject do |node|
        node.ancestors('details').any? { |details| details['open'].nil? }
      end
      expect(visible_programs.map(&:text)).to eq([program])
      expect(payload.fetch('markdown').scan('https://publication.example.test/guide/reference/').size).to eq(2)
      (1..8).each do |number|
        expect(payload.fetch('markdown')).to include(
          "Section #{number} preserves the complete independently authored publication introduction before its physical title."
        )
      end
      expect(payload.fetch('markdown')).not_to include('UNPUBLISHED_HEADING_METADATA_PROSE', 'CLOSED_HEADING_METADATA_PROGRAM')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves physical breaks in WordPress heading metadata without splitting inline words' do
    expect_heading_metadata('WordPress 6.8', 'Continuous<br>micro<em>service</em> delivery',
                            'Continuous microservice delivery')
  end

  it 'preserves physical breaks in shared documentation heading metadata after complete introduction paragraphs' do
    expect_heading_metadata('MkDocs 1.6', 'Continuous<br>micro<em>service</em> delivery',
                            'Continuous microservice delivery')
  end

  it 'retains adjacent inline word fragments when there is no physical break' do
    expect_heading_metadata('WordPress 6.8', 'Micro<em>service</em> deployment', 'Microservice deployment')
  end

  it 'does not turn a source-hidden break into a visible word boundary' do
    expect_heading_metadata('WordPress 6.8', 'Micro<span hidden><br></span><em>service</em> deployment',
                            'Microservice deployment')
  end
end
