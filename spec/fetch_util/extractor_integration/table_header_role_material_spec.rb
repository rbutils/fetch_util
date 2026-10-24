# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil physical table header and cell roles' do
  include_context 'extractor integration helpers'

  def header_role_shape(node)
    return nil if node.comment?
    if node.text?
      return nil if %w[table thead tbody tfoot tr].include?(node.parent.name) && node.text.strip.empty?
      return ['text', node.text]
    end
    attributes = node.attribute_nodes.filter_map do |attribute|
      next if %w[class style].include?(attribute.name)
      [attribute.name, attribute.value]
    end.sort
    [node.name, attributes, node.children.filter_map { |child| header_role_shape(child) }]
  end

  def with_header_role_table(table)
    html = <<~HTML
      <!doctype html><html><head><title>Independent measurement records</title></head><body>
      <main><article><h1>Independent measurement records</h1>
      <p>The publication explains the complete measurements in their physical rows and columns.
      Each header identifies its own data, and every independent cell, reference and empty value
      belongs to the comparison rather than an interchangeable layout decoration.</p>
      #{table}
      <p>The complete closing explanation remains visible. Consult the
      <a href="https://reference.example.test/measurement-guide">independent measurement guide</a>
      before interpreting these recorded values.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/guides/header-roles', html) do |page|
      body_html = page.evaluate('document.body.innerHTML')
      body_text = page.evaluate('document.body.innerText')
      payload = extract_payload(page)
      expect(payload.fetch('title')).to eq('Independent measurement records')
      expect(payload.fetch('markdown')).to include('complete closing explanation', 'independent measurement guide')
      expect(payload.fetch('markdown')).to include('https://reference.example.test/measurement-guide')
      expect(page.evaluate('document.body.innerHTML')).to eq(body_html)
      expect(page.evaluate('document.body.innerText')).to eq(body_text)
      yield payload
      expect(page.evaluate('document.body.innerHTML')).to eq(body_html)
      expect(page.evaluate('document.body.innerText')).to eq(body_text)
    end
  end

  def complete_header_role_tables(payload)
    native = Nokogiri::HTML5.parse(payload.fetch('html')).css('table')
    rendered = Nokogiri::HTML5.parse(payload.fetch('markdown')).css('table')
    expect(native).not_to be_empty
    expect(rendered.length).to eq(native.length), 'each physical table must retain its complete cell roles'
    expect(rendered.map { |table| header_role_shape(table) }).to eq(native.map { |table| header_role_shape(table) })
    rendered
  end

  it 'keeps every body-row header, scoped association and independent complete reference' do
    destination = 'https://reference.example.test/measurements?range[from]=0&range[to]=35#observations'
    table = <<~HTML
      <table><thead><tr><th scope="col">Measure</th><th scope="col">Recorded value</th></tr></thead><tbody>
      <tr><th scope="row">First independent measure</th><td><a href="#{CGI.escapeHTML(destination)}">Complete observation</a></td></tr>
      <tr><th scope="row">Second independent measure</th><td><em>Independent value</em></td></tr>
      </tbody></table>
    HTML
    with_header_role_table(table) do |payload|
      rendered = complete_header_role_tables(payload).first
      expect(rendered.css('tbody tr > th').map(&:text)).to eq(['First independent measure', 'Second independent measure'])
      expect(rendered.css('tbody th').map { |cell| cell['scope'] }).to eq(%w[row row])
      expect(rendered.css('a').map { |link| [link.text, link['href']] }).to eq([['Complete observation', destination]])
      expect(rendered.css('em').map(&:text)).to eq(['Independent value'])
    end
  end

  it 'does not promote data cells beside a first-row header into additional headers' do
    table = '<table><tbody><tr><th>Independent key</th><td>First data value</td></tr><tr><th>Second key</th><td>Second data value</td></tr></tbody></table>'
    with_header_role_table(table) do |payload|
      rendered = complete_header_role_tables(payload).first
      expect(rendered.css('tr').map { |row| row.element_children.map(&:name) }).to eq([%w[th td], %w[th td]])
    end
  end

  it 'retains multiple physical header rows without turning a later header into ordinary data' do
    table = <<~HTML
      <table><thead><tr><th>First header</th><th>Second header</th></tr>
      <tr><th>First detailed header</th><th>Second detailed header</th></tr></thead>
      <tbody><tr><td>Independent first value</td><td>Independent second value</td></tr></tbody></table>
    HTML
    with_header_role_table(table) do |payload|
      rendered = complete_header_role_tables(payload).first
      expect(rendered.css('thead th').map(&:text)).to eq(['First header', 'Second header', 'First detailed header', 'Second detailed header'])
    end
  end

  it 'preserves explicit data-cell roles inside a physical table-head section' do
    table = '<table><thead><tr><td>First data label</td><td>Second data label</td></tr></thead><tbody><tr><td>First value</td><td>Second value</td></tr></tbody></table>'
    with_header_role_table(table) do |payload|
      rendered = complete_header_role_tables(payload).first
      expect(rendered.css('th')).to be_empty
      expect(rendered.css('td').map(&:text)).to eq(['First data label', 'Second data label', 'First value', 'Second value'])
    end
  end

  it 'keeps a missing physical cell distinct from a meaningful empty physical cell' do
    table = '<table><thead><tr><th>Key</th><th>Value</th></tr></thead>' \
            '<tbody><tr><td>Single physical cell</td></tr><tr><td>Meaningful empty value</td><td></td></tr></tbody></table>'
    with_header_role_table(table) do |payload|
      rendered = complete_header_role_tables(payload).first
      expect(rendered.css('tbody tr').map { |row| row.css('td').length }).to eq([1, 2])
      expect(rendered.css('tbody tr').last.css('td').last.text).to eq('')
    end
  end

  it 'keeps an ordinary single column-header row on the existing readable pipe-table path' do
    table = '<table><thead><tr><th>Measure</th><th>Value</th></tr></thead>' \
            '<tbody><tr><td>Alpha</td><td>Complete value</td></tr><tr><td>Beta</td><td>Another value</td></tr></tbody></table>'
    with_header_role_table(table) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('| Measure | Value |', '| Alpha | Complete value |', '| Beta | Another value |')
      expect(Nokogiri::HTML5.parse(markdown).css('table')).to be_empty
    end
  end

  it 'keeps headerless data and its real empty cells on the existing generated-empty-header path' do
    table = '<table><tbody><tr><td>First independent value</td><td></td></tr><tr><td>Second independent value</td><td>Complete data</td></tr></tbody></table>'
    with_header_role_table(table) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('|  |  |', '| First independent value |  |', '| Second independent value | Complete data |')
      expect(Nokogiri::HTML5.parse(markdown).css('table')).to be_empty
    end
  end

  it 'retains visible row headers while hidden and closed table content stay absent from Markdown' do
    table = <<~HTML
      <table><tbody><tr><th scope="row">Visible measure</th><td>Visible data</td></tr></tbody></table>
      <div style="display:none"><table><tbody><tr><th>Hidden measure</th><td>Hidden data</td></tr></tbody></table></div>
      <details><summary>Optional closed measurements</summary><table><tbody><tr><th>Closed measure</th><td>Closed data</td></tr></tbody></table></details>
    HTML
    with_header_role_table(table) do |payload|
      markdown = payload.fetch('markdown')
      rendered = Nokogiri::HTML5.parse(markdown).css('table')
      expect(rendered.length).to eq(1)
      expect(rendered.first.css('th').map(&:text)).to eq(['Visible measure'])
      expect(markdown).to include('Visible data', 'Optional closed measurements')
      expect(markdown).not_to include('Hidden measure', 'Hidden data', 'Closed measure', 'Closed data')
      closed = Nokogiri::HTML5.parse(payload.fetch('html')).at_css('details:not([open])')
      expect(closed).not_to be_nil
      expect(closed.css('th').map(&:text)).to eq(['Closed measure'])
    end
  end

  it 'leaves complete table-shaped program text literal and independent from physical data tables' do
    program = "<table>\n<tr><th scope=\"row\">Literal header</th><td>Literal value</td></tr>\n</table>"
    with_header_role_table("<pre><code>#{CGI.escapeHTML(program)}</code></pre>") do |payload|
      native = Nokogiri::HTML5.parse(payload.fetch('html'))
      expect(native.css('table')).to be_empty
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include('```', program)
    end
  end

  it 'retains independent inner and outer table headers without borrowing descendant row roles' do
    table = <<~HTML
      <table><thead><tr><th>Outer key</th><th>Outer detail</th></tr></thead><tbody><tr><td>Independent outer value</td><td>
      <table><thead><tr><th>Inner key</th><th>Inner detail</th></tr></thead><tbody>
      <tr><th scope="row">Independent inner measure</th><td>Complete inner value</td></tr></tbody></table>
      </td></tr></tbody></table>
    HTML
    with_header_role_table(table) do |payload|
      rendered = complete_header_role_tables(payload)
      expect(rendered.length).to eq(2)
      expect(rendered.last.css('tbody th').map(&:text)).to eq(['Independent inner measure'])
    end
  end
end
