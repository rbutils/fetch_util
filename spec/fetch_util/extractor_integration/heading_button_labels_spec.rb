require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Physical heading button labels' do
  include_context 'extractor integration helpers'

  def heading_button_page(body)
    <<~HTML
      <html><head><title>Complete publication handbook</title><meta name="generator" content="MkDocs 1.6"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Complete publication handbook</h1>#{body}</article></main></body></html>
    HTML
  end

  it 'retains complete heading roles when physical buttons become inert readable labels' do
    html = heading_button_page(<<~HTML)
      <p>The complete publication introduction remains before every independent heading.</p>
      <h2><button type="button">How are complete publication records deployed?</button></h2>
      <p>Every publication record retains its complete explanation and destination.</p>
      <h3>Before <button type="button">Which complete deployment files are available?</button> after</h3>
      <p>The complete deployment explanation remains after the lower heading.</p>
    HTML
    with_url_page('https://publication.example.test/handbook/controls/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      expected_headings = [
        'How are complete publication records deployed?',
        'Before Which complete deployment files are available? after'
      ]
      expect(native.css('h2,h3').map { |node| node.text.gsub(/[[:space:]]+/, ' ').strip }).to eq(expected_headings)
      expect(native.css('h2 p,h3 p,h2 button,h3 button')).to be_empty
      expect(payload.fetch('markdown')).to include('## How are complete publication records deployed?')
      expect(payload.fetch('markdown')).to include('### Before Which complete deployment files are available? after')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves heading-owned sibling resources and meaningful non-button control labels' do
    html = heading_button_page(<<~HTML)
      <h4><span role="button">Which complete installation options are documented?</span>
      <a href="../reference/">Independent reference</a></h4>
      <p>The complete independent reference stays associated with its physical heading.</p>
      <h5><input type="button" value="Read the complete publication configuration"></h5>
      <p>Every configuration option remains after the lower-level physical heading.</p>
    HTML
    with_url_page('https://publication.example.test/handbook/controls/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      markdown = payload.fetch('markdown')
      expect(markdown).to include('#### Which complete installation options are documented? [Independent reference](https://publication.example.test/handbook/reference/)')
      expect(markdown).to include('##### Read the complete publication configuration')
      expect(markdown.scan('https://publication.example.test/handbook/reference/').length).to eq(1)
      expect(Nokogiri::HTML5(payload.fetch('html')).css('h4 p,h5 p')).to be_empty
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps unrelated labels as paragraphs while retaining source visibility, programs and BODY' do
    program = "const markup = \"<h3><button>Literal publication heading</button></h3>\";\nprint(markup);"
    label = 'Read the complete publication handbook and configuration reference'
    html = heading_button_page(<<~HTML)
      <h2>Visible publication controls</h2><p>The complete visible prose remains.</p>
      <button type="button">#{label}</button>
      <h3 hidden><button type="button">Unpublished heading control</button></h3>
      <details><summary>Additional publication controls</summary>
      <h4><button type="button">Closed heading control</button></h4>
      <pre><code>closed_program();</code></pre></details>
      <pre><code data-language="js">#{CGI.escapeHTML(program)}</code></pre>
    HTML
    with_url_page('https://publication.example.test/handbook/controls/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      expect(native.css('p[data-fetchutil-button-text="true"]').map(&:text)).to include(label)
      expect(payload.fetch('markdown')).to include('## Visible publication controls', label, program)
      expect(payload.fetch('markdown')).not_to include('Unpublished heading control', 'Closed heading control', 'closed_program();')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
