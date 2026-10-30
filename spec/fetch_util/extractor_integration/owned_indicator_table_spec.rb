# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Source-owned indicator feature matrices' do
  include_context 'extractor integration helpers'

  def feature_labels
    [
      'Protocol revision A', 'Protocol revision B', 'Protocol revision C', 'Session testament',
      'Encrypted transport', 'Message persistence', 'Automatic reconnect', 'Offline buffering',
      'WebSocket transport', 'Plain TCP transport', 'Asynchronous calls', 'Blocking calls', 'Broker failover'
    ]
  end

  def indicator_program
    "status = '<i class=\"literal-indicator\"></i>'\n\nputs(status)"
  end

  def indicator_matrix(labels, header: false)
    heading = header ? '<tr><th>Feature</th><th>Declared indicator</th></tr>' : ''
    rows = labels.each_with_index.map do |label, index|
      glyph = index.even? ? 'indicator-present' : 'indicator-absent'
      <<~HTML
        <tr><td><a href="#" data-toggle="tooltip" data-original-title="Complete note for #{label}">#{label}</a></td>
        <td class="indicator-cell"><i aria-hidden="true" class="feature-glyph #{glyph}"></i></td></tr>
      HTML
    end.join
    "<table class=\"feature-matrix\"><tbody>#{heading}#{rows}</tbody></table>"
  end

  def indicator_document(header: false, boundary: nil)
    matrices = '<div class="matrix-row">' \
               "<div class=\"matrix-column\">#{indicator_matrix(feature_labels.first(7), header: header)}</div>" \
               "<div class=\"matrix-column\">#{indicator_matrix(feature_labels.drop(7), header: header)}</div></div>"
    matrices = "<nav aria-label=\"Account actions\"><form>#{matrices}</form></nav>" if boundary == :interface
    matrices = "<div style=\"display:none\">#{matrices}</div>" if boundary == :hidden
    <<~HTML
      <html><head><title>Messaging Client | Example Development Foundation</title></head>
      <body><main><section class="panel-body"><h1>Transport guide</h1>
      <p>This independent client connects applications to message brokers through several transports.
      The complete reference explains the declared feature matrix and the installation program.</p>
      <h2>Feature declarations</h2>#{matrices}
      <h2>Installation</h2><p>Install the client after configuring the local language environment.</p>
      <pre><code>#{CGI.escapeHTML(indicator_program)}</code></pre>
      <h2>Getting started</h2><p>The client opens the selected transport and reports connection failures.
      Applications can subscribe to topics, publish messages and close their sessions explicitly.</p>
      <p>This concluding paragraph belongs to the same guide and follows the complete installation program.</p>
      </section></main></body></html>
    HTML
  end

  def indicator_attributes(root)
    root.css('table i').map { |node| node.attribute_nodes.to_h { |attribute| [attribute.name, attribute.value] } }
  end

  def assert_complete_indicator_matrices(header:)
    html = indicator_document(header: header)
    original = Nokogiri::HTML5(html)
    with_url_page('https://reference.example.test/client/guide/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(native.css('pre').map(&:text)).to eq([indicator_program])
      expect(native.css('h1,h2').map { |node| [node.name, node.text] }).to eq(
        [['h1', 'Transport guide'], ['h2', 'Feature declarations'], ['h2', 'Installation'], ['h2', 'Getting started']]
      )
      expect(native.css('table tr td:first-child').map(&:text)).to eq(feature_labels)
      expect(native.css('table').map { |table| table.css('tr').length }).to eq(header ? [8, 7] : [7, 6])
      expect(indicator_attributes(native)).to eq(indicator_attributes(original))
      expect(native.css('table a').map { |node| [node.text, node['href'], node['data-original-title']] }).to eq(
        feature_labels.map { |label| [label, 'https://reference.example.test/client/guide/#', "Complete note for #{label}"] }
      )
      rendered = Nokogiri::HTML5.fragment(payload.fetch('markdown'))
      expect(rendered.css('table tr td:first-child').map(&:text)).to eq(feature_labels)
      expect(indicator_attributes(rendered)).to eq(indicator_attributes(original))
      expect(rendered.css('table a').map { |node| [node.text, node['href'], node['data-original-title']] }).to eq(
        native.css('table a').map { |node| [node.text, node['href'], node['data-original-title']] }
      )
      expect(payload.fetch('markdown')).to include(indicator_program, 'This concluding paragraph belongs to the same guide')
    end
  end

  it 'retains all physical unheaded feature rows, opaque indicator declarations and independent references' do
    assert_complete_indicator_matrices(header: false)
  end

  it 'preserves the same complete indicator values when the author supplies column headers' do
    assert_complete_indicator_matrices(header: true)
  end

  it 'keeps genuine navigation/form matrices outside the guide without changing the literal program' do
    with_url_page('https://reference.example.test/client/guide/', indicator_document(boundary: :interface)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(native.css('table, form')).to be_empty
      expect(native.css('nav').all? { |node| node.text.strip.empty? && node.css('i, a, input').empty? }).to be(true)
      expect(native.css('pre').map(&:text)).to eq([indicator_program])
      feature_labels.each { |label| expect(payload.fetch('markdown')).not_to include(label) }
      expect(payload.fetch('markdown')).to include(indicator_program)
    end
  end

  it 'excludes positively hidden matrices while retaining the complete visible guide program' do
    with_url_page('https://reference.example.test/client/guide/', indicator_document(boundary: :hidden)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(native.css('table')).to be_empty
      expect(native.css('pre').map(&:text)).to eq([indicator_program])
      feature_labels.each { |label| expect(payload.fetch('markdown')).not_to include(label) }
      expect(payload.fetch('markdown')).to include(indicator_program)
    end
  end

  it 'retains two physically independent identical rows and their complete indicator declarations' do
    original = Nokogiri::HTML5(indicator_document)
    row = original.at_css('table tr')
    row.add_next_sibling(row.dup)
    expected_labels = original.css('table tr td:first-child').map(&:text)
    with_url_page('https://reference.example.test/client/guide/', original.to_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        retained = Nokogiri::HTML5.fragment(value)
        expect(retained.css('table tr td:first-child').map(&:text)).to eq(expected_labels)
        expect(indicator_attributes(retained)).to eq(indicator_attributes(original))
        expect(retained.css('table a').map { |link| link['data-original-title'] }).to eq(
          original.css('table a').map { |link| link['data-original-title'] }
        )
      end
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(payload.fetch('markdown')).to include(indicator_program)
    end
  end

  it 'preserves authored marker collisions and literal table programs without promoting program markup' do
    literal = "record = '<table><tr><td>literal only</td><td><i class=\"literal-glyph\"></i></td></tr></table>'\n\nputs(record)"
    original = Nokogiri::HTML5(indicator_document)
    original.at_css('pre code').content = literal
    original.css('table').each { |table| table['data-fetchutil-reader-indicator-table'] = '0' }
    with_url_page('https://reference.example.test/client/guide/', original.to_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      # The HTML parser must not interpret the complete fenced program as DOM.
      expect(payload.fetch('markdown').scan(literal).length).to eq(1)
      protected_markdown = payload.fetch('markdown').sub(literal, CGI.escapeHTML(literal))
      [payload.fetch('html'), protected_markdown].each do |value|
        retained = Nokogiri::HTML5.fragment(value)
        expect(retained.css('table').length).to eq(2)
        expect(retained.css('table').map { |table| table['data-fetchutil-reader-indicator-table'] }).to eq(%w[0 0])
        expect(retained.css('table tr td:first-child').map(&:text)).to eq(feature_labels)
        expect(indicator_attributes(retained)).to eq(indicator_attributes(original))
      end
      expect(Nokogiri::HTML5.fragment(payload.fetch('html')).css('pre code').map(&:text)).to eq([literal])
      expect(payload.fetch('markdown')).to include(literal)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains the complete matrix group beside an empty column and already-pruned scripts' do
    original = Nokogiri::HTML5(indicator_document)
    original.at_css('.matrix-row').add_child(
      '<div class="matrix-column"></div>' \
      '<script src="https://assets.example.test/tooltips.js"></script>' \
      '<script>void 0;</script>'
    )
    with_url_page('https://reference.example.test/client/guide/', original.to_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(Nokogiri::HTML5.fragment(payload.fetch('html')).css('pre code').map(&:text)).to eq([indicator_program])
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        retained = Nokogiri::HTML5.fragment(value)
        expect(retained.css('table tr td:first-child').map(&:text)).to eq(feature_labels)
        expect(indicator_attributes(retained)).to eq(indicator_attributes(original))
        expect(retained.css('table a').map { |link| link['data-original-title'] }).to eq(
          original.css('table a').map { |link| link['data-original-title'] }
        )
        expect(retained.css('script')).to be_empty
      end
      expect(payload.fetch('markdown')).to include(indicator_program)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
