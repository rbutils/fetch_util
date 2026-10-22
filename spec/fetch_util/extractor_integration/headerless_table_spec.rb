require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Physical headerless table data roles' do
  include_context 'extractor integration helpers'

  def headerless_records
    <<~HTML
      <tr><td><a href="/records/alpha">Alpha record</a></td><td><em>review pending</em></td><td><code>alpha_key</code></td></tr>
      <tr><td><a href="/records/beta">Beta record</a></td><td><strong>approved</strong></td><td><code>beta_key</code></td></tr>
      <tr><td><a href="/records/alpha">Independent alpha record</a></td><td>retained</td><td><code>alpha_copy</code></td></tr>
    HTML
  end

  def expected_headerless_markdown_rows
    [
      ['[Alpha record](https://records.publication.example.test/records/alpha)', '_review pending_', '`alpha_key`'],
      ['[Beta record](https://records.publication.example.test/records/beta)', '**approved**', '`beta_key`'],
      ['[Independent alpha record](https://records.publication.example.test/records/alpha)', 'retained', '`alpha_copy`']
    ]
  end

  def markdown_table_rows(markdown)
    markdown.lines.select { |line| line.lstrip.start_with?('|') }
                  .map { |line| line.strip.split('|', -1)[1...-1].map(&:strip) }
  end

  def headerless_table_probe(table)
    root = File.expand_path('../../..', __dir__)
    scripts = File.readlines(File.join(root, 'websieve/manifest.txt')).map(&:strip)
                  .reject { |path| path.empty? || path.start_with?('#') }
                  .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    boundary = '})(window);'
    raise 'table probe boundary changed' unless scripts.scan(boundary).length == 1
    scripts = scripts.sub(boundary, 'global.__headerlessTable = tableToMarkdown; })(window);')
    with_url_page('https://records.publication.example.test/catalog/', "<html><body>#{table}</body></html>") do |page|
      page.add_script_tag(content: scripts)
      page.evaluate(<<~JS)
        (() => {
          const before = document.body.innerHTML;
          const table = document.querySelector('table');
          const markdown = __headerlessTable(table, '');
          return { markdown, unchanged: document.body.innerHTML === before,
            cells: Array.from(table.querySelectorAll('tr')).map(row =>
              Array.from(row.children).map(cell => [cell.tagName, cell.textContent])) };
        })()
      JS
    end
  end

  it 'keeps every ordinary unheaded row as data with complete independent references and inline roles' do
    result = headerless_table_probe("<table><tbody>#{headerless_records}</tbody></table>")
    expect(result.fetch('cells').flatten(1).map(&:first)).to eq(['TD'] * 9)
    rows = markdown_table_rows(result.fetch('markdown'))
    expect(rows.first).to eq(['', '', ''])
    expect(rows[1]).to eq(['---', '---', '---'])
    expect(rows.drop(2)).to eq(expected_headerless_markdown_rows)
    expect(result.fetch('unchanged')).to be(true)
  end

  it 'retains data roles after a source-hidden document header is removed' do
    program = "const marker = '<th>literal header</th>';\nconsole.log(marker);"
    html = <<~HTML
      <html><head><title>Published package directory</title><meta name="generator" content="MkDocs"></head>
      <body><main class="md-main"><article class="md-content__inner md-typeset">
      <h1>Published package directory</h1><p>Every published record retains its complete destination, review state and identifier.</p>
      <h2>Records</h2><table><tbody><tr style="display:none"><th>Hidden name</th><th>Hidden state</th><th>Hidden key</th></tr>
      #{headerless_records}</tbody></table><h2>Literal example</h2><pre><code data-language="javascript">#{CGI.escapeHTML(program)}</code></pre>
      <p>The independent records and literal example remain in their published order.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://records.publication.example.test/catalog/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(native.css('table th')).to be_empty
      expect(native.css('table td').map(&:text)).to eq(
        [
          'Alpha record', 'review pending', 'alpha_key', 'Beta record', 'approved', 'beta_key',
          'Independent alpha record', 'retained', 'alpha_copy'
        ]
      )
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(native.css('a[href]').map { |node| [node.text, node['href']] }).to eq(
        [
          ['Alpha record', 'https://records.publication.example.test/records/alpha'],
          ['Beta record', 'https://records.publication.example.test/records/beta'],
          ['Independent alpha record', 'https://records.publication.example.test/records/alpha']
        ]
      )
      rows = markdown_table_rows(payload.fetch('markdown'))
      expect(rows.first).to eq(['', '', ''])
      expect(rows.drop(2)).to eq(expected_headerless_markdown_rows)
      expect(payload.fetch('markdown')).to include(
        program,
        'Every published record retains its complete destination, review state and identifier.',
        'The independent records and literal example remain in their published order.'
      )
      expect(payload.fetch('markdown')).not_to include('Hidden name', 'Hidden state', 'Hidden key')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the original explicitly declared header above every data row' do
    table = "<table><thead><tr><th>Record</th><th>State</th><th>Key</th></tr></thead><tbody>#{headerless_records}</tbody></table>"
    result = headerless_table_probe(table)
    rows = markdown_table_rows(result.fetch('markdown'))
    expect(rows.first).to eq(%w[Record State Key])
    expect(rows[1]).to eq(['---', '---', '---'])
    expect(rows.drop(2)).to eq(expected_headerless_markdown_rows)
    expect(result.fetch('cells').first.map(&:first)).to eq(['TH'] * 3)
    expect(result.fetch('unchanged')).to be(true)
  end
end
