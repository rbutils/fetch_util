require 'spec_helper'

require 'cgi'
require 'nokogiri'

RSpec.describe 'FetchUtil complete block material inside table cells' do
  include_context 'extractor integration helpers'

  def complex_table_shape(node, literal: false)
    return nil if node.comment?
    if node.text?
      return nil if !literal && %w[table thead tbody tfoot tr].include?(node.parent.name) && node.text.strip.empty?
      return ['text', node.text]
    end
    literal ||= %w[pre code].include?(node.name)
    attributes = node.attribute_nodes.filter_map do |attribute|
      next if %w[class style].include?(attribute.name)
      [attribute.name, attribute.value]
    end.sort
    [node.name, attributes, node.children.filter_map { |child| complex_table_shape(child, literal: literal) }]
  end

  def with_complex_table(table)
    html = <<~HTML
      <!doctype html><html><head><title>Publication comparison guide</title></head><body>
      <main><article><h1>Publication comparison guide</h1>
      <p>The complete comparison explains every independent option and its physical data cells.
      Paragraph boundaries, nested choices, literal examples and references belong to the same
      publication and must remain in their original order.</p>
      #{table}
      <p>The complete closing explanation remains visible. Consult the
      <a href="https://reference.example.test/comparison">independent comparison reference</a>
      before selecting an option, and retain every materialized row.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/guides/comparison', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(payload.fetch('markdown')).to include('independent comparison reference', 'https://reference.example.test/comparison')
      yield payload
    end
  end

  def expect_complete_table_material(payload)
    native = Nokogiri::HTML5.parse(payload.fetch('html')).css('table')
    rendered = Nokogiri::HTML5.parse(payload.fetch('markdown')).css('table')
    expect(native).not_to be_empty
    expect(rendered.length).to eq(native.length), 'complex table material must remain a complete parseable HTML block'
    expect(rendered.map { |table| complex_table_shape(table) }).to eq(native.map { |table| complex_table_shape(table) })
    rendered.first
  end

  it 'retains nested unordered and ordered choices with their complete paragraph and reference roles' do
    table = <<~HTML
      <table><thead><tr><th>Option</th><th>Complete choices</th></tr></thead><tbody>
      <tr><td>First option</td><td><ul><li><p>Batteries included</p></li>
      <li><p>Decent speed</p><ol start="3"><li><a href="https://reference.example.test/third">Third choice</a></li>
      <li><em>Fourth choice</em></li></ol></li></ul></td></tr>
      </tbody></table>
    HTML
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.css('td ul > li').length).to eq(2)
      expect(rendered.at_css('ol')['start']).to eq('3')
    end
  end

  it 'preserves independent equal paragraphs and a quoted explanation inside their own cell' do
    table = <<~HTML
      <table><tbody><tr><td>Independent record</td><td>
      <p>The independently authored explanation remains complete.</p>
      <p>The independently authored explanation remains complete.</p>
      <blockquote><p>A <strong>separate quoted explanation</strong> keeps its own role.</p></blockquote>
      </td></tr></tbody></table>
    HTML
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.css('td > p').map(&:text)).to eq(Array.new(2, 'The independently authored explanation remains complete.'))
      expect(rendered.css('blockquote p strong').map(&:text)).to eq(['separate quoted explanation'])
    end
  end

  it 'keeps every merged-cell extent and meaningful empty data cell' do
    table = <<~HTML
      <table><tbody><tr><td rowspan="2">Independent pair</td><td colspan="2">Shared scope</td></tr>
      <tr><td></td><td>Final distinct value</td></tr></tbody></table>
    HTML
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expected_extents = [['td', '2', nil], ['td', nil, '2']]
      expect(rendered.css('[rowspan],[colspan]').map { |node| [node.name, node['rowspan'], node['colspan']] }).to eq(expected_extents)
      expect(rendered.css('tr')[1].css('td')[0].text).to eq('')
    end
  end

  it 'retains the independent outer and inner table boundaries, captions and heading roles' do
    table = <<~HTML
      <table><caption>Outer comparison</caption><thead><tr><th>Record</th><th>Detailed comparison</th></tr></thead>
      <tbody><tr><td>Outer record</td><td><h3>Independent detail</h3><table><caption>Inner comparison</caption>
      <tbody><tr><td>Inner key</td><td>Inner value</td></tr></tbody></table></td></tr></tbody></table>
    HTML
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.css('caption').map(&:text)).to eq(['Outer comparison', 'Inner comparison'])
      expect(rendered.css('h3').map(&:text)).to eq(['Independent detail'])
    end
  end

  it 'preserves complete literal program bytes and named HTTP bindings inside a data cell' do
    program = "first_code()\n\nlast_code('literal | ``` value')"
    table = [
      '<table><tbody><tr><td>Literal procedure</td><td><pre><code id="literal-program">',
      '<a id="first-line" name="first-line" href="https://reference.example.test/code-line">first_code()</a>',
      "\n\n#{CGI.escapeHTML("last_code('literal | ``` value')")}</code></pre></td></tr></tbody></table>"
    ].join
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.at_css('pre').text).to eq(program)
      expect(rendered.css('[id="literal-program"]').length).to eq(1)
      expect(rendered.at_css('code').children.first['id']).to eq('literal-program')
      expect(rendered.at_css('code a').attributes.transform_values(&:value)).to include(
        'id' => 'first-line', 'name' => 'first-line', 'href' => 'https://reference.example.test/code-line'
      )
    end
  end

  it 'retains the visible list while source-hidden and closed-panel contents remain absent' do
    table = <<~HTML
      <table><tbody><tr><td>Visibility record</td><td><ul><li>Visible first choice</li><li>Visible second choice</li></ul>
      <div style="display:none"><ul><li>Hidden independent choice</li></ul></div>
      <details><summary>Available explanation</summary><ul><li>Closed independent choice</li></ul></details>
      </td></tr></tbody></table>
    HTML
    with_complex_table(table) do |payload|
      markdown = payload.fetch('markdown')
      rendered = Nokogiri::HTML5.parse(markdown).at_css('table')
      expect(rendered).not_to be_nil
      expect(rendered.css('ul li').map(&:text)).to eq(['Visible first choice', 'Visible second choice'])
      expect(markdown).to include('Available explanation')
      expect(markdown).not_to include('Hidden independent choice', 'Closed independent choice')
    end
  end

  it 'keeps ordinary inline data in its existing readable Markdown table' do
    table = '<table><thead><tr><th>Key</th><th>Value</th></tr></thead><tbody><tr><td>Alpha</td><td>Complete value</td></tr></tbody></table>'
    with_complex_table(table) do |payload|
      expect(payload.fetch('markdown')).to include('| Key | Value |', '| Alpha | Complete value |')
    end
  end

  it 'retains the source-bound canonical program without further whitespace normalization' do
    program = "\n    first_code()\n\n    last_code()  \n\n"
    table = "<table><tbody><tr><td>Complete program</td><td><pre><code>#{CGI.escapeHTML(program)}</code></pre></td></tr></tbody></table>"
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.at_css('pre code').text).to eq("    first_code()\n\n    last_code()  ")
    end
  end

  it 'keeps authored marker-shaped text and attributes independent from private table snapshots' do
    table = <<~HTML
      <p>FETCHUTILTABLEBLOCK0END is independently authored publication text.</p>
      <table data-fetch-util-table-block="0"><tbody><tr><td>Independent record</td><td>
      <ul><li>First distinct choice</li><li>Second distinct choice</li></ul></td></tr></tbody></table>
    HTML
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered['data-fetch-util-table-block']).to eq('0')
      expect(payload.fetch('markdown').scan('FETCHUTILTABLEBLOCK0END').length).to eq(1)
      expect(rendered.css('ul li').map(&:text)).to eq(['First distinct choice', 'Second distinct choice'])
    end
  end

  it 'keeps commented-out cells, resources and programs inert in a complete table' do
    table = <<~HTML
      <table><tbody><tr><td>Visible record</td><td><ul>
      <li>Visible first choice</li><li>Visible second choice</li></ul></td>
      <!-- <td><a href="https://private.example.test/inert-record">Commented independent destination</a>
      <pre><code>inert_program()</code></pre></td> -->
      </tr></tbody></table>
    HTML
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.css('td').length).to eq(2)
      expect(payload.fetch('markdown')).not_to include('Commented independent destination', 'private.example.test', 'inert_program()')
      expect(rendered.css('ul li').map(&:text)).to eq(['Visible first choice', 'Visible second choice'])
    end
  end

  it 'retains complete comment-shaped text as literal program data inside a table' do
    program = "<!-- literal program comment -->\nkept_code()"
    table = "<table><tbody><tr><td>Visible procedure</td><td><pre><code>#{CGI.escapeHTML(program)}</code></pre></td></tr></tbody></table>"
    with_complex_table(table) do |payload|
      rendered = expect_complete_table_material(payload)
      expect(rendered.at_css('pre code').text).to eq(program)
    end
  end
end
