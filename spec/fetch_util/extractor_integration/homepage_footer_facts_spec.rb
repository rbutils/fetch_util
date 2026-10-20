require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Authored homepage footer facts' do
  include_context 'extractor integration helpers'

  def footer_facts_group(label, rows, attributes: '')
    cells = rows.map { |row| "<tr>#{row.map { |value| "<td>#{CGI.escapeHTML(value)}</td>" }.join}</tr>" }.join
    "<div #{attributes}><span>#{CGI.escapeHTML(label)}</span><table><tbody>#{cells}</tbody></table></div>"
  end

  def footer_facts_page(footer, program: nil)
    reports = %w[First Second Third].map do |name|
      <<~HTML
        <article><h3><a href="/exhibitions/#{name.downcase}/">#{name} independent exhibition</a></h3>
        <p>The complete #{name.downcase} exhibition description retains its independently published observations.</p></article>
      HTML
    end.join
    literal = program ? "<pre><code>#{CGI.escapeHTML(program)}</code></pre>" : ''
    <<~HTML
      <html><head><title>Independent venue collections</title><meta property="og:type" content="website"></head>
      <body><main><div class="page-content"><h1>Independent venue collections</h1>
      <p>Explore every independent exhibition and the complete information needed to plan a visit.</p>
      #{literal}<section><h2>Current exhibitions</h2>#{reports}</section>
      <footer><nav><a href="/privacy/">Privacy furniture</a><a href="/account/">Account furniture</a></nav>
      <form action="/subscribe/"><label>Newsletter address<input name="email"></label><button>Subscribe furniture</button></form>
      #{footer}</footer></div></main></body></html>
    HTML
  end

  def footer_facts_cells(html)
    Nokogiri::HTML5(html).css('table').map do |table|
      table.css('tr').map { |row| row.element_children.map { |cell| cell.text.gsub(/[[:space:]]+/, ' ').strip } }
    end
  end

  def footer_markdown_rows(markdown)
    markdown.lines.filter_map do |line|
      next unless line.strip.start_with?('|') && line.strip.end_with?('|')
      cells = line.strip.split('|', -1)[1...-1].map(&:strip)
      next if cells.all?(&:empty?) || cells.all? { |cell| cell.match?(/\A:?-+:?\z/) }
      cells
    end
  end

  it 'retains every visible atomic footer table and its complete label at the source position' do
    fees = [['Standard:', '12 credits'], ['Concession:', '8 credits'], ['Weekend:', '3 credits']]
    hours = [['Tuesday to Saturday:', '09:30 - 17:30'], ['Friday:', '09:30 - 20:30']]
    footer = footer_facts_group('Entry fees', fees) + footer_facts_group('Opening schedule', hours)
    with_url_page('https://venue.publication.example.test/en/', footer_facts_page(footer)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5(payload.fetch('html'))
      markdown = payload.fetch('markdown')
      expect(footer_facts_cells(payload.fetch('html'))).to eq([fees, hours])
      expect(footer_markdown_rows(markdown)).to eq(fees + hours)
      headers = markdown.scan(/(?:^\|[^\n]*\|\n?)+/).map do |table|
        table.lines.first.strip.split('|', -1)[1...-1].map(&:strip)
      end
      expect(headers).to eq([['', ''], ['', '']])
      expect(native.text).to include('Entry fees', 'Opening schedule')
      expect(markdown.index('Third independent exhibition')).to be < markdown.index('Entry fees')
      expect(markdown.index('Entry fees')).to be < markdown.index('Opening schedule')
      %w[First Second Third].each do |name|
        expect(markdown).to include("#{name} independent exhibition", "The complete #{name.downcase} exhibition description")
      end
      expect(markdown).not_to include('Privacy furniture', 'Account furniture', 'Newsletter address', 'Subscribe furniture')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps independent equal-valued tables and every row without a presentation limit' do
    rows = Array.new(41) { |index| ["Programme #{index + 1}:", "Value #{index + 1}"] }
    footer = footer_facts_group('First published schedule', rows) + footer_facts_group('Second published schedule', rows)
    with_url_page('https://venue.publication.example.test/', footer_facts_page(footer)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(footer_facts_cells(payload.fetch('html'))).to eq([rows, rows])
      expect(footer_markdown_rows(payload.fetch('markdown'))).to eq(rows + rows)
      expect(payload.fetch('markdown')).to include('First published schedule', 'Second published schedule')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves the complete earlier collection representation when visible facts form its source suffix' do
    rows = [['Weekday:', '42 credits'], ['Weekend:', '29 credits']]
    footer = footer_facts_group('Complete published rates', rows)
    payloads = ['', footer].map do |facts|
      markup = footer_facts_page(facts).sub('</h3>', <<~HTML)
        </h3><div class="image-wrapper">
        <img src="https://media.publication.example.test/independent-work.jpg" alt="Independent published work">
        </div>
      HTML
      with_url_page('https://venue.publication.example.test/', markup) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        payload
      end
    end
    original, enriched = payloads.map { |payload| payload.fetch('markdown') }
    expect(original).to include('![Independent published work](https://media.publication.example.test/independent-work.jpg)')
    expect(enriched).to include(original)
    expect(enriched.index('Explore every independent exhibition')).to be < enriched.index(original)
    expect(enriched.index(original) + original.length).to be < enriched.index('Complete published rates')
    expect(footer_markdown_rows(enriched)).to eq(rows)
    expect(enriched.index('Third independent exhibition')).to be < enriched.index('Complete published rates')
  end

  it 'does not turn footer navigation, hidden data or literal programme text into visible facts' do
    program = "const sample = '<footer><table><tr><td>literal data</td></tr></table></footer>';\nprint(sample); "
    footer = footer_facts_group('Unpublished schedule', [['Private:', 'Hidden value'], ['Secret:', 'Hidden second']], attributes: 'hidden')
    footer += <<~HTML
      <div><span>Navigation furniture</span><table><tbody>
      <tr><td><a href="/login/">Sign in furniture</a></td><td><a href="/register/">Register furniture</a></td></tr>
      <tr><td><a href="/legal/">Legal furniture</a></td><td><a href="/cookies/">Cookie furniture</a></td></tr>
      </tbody></table></div>
      <div style="display:none"><span>Hidden programme</span><pre><code>do_not_publish();</code></pre></div>
    HTML
    with_url_page('https://venue.publication.example.test/', footer_facts_page(footer, program: program)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(Nokogiri::HTML5(payload.fetch('html')).at_css('pre').text).to eq(program)
      expect(payload.fetch('markdown')).to include(program)
      expect(payload.fetch('markdown')).not_to include(
        'Unpublished schedule', 'Hidden value', 'Hidden second',
        'Navigation furniture', 'Sign in furniture', 'Register furniture',
        'Legal furniture', 'Cookie furniture', 'do_not_publish();'
      )
      expect(footer_facts_cells(payload.fetch('html'))).to eq([])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
