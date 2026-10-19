require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Physical heading line breaks' do
  include_context 'extractor integration helpers'

  def heading_break_page(body)
    <<~HTML
      <html><head><title>Complete regional publication</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Complete regional publication</h1>#{body}</article></main></body></html>
    HTML
  end

  it 'retains heading levels and complete word boundaries across leading, interior and trailing breaks' do
    html = heading_break_page(<<~HTML)
      <h2><br>Complete<br><em>regional</em> guide<br></h2>
      <p>The complete introduction remains before the lower-level access heading.</p>
      <h5><br>Dataset access</h5>
      <p>Every dataset and its complete explanation remain independently readable.</p>
      <h6>Supplemental<br><strong>reading</strong><br></h6>
    HTML
    with_url_page('https://publication.example.test/guide/breaks/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('## Complete _regional_ guide',
                                                   '##### Dataset access',
                                                   '###### Supplemental **reading**')
      expect(Nokogiri::HTML5(payload.fetch('html')).css('h2,h5,h6').map(&:name)).to eq(%w[h2 h5 h6])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves heading-owned reference, image and complete literal inline-program values' do
    html = heading_break_page(<<~HTML)
      <h3><br>Deployment <a href="../manual/"><strong>reference</strong></a><br>and <code>mode  --flag</code></h3>
      <p>All deployment instructions remain between the independent physical headings.</p>
      <h4>Publication<br><img src="../diagram.png" alt="Independent diagram"><br>resources</h4>
    HTML
    with_url_page('https://publication.example.test/guide/breaks/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect(markdown).to include('### Deployment [**reference**](https://publication.example.test/guide/manual/) and `mode  --flag`',
                                  '#### Publication ![Independent diagram](https://publication.example.test/guide/diagram.png) resources')
      expect(markdown.scan('https://publication.example.test/guide/manual/').size).to eq(1)
      expect(markdown.scan('https://publication.example.test/guide/diagram.png').size).to eq(1)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps hidden and closed heading bodies hidden and leaves literal program markup unchanged' do
    program = "const markup = \"<h5><br>Literal heading<br></h5>\";\nprint(markup);"
    html = heading_break_page(<<~HTML)
      <h2>Visible publication controls</h2><p>The complete visible prose remains.</p>
      <h5 hidden><br>Unpublished heading</h5>
      <details><summary>Additional publication controls</summary><h6><br>Closed heading</h6>
      <pre><code>closed_program();</code></pre></details>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
    HTML
    with_url_page('https://publication.example.test/guide/breaks/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect(markdown).to include('## Visible publication controls', program)
      expect(markdown).not_to include('Unpublished heading', 'Closed heading', 'closed_program();')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
