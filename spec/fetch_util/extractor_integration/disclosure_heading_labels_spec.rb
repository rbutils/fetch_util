require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Complete physical disclosure heading labels' do
  include_context 'extractor integration helpers'

  def disclosure_heading_page(body, docs: false)
    generator = docs ? '<meta name="generator" content="MkDocs 1.6">' : '<meta property="og:type" content="website">'
    "<html><head><title>Publication toolkit</title>#{generator}</head><body><main class=\"md-main\">#{body}</main></body></html>"
  end

  it 'retains complete short and long heading labels without opening closed answers' do
    long_label = "#{("Independent publication evidence and complete resource ownership " * 8).strip}?"
    labels = ['API?', 'Self-hosted?', long_label]
    program = "const heading = '<button aria-expanded=\"false\">API?</button>';\nprint(heading); "
    html = disclosure_heading_page(<<~HTML, docs: true)
      <article class="md-content__inner md-typeset"><h1>Publication toolkit</h1>
      <p>Every published question keeps its complete visible heading and independent resource.</p>
      <h3><button type="button" aria-expanded="false">API?</button></h3>
      <div hidden><p>Unpublished closed answer</p><pre>closedProgramme()</pre></div>
      <h3><button type="button" aria-expanded="true">Self-hosted?</button></h3>
      <div><p>The complete open answer retains <a href="../reference/">its independent reference</a>.</p></div>
      <h3><button type="button" aria-expanded="false">#{CGI.escapeHTML(long_label)}</button></h3>
      <pre><code>#{CGI.escapeHTML(program)}</code></pre></article>
    HTML
    with_url_page('https://publication.example.test/handbook/questions/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      expect(native.css('h3').map(&:text)).to eq(labels)
      labels.each { |label| expect(payload.fetch('markdown')).to include("### #{label}") }
      expect(payload.fetch('markdown')).to include('The complete open answer retains', 'https://publication.example.test/handbook/reference/')
      expect(payload.fetch('markdown')).not_to include('Unpublished closed answer', 'closedProgramme()')
      expect(native.at_css('pre').text).to eq(program)
      expect(payload.fetch('markdown')).to include(program)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains independently repeated short labels on a semantic software homepage' do
    labels = ['Product vs. Tools', 'API?', 'Self-hosted?', 'API?']
    controls = labels.map { |label| "<h3><button type=\"button\" aria-expanded=\"false\" data-state=\"closed\">#{label}</button></h3>" }.join
    html = disclosure_heading_page(<<~HTML)
      <h1>Publication toolkit</h1>
      <p>The open-source publication framework retains complete independent evidence, questions and software documentation.</p>
      <p><a href="/docs/">Documentation</a> and <a href="/start/">Get started</a> describe the complete public framework.</p>
      <section><h2>Complete questions</h2>#{controls}</section>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(Nokogiri::HTML5(payload.fetch('html')).css('h3').map(&:text)).to eq(labels)
      expect(payload.fetch('markdown').scan(/^### API\?$/).size).to eq(2)
      expect(payload.fetch('markdown')).to include('### Product vs. Tools', '### Self-hosted?')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps menu, player, form, hidden and unrelated controls distinct from authored headings' do
    html = disclosure_heading_page(<<~HTML, docs: true)
      <article class="md-content__inner md-typeset"><h1>Publication toolkit</h1>
      <p>The complete published explanation remains independent of interface controls.</p>
      <h3><button type="button" aria-expanded="false">Play</button></h3>
      <nav><h3><button type="button" aria-expanded="false">Navigation control</button></h3></nav>
      <form><h3><button type="button" aria-expanded="false">Form control</button></h3></form>
      <h3><button type="button" aria-expanded="false" aria-haspopup="menu">Menu control</button></h3>
      <h3 hidden><button type="button" aria-expanded="false">Hidden question?</button></h3>
      <h3>Published heading <button type="button" aria-expanded="false">Expand</button></h3>
      <button type="button" aria-expanded="false">Unrelated control</button>
      <details><summary>Closed resources</summary><h3><button aria-expanded="false">Closed question?</button></h3></details>
      </article>
    HTML
    with_url_page('https://publication.example.test/handbook/questions/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('Published heading')
      expect(payload.fetch('markdown')).not_to include(
        'Play', 'Navigation control', 'Form control', 'Menu control', 'Hidden question?', 'Expand', 'Unrelated control', 'Closed question?'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
