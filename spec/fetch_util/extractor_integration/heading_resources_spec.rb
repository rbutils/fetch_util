require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Source-owned heading resources' do
  include_context 'extractor integration helpers'

  def heading_resource_records
    [
      ['Getting started', '/start/', true],
      ['Source sessions', '/sessions/', false],
      ['Supported platforms', '/platforms/', false],
      ['Waiting strategies', '/waiting/', false],
      ['Reference interactions', '/interactions/', false],
      ['Independent source sessions', '/sessions/', false],
      ['Practical assistance', '/assistance/', true]
    ]
  end

  def heading_resource_program
    "const reference_edition = 42;\nconsole.log(reference_edition);"
  end

  def heading_resource_description(label)
    "#{label} publishes the complete source observations and the independently maintained instructions, " \
      'including practical examples, original reference values and the complete explanation needed to interpret each result.'
  end

  def heading_resource_page(describe_all: false, extra: '', program: heading_resource_program)
    cards = heading_resource_records.map do |label, href, described|
      description = describe_all || described ? heading_resource_description(label) : ''
      "<div class=\"entry\"><h5><a href=\"#{href}\">#{label}</a></h5><p>#{description}</p></div>"
    end.join
    literal = "<pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    <<~HTML
      <html><head><title>Independent reference guide</title><meta property="og:type" content="article"></head>
      <body><main><section><div class="report-content"><h1>Independent reference guide</h1>
      <p>This guide preserves every independently published reference destination and the full explanation of its original observations.</p>
      <p>Readers can compare the practical procedures, inspect their source records and retain the complete instructions for every supported edition.</p>
      <div class="section-index">#{cards}</div>
      <p>The final explanation remains part of this guide and preserves the publication history, original measurements and all practical comparison values.</p>
      #{literal}</div></section></main>#{extra}</body></html>
    HTML
  end

  def expect_complete_heading_resources(payload, describe_all: false, program: heading_resource_program)
    native = Nokogiri::HTML5(payload.fetch('html'))
    native.css('nav, details:not([open]), [role="dialog"]').remove
    expected = heading_resource_records.map do |label, href, _described|
      [label, "https://guide.publication.example.test#{href}"]
    end
    expect(native.css('h5 a[href]').map { |node| [node.text, node['href']] }).to eq(expected)
    expect(native.css('a[href]').map { |node| [node.text, node['href']] }).to eq(expected)
    headings = payload.fetch('markdown').lines.filter_map do |line|
      match = line.match(/^##### \[([^\]]+)\]\((https?:[^)]+)\)\s*$/)
      [match[1], match[2]] if match
    end
    expect(headings).to eq(expected)
    expected_paragraphs = [
      'This guide preserves every independently published reference destination and the full explanation of its original observations.',
      'Readers can compare the practical procedures, inspect their source records and retain the complete instructions for every supported edition.',
      *heading_resource_records.filter_map { |label, _href, described| heading_resource_description(label) if describe_all || described },
      'The final explanation remains part of this guide and preserves the publication history, original measurements and all practical comparison values.'
    ]
    expect(native.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }.reject(&:empty?)).to eq(expected_paragraphs)
    expected_paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
    expect(native.css('pre').map(&:text)).to eq([program])
    expect(payload.fetch('markdown')).to include(program)
    expect(payload.fetch('title')).to eq('Independent reference guide')
    expect(payload.fetch('html')).not_to include('data-fetchutil-reader-source-resource')
  end

  it 'preserves every physical heading-only reference in its original order and role' do
    with_url_page('https://guide.publication.example.test/manual/', heading_resource_page) do |page|
      before = page.evaluate('document.body.outerHTML')
      expect_complete_heading_resources(extract(page))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'preserves the same references when every card also owns an authored description' do
    with_url_page('https://guide.publication.example.test/manual/', heading_resource_page(describe_all: true)) do |page|
      before = page.evaluate('document.body.outerHTML')
      expect_complete_heading_resources(extract(page), describe_all: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps independent interfaces and hidden content excluded without interpreting literal program markup' do
    program = "<div class=\"entry\">\n  <h5><a href=\"/literal/\">Literal reference</a></h5>\n</div>"
    extra = <<~HTML
      <div class="entry" style="display:none"><h5><a href="/hidden/">Hidden reference</a></h5></div>
      <nav><div class="entry"><h5><a href="/navigation/">Navigation reference</a></h5></div></nav>
      <div role="dialog"><div class="entry"><h5><a href="/dialog/">Dialog reference</a></h5></div></div>
      <details><summary>Closed reference panel</summary><div class="entry"><h5><a href="/closed/">Closed reference</a></h5></div></details>
    HTML
    html = heading_resource_page(describe_all: true, extra: extra, program: program)
    with_url_page('https://guide.publication.example.test/manual/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect_complete_heading_resources(payload, describe_all: true, program: program)
      %w[Hidden Navigation Dialog Closed].each { |label| expect(payload.fetch('markdown')).not_to include("#{label} reference") }
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
