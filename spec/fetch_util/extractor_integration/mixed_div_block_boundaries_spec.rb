# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Physical mixed DIV boundaries' do
  include_context 'extractor integration helpers'

  def boundary_paragraphs
    [
      'This open source framework provides a complete research workspace and documents how independent observations are collected and compared.',
      'The authors explain the physical organization of the evidence so every complete passage and reference retains its original owner.',
      'A final account describes the published methods, independent resource destinations, and the complete record of the observed results.'
    ]
  end

  def boundary_document(content)
    <<~HTML
      <html><head><title>An open research framework</title></head><body><main>
      <h1>An open research framework</h1>
      #{boundary_paragraphs.first(2).map { |text| "<p>#{text}</p>" }.join}
      #{content}
      <p>#{boundary_paragraphs.last}</p>
      <p><a href="https://manual.example.test/docs/overview?edition=full&amp;view=text#methods">Documentation</a>
      <a href="https://github.com/example/research">Source code</a></p>
      </main></body></html>
    HTML
  end

  def observe_boundary(content)
    with_url_page('https://research.example.test/', boundary_document(content)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(payload.fetch('readerMode')).to eq(false)
      boundary_paragraphs.each { |text| expect(native.text).to include(text) }
      expect(native.css('a[href]').map { |node| node['href'] }).to include(
        'https://manual.example.test/docs/overview?edition=full&view=text#methods',
        'https://github.com/example/research'
      )
      yield native, payload.fetch('markdown')
    end
  end

  it 'separates an accessible label from the first reference in a following source block' do
    content = '<div><a href="/intro?edition=full&amp;view=text#record" aria-label="Opening reference"></a>' \
      '<div><a href="/release?edition=full&amp;view=text#record">Release reference</a>' \
      '<h2>Independent method boundary</h2></div></div>'
    observe_boundary(content) do |native, markdown|
      link = native.at_css('a[aria-label="Opening reference"]')
      expect(link['href']).to eq('https://research.example.test/intro?edition=full&view=text#record')
      expect(native.css('h2').map(&:text)).to include('Independent method boundary')
      expect(markdown).to include('[Opening reference](https://research.example.test/intro?edition=full&view=text#record)')
      expect(markdown).to include('[Release reference](https://research.example.test/release?edition=full&view=text#record)')
      expect(markdown).to match(/\[Opening reference\]\([^\n]+\)\s+\[Release reference\]/)
    end
  end

  it 'keeps trailing prose inside its source block separate from a following resource' do
    prose = 'A complete independent description ends at this physical source boundary.'
    content = "<div><h2>Detailed observation</h2><span>#{prose}</span></div>" \
      '<span><a href="/method?edition=full&amp;view=text#record">Method reference</a></span>'
    observe_boundary(content) do |native, markdown|
      expect(native.text).to include(prose)
      expect(native.css('h2').map(&:text)).to include('Detailed observation')
      expect(native.css('a[href]').map { |node| node['href'] }).to include(
        'https://research.example.test/method?edition=full&view=text#record'
      )
      expect(markdown).to match(/#{Regexp.escape(prose)}\s+\[Method reference\]/)
    end
  end

  it 'keeps pure nested wrappers and their complete semantic blocks' do
    content = '<div><div><h2>Complete wrapped account</h2><p>Every wrapped paragraph remains independently represented.</p></div></div>'
    observe_boundary(content) do |_native, markdown|
      expect(markdown).to include('## Complete wrapped account', 'Every wrapped paragraph remains independently represented.')
    end
  end

  it 'retains intentionally joined inline prose without inserting a boundary' do
    content = '<p>joined<a href="/inline?edition=full&amp;view=text#record">Label</a>continuation.</p>'
    observe_boundary(content) do |_native, markdown|
      expect(markdown).to include('joined[Label](https://research.example.test/inline?edition=full&view=text#record)continuation.')
    end
  end

  it 'preserves both independent equal destinations around a physical heading block' do
    link = '<a href="/repeated?edition=full&amp;view=text#record">Repeated independent reference</a>'
    content = "<div>#{link}<div><h2>Distinct physical boundary</h2></div>#{link}</div>"
    observe_boundary(content) do |native, markdown|
      destination = 'https://research.example.test/repeated?edition=full&view=text#record'
      expect(native.css('a[href]').count { |node| node['href'] == destination }).to eq(2)
      expect(markdown.scan(destination).length).to eq(2)
    end
  end

  it 'retains a complete literal program containing wrapper-like source text' do
    program = "<div>first<div>second</div>third</div>\nkeep_joined()"
    content = "<pre><code class=\"language-html\">#{CGI.escapeHTML(program)}</code></pre>"
    observe_boundary(content) do |native, markdown|
      expect(native.css('pre').map(&:text)).to include(program)
      expect(markdown).to include(program)
    end
  end
end
