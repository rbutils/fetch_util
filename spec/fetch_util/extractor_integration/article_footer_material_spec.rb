require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Physical article footer material' do
  include_context 'extractor integration helpers'

  def article_footer_page(body, docs: false)
    generator = docs ? '<meta name="generator" content="MkDocs 1.6">' : '<meta property="og:type" content="website">'
    <<~HTML
      <html><head><title>Complete publication reports</title>#{generator}</head>
      <body><main class="md-main">#{body}</main>
      <footer role="contentinfo">Global publication furniture</footer></body></html>
    HTML
  end

  it 'retains complete article-owned attributions and independent repeated references' do
    html = article_footer_page(<<~HTML, docs: true)
      <article class="md-content__inner md-typeset"><h1>Complete publication reports</h1>
      <p>The complete publication introduction remains before the independent reports.</p>
      <section><h2>Independent observations</h2>
      <blockquote><p>The first complete report retains its evidence and attribution.</p></blockquote>
      <footer>Morgan Vale, Research Director, <a href="../reference/">Publication reference</a></footer>
      <blockquote><p>The second complete report retains its independent attribution.</p></blockquote>
      <footer>Avery Reed, Platform Engineer, <a href="../reference/">Publication reference</a></footer>
      <footer>Avery Reed, Platform Engineer</footer></section></article>
    HTML
    with_url_page('https://publication.example.test/handbook/reports/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      markdown = payload.fetch('markdown')
      expect(native.text).to include('Morgan Vale, Research Director, Publication reference')
      expect(native.text.scan('Avery Reed, Platform Engineer').length).to eq(2)
      expect(markdown).to include('Morgan Vale, Research Director,', 'Avery Reed, Platform Engineer')
      expect(markdown.scan('https://publication.example.test/handbook/reference/').length).to eq(2)
      expect(markdown).to include('The first complete report retains its evidence and attribution.')
      expect(markdown).to include('The second complete report retains its independent attribution.')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains each testimonial attribution in a complete semantic landing page' do
    html = article_footer_page(<<~HTML)
      <h1>Complete publication reports</h1>
      <p>Every independent observation is published here with its complete source and attribution.</p>
      <section><h2>Published reports</h2>
      <article><h3>First report</h3><blockquote><p>The first complete observation explains every recorded result.</p></blockquote>
      <footer>Morgan Vale, Research Director</footer></article>
      <article><h3>Second report</h3><blockquote><p>The second complete observation explains its independent result.</p></blockquote>
      <footer>Avery Reed, Platform Engineer</footer></article>
      <article><h3>Third report</h3><blockquote><p>The third complete observation explains every recorded resource.</p></blockquote>
      <footer>Jordan Moss, Publication Maintainer</footer></article></section>
    HTML
    with_url_page('https://publication.example.test/reports/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      names = ['Morgan Vale, Research Director', 'Avery Reed, Platform Engineer', 'Jordan Moss, Publication Maintainer']
      names.each do |name|
        expect(Nokogiri::HTML5(payload.fetch('html')).text).to include(name)
        expect(payload.fetch('markdown')).to include(name)
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps page landmarks and hidden controls distinct from visible article material' do
    program = "const markup = '<footer>literal programme value</footer>';\nprint(markup); "
    html = article_footer_page(<<~HTML, docs: true)
      <article class="md-content__inner md-typeset"><h1>Complete publication reports</h1>
      <p>The complete published explanation remains with its literal programme.</p>
      <pre><code>#{CGI.escapeHTML(program)}</code></pre>
      <footer hidden>Unpublished attribution</footer>
      <details><summary>Additional reports</summary><footer>Closed attribution</footer></details>
      <footer role="contentinfo">Explicit page landmark</footer></article>
    HTML
    with_url_page('https://publication.example.test/handbook/reports/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(Nokogiri::HTML5(payload.fetch('html')).at_css('pre').text).to eq(program)
      expect(payload.fetch('markdown')).to include(program)
      expect(payload.fetch('markdown')).not_to include('Global publication furniture', 'Explicit page landmark', 'Unpublished attribution', 'Closed attribution')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains physical testimonial attributions through software homepage release-note cleanup' do
    html = article_footer_page(<<~HTML)
      <h1>Complete publication reports</h1>
      <p>The open-source framework publishes every independent observation with complete software documentation and attribution.</p>
      <p><a href="/docs/">Documentation</a> and <a href="/start/">Get started</a> describe the complete public framework.
      <a href="https://code.publication.example.test/source/">Source code</a> remains independently available.</p>
      <section><h2>Independent reports</h2>
      <article><h3>First report</h3><blockquote><p>The first complete observation explains every recorded result.</p></blockquote>
      <footer>Morgan Vale, Research Director</footer></article>
      <article><h3>Second report</h3><blockquote><p>The second complete observation explains its independent result.</p></blockquote>
      <footer>Avery Reed, Platform Engineer</footer></article>
      <article><h3>Third report</h3><blockquote><p>The third complete observation explains every recorded resource.</p></blockquote>
      <footer>Jordan Moss, Publication Maintainer</footer></article></section>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      names = ['Morgan Vale, Research Director', 'Avery Reed, Platform Engineer', 'Jordan Moss, Publication Maintainer']
      names.each do |name|
        expect(Nokogiri::HTML5(payload.fetch('html')).text).to include(name)
        expect(payload.fetch('markdown')).to include(name)
      end
      expect(payload.fetch('markdown')).to include('[Documentation](https://publication.example.test/docs/)',
                                                   '[Get started](https://publication.example.test/start/)',
                                                   '[Source code](https://code.publication.example.test/source/)')
      expect(payload.fetch('markdown')).not_to include('Global publication furniture')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
