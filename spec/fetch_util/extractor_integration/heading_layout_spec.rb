require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Physical heading layout' do
  include_context 'extractor integration helpers'

  def heading_layout_page(body)
    <<~HTML
      <html><head><title>Complete publication guide</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Complete publication guide</h1>#{body}</article></main></body></html>
    HTML
  end

  it 'retains physical heading levels and inline formatting through nested layout wrappers' do
    html = heading_layout_page(<<~HTML)
      <h2><div>Dataset<span> announcements and <em>complete</em> updates</span></div></h2>
      <p>Every published record belongs to this section, with the complete explanation retained.</p>
      <h3><div>Regional</div><div><strong>reference</strong> resources</div></h3>
      <p>Independent destination <a href="../reference/">full reference</a> follows both headings.</p>
    HTML
    with_url_page('https://publication.example.test/guide/layout/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('## Dataset announcements and _complete_ updates',
                                  '### Regional **reference** resources',
                                  '[full reference](https://publication.example.test/guide/reference/)')
      expect(markdown.index('## Dataset')).to be < markdown.index('Every published record')
      expect(markdown.index('Every published record')).to be < markdown.index('### Regional')
      expect(Nokogiri::HTML5(payload.fetch('html')).css('h2').map { |h| h.text.gsub(/\s+/, ' ').strip }).to include('Dataset announcements and complete updates')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves heading-owned references, images and complete literal inline programs' do
    html = heading_layout_page(<<~HTML)
      <h2><div>Deployment <a href="../manual/"><strong>reference</strong></a> and <code>mode  --flag</code></div></h2>
      <p>Complete accompanying deployment instructions remain independently readable.</p>
      <h3><div>Publication image <img src="../figure.png" alt="Independent diagram"></div></h3>
      <p>The physical image and both heading roles are authored material, not navigation.</p>
    HTML
    with_url_page('https://publication.example.test/guide/layout/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect(markdown).to include('## Deployment [**reference**](https://publication.example.test/guide/manual/) and `mode  --flag`',
                                  '### Publication image ![Independent diagram](https://publication.example.test/guide/figure.png)')
      expect(markdown.scan('https://publication.example.test/guide/manual/').size).to eq(1)
      expect(markdown.scan('https://publication.example.test/guide/figure.png').size).to eq(1)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps hidden and closed heading bodies hidden and leaves literal program markup unchanged' do
    program = "const markup = \"<h2><div>Literal heading</div></h2>\";\nprint(markup);"
    html = heading_layout_page(<<~HTML)
      <h2>Visible controls and complete programs</h2>
      <p>All ordinary source text remains outside the independently declared program.</p>
      <h3 hidden><div>Unpublished heading label</div></h3>
      <details><summary>Additional reference controls</summary><h3><div>Closed heading body</div></h3>
      <pre><code>closed_program();</code></pre></details>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
    HTML
    with_url_page('https://publication.example.test/guide/layout/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = extract(page).fetch('markdown')
      expect(markdown).to include('## Visible controls and complete programs', program)
      expect(markdown).not_to include('Unpublished heading label', 'Closed heading body', 'closed_program();')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
