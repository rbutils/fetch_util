require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Complete physical data-table selection' do
  include_context 'extractor integration helpers'

  def research_rows(count)
    (1..count).map do |index|
      "<tr><td>Independent research occupation number #{index}</td><td>Region #{index}</td>" \
        "<td>#{index * 125}</td><td>Complete measured observation #{index}, retained without any omitted values.</td></tr>"
    end.join
  end

  def research_table(count, attributes: '')
    "<table #{attributes}><thead><tr><th>Occupation</th><th>Region</th><th>Median</th><th>Observation</th></tr></thead>" \
      "<tbody>#{research_rows(count)}</tbody></table>"
  end

  def publication_html(hidden: '')
    <<~HTML
      <html><head><title>Regional research measurements</title>
      <link rel='canonical' href='https://data.publication.example.test/report'>
      <meta name='description' content='Complete regional measurements with independent methods, summaries and reusable data.'></head><body>
      <nav><a href='/navigation'>Unrelated navigation</a></nav>
      <div class='publication'><h1>Regional research measurements</h1>
        <p>The complete regional research publication explains every observation, its units and the independent method used to collect these measurements.</p>
        <div><h2>Summary measurements</h2><div>#{research_table(3)}</div></div>
        <div><h2>Collection method</h2><p>Measurements retain every original value. Consult the <a href='/method'>complete methodology</a> before comparing regions.</p>
          <pre><code>  const sample = "&lt;table&gt;literal&lt;/table&gt;";\nkeep_every_record();</code></pre></div>
        <div><h2>Complete measurements</h2><div>#{research_table(120)}</div></div>
        <div><h2>Reuse the measurements</h2><p>Download the <a href='/complete.csv'>complete data</a> and retain this independent attribution with every reuse.</p></div>
        #{hidden}
      </div><aside>Unrelated sidebar publication <a href='/other'>Different report</a></aside>
      </body></html>
    HTML
  end

  def table_values(root)
    root.css('table').map do |table|
      table.css('tr').map { |row| row.css('th, td').map { |cell| [cell.name, cell.text, cell['rowspan'], cell['colspan']] } }
    end
  end

  it 'retains both complete tables and their independently owned publication context' do
    html = publication_html
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = Nokogiri::HTML5(html).at_css('.publication')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))

      expect(table_values(body)).to eq(table_values(source))
      expect(body.css('h1, h2').map { |node| [node.name, node.text] }).to eq(source.css('h1, h2').map { |node| [node.name, node.text] })
      expect(body.css('p').map(&:text)).to eq(source.css('p').map(&:text))
      expect(body.css('pre').map(&:text)).to eq(source.css('pre').map(&:text))
      references = [
        ['complete methodology', 'https://data.publication.example.test/method'],
        ['complete data', 'https://data.publication.example.test/complete.csv']
      ]
      expect(body.css('a').map { |node| [node.text, node['href']] }).to eq(references)
      source.css('th, td').each { |cell| expect(payload.fetch('markdown')).to include(cell.text) }
      expect(payload.fetch('markdown')).to include(source.at_css('pre').text)
      expect(payload.fetch('markdown')).not_to include('Unrelated sidebar publication')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps a complete table when no unique matching publication heading can justify wider ownership' do
    html = "<html><head><title>Independent catalogue</title></head><body>" \
      "<div><h1>Unrelated landing heading</h1><p>Unrelated owner prose remains separate from the independently structured measurements.</p></div>" \
      "<div>#{research_table(120)}</div></body></html>"
    with_url_page('https://data.publication.example.test/catalogue', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(table_values(body)).to eq(table_values(Nokogiri::HTML5(html)))
      expect(body.css('table').length).to eq(1)
      expect(body.css('tr').length).to eq(121)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains a title-qualified data publication with a delimited title suffix and transparent scroll wrappers' do
    html = publication_html.sub('<title>Regional research measurements</title>',
                                '<title>Regional research measurements — Open Dataset | Research Observatory</title>')
    html = html.gsub('<div><table ', "<div class='table-scroll'><table ")
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = Nokogiri::HTML5(html).at_css('.publication')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(table_values(body)).to eq(table_values(source))
      expect(body.css('h1, h2').map { |node| [node.name, node.text] }).to eq(source.css('h1, h2').map { |node| [node.name, node.text] })
      expect(body.css('p').map(&:text)).to eq(source.css('p').map(&:text))
      expect(body.css('pre').map(&:text)).to eq(source.css('pre').map(&:text))
      expect(body.css('a').map(&:text)).to eq(source.css('a').map(&:text))
      source.css('th, td').each { |cell| expect(payload.fetch('markdown')).to include(cell.text) }
      expect(payload.fetch('markdown')).to include(source.at_css('pre').text)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves complete independently described downloads and guide references within the data publication' do
    resources = <<~HTML
      <div><h2>Reusable data</h2><div class='resource-grid'>
        <a href='/export.csv' download>Complete CSV<span>Every record, UTF-8</span></a>
        <a href='/export.json' download>Complete JSON<span>Every record with metadata</span></a>
      </div></div>
      <div><h2>Interpretation guides</h2><div class='resource-grid'>
        <a href='/guide-one'>First guide<span>Complete research methodology</span></a>
        <a href='/guide-two'>Second guide<span>Complete research methodology</span></a>
      </div></div>
    HTML
    html = publication_html.sub('</div><aside>', "#{resources}</div><aside>")
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = Nokogiri::HTML5(html).at_css('.publication')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expected = source.css('a[href]').map { |node| [node.text, "https://data.publication.example.test#{node["href"]}"] }
      expect(body.css('a[href]').map { |node| [node.text, node['href']] }).to eq(expected)
      expect(table_values(body)).to eq(table_values(source))
      expect(body.css('h1,h2').map { |node| [node.name, node.text] }).to eq(source.css('h1,h2').map { |node| [node.name, node.text] })
      expect(body.css('pre').map(&:text)).to eq(source.css('pre').map(&:text))
      expected.each do |label, href|
        expect(payload.fetch('markdown')).to include(label, "(#{href})")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps source-hidden and closed data private while retaining all visible values' do
    hidden = "<div hidden>#{research_table(2, attributes: "id='hidden-records'")}</div>" \
      "<details><summary>Closed supplementary measurements</summary><p>Closed supplementary secret</p>" \
      "<table><tr><th>Private field</th><th>Private value</th></tr><tr><td>Hidden account</td><td>Secret value</td></tr></table></details>"
    html = publication_html(hidden: hidden)
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(body.at_css('#hidden-records')).to be_nil
      expect(payload.fetch('markdown')).not_to include('Closed supplementary secret', 'Private field', 'Hidden account', 'Secret value')
      expect(payload.fetch('markdown')).to include('Independent research occupation number 120')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete short publication fields and selects the owned introduction over a pre-title path' do
    fields = <<~HTML
      <div class='dataset-overview'>
        <div><div class='summary-field'><div>123</div><div>Occupations</div></div></div>
        <div><div class='summary-field'><div class='marker'></div>Survey release 2026</div>
          <div class='summary-field'><div class='marker'></div>CSV and JSON</div>
          <div class='summary-field'><div class='marker'></div>CC BY 4.0</div>
          <div class='summary-field'><div class='marker'></div>Updated 28 July 2026</div></div>
        <div hidden>Private unreleased measurements</div>
      </div>
    HTML
    html = publication_html.sub(/<meta name='description'[^>]*>/, '')
    html = html.sub('<h1>', "<div class='page-path'><a href='/'>Home</a> › Regional measurements</div><h1>")
    html = html.sub('<div><h2>Summary measurements</h2>', "#{fields}<div><h2>Summary measurements</h2>")
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = Nokogiri::HTML5(html).at_css('.publication')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      source.css('.summary-field').each { |node| expect(body.text).to include(node.text) }
      expect(payload.fetch('excerpt')).to eq(source.at_css('p').text)
      expect(table_values(body)).to eq(table_values(source))
      expect(body.css('h1,h2').map { |node| [node.name, node.text] }).to eq(source.css('h1,h2').map { |node| [node.name, node.text] })
      expect(body.css('pre').map(&:text)).to eq(source.css('pre').map(&:text))
      expect(body.css('a').map(&:text)).to eq(source.css('a').map(&:text))
      expect(payload.fetch('markdown')).not_to include('Private unreleased measurements')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains a complete physical table directly owned by the source body' do
    html = "<html><head><title>Independent catalogue</title></head><body>#{research_table(120)}</body></html>"
    with_url_page('https://data.publication.example.test/catalogue', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(table_values(body)).to eq(table_values(Nokogiri::HTML5(html)))
      expect(body.css('tr').length).to eq(121)
      Nokogiri::HTML5(html).css('th,td').each { |cell| expect(payload.fetch('markdown')).to include(cell.text) }
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'uses the owned introduction after a relative static-homepage trail' do
    html = publication_html.sub(/<meta name='description'[^>]*>/, '')
    html = html.sub('<h1>', "<div class='page-path'><a href='index.html'>Home</a> › Regional measurements</div><h1>")
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source = Nokogiri::HTML5(html).at_css('.publication')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload.fetch('excerpt')).to eq(source.at_css('p').text)
      expect(table_values(body)).to eq(table_values(source))
      expect(body.css('h1,h2').map { |node| [node.name, node.text] }).to eq(source.css('h1,h2').map { |node| [node.name, node.text] })
      expect(body.css('pre').map(&:text)).to eq(source.css('pre').map(&:text))
      expect(body.css('a').map(&:text)).to eq(source.css('a').map(&:text))
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains complete emphasized cell values, nested roles, references and literal programs' do
    details = '<strong>calibrated estimate</strong> and <em>verified <strong>joint interval</strong></em> ' \
      'with <code>A*B`C</code> and <a href="/explanation"><em>complete guide</em></a>'
    html = publication_html.sub('<td>Region 1</td>', '<td><em>no state qualifies</em></td>')
    html = html.sub('Complete measured observation 1, retained without any omitted values.', details)
    with_url_page('https://data.publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      source_body = Nokogiri::HTML5(html).at_css('.publication')
      payload = extract_payload(page)
      body = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(table_values(body)).to eq(table_values(source_body))
      expect(body.css('em,strong,code').map { |node| [node.name, node.text] }).to eq(source_body.css('em,strong,code').map { |node| [node.name, node.text] })
      expect(body.css('h1,h2').map { |node| [node.name, node.text] }).to eq(source_body.css('h1,h2').map { |node| [node.name, node.text] })
      expect(body.css('pre').map(&:text)).to eq(source_body.css('pre').map(&:text))
      expect(body.css('a').map(&:text)).to eq(source_body.css('a').map(&:text))
      expect(payload.fetch('markdown')).to include('_no state qualifies_', '**calibrated estimate**', '_verified **joint interval**_', '``A*B`C``', '[_complete guide_](https://data.publication.example.test/explanation)')
      expect(payload.fetch('markdown')).to include(source_body.at_css('pre').text)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
