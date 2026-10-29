# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Complete physical records in headed sections' do
  include_context 'extractor integration helpers'

  def sectioned_record(title, url:, rank: 2, extra: '')
    <<~HTML
      <a class="story-card" href="#{url}"><h#{rank}>#{title}</h#{rank}>
        <p>#{title} keeps its complete independently authored account.</p>#{extra}
      </a>
    HTML
  end

  def sectioned_page(material)
    <<~HTML
      <html><head><title>Latest reports | Reference publication</title>
      <link rel="canonical" href="https://publication.example.test/">
      <meta name="generator" content="WordPress"><meta property="og:type" content="website"></head>
      <body><main id="publication">#{material}</main></body></html>
    HTML
  end

  def ordinary_sectioned_material
    first = sectioned_record('First independent account', url: '/reports/first?edition=2&amp;view=full#details')
    second = sectioned_record('Second independent account', url: '/reports/second?edition=3&amp;view=full#details', rank: 3)
    first += sectioned_record('Additional regional account', url: '/regional/additional#complete')
    first += sectioned_record('Third regional account', url: '/regional/third#complete')
    second += sectioned_record('Additional international account', url: '/international/additional#complete')
    second += sectioned_record('Third international account', url: '/international/third#complete')
    "<section><h2>Regional publication</h2>#{first}</section>" \
      "<section><h2>International publication</h2>#{second}</section>"
  end

  def with_sectioned_result(html)
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      source = Nokogiri::HTML5.fragment(before)
      references = page.evaluate(<<~JS)
        Array.from(document.querySelectorAll('#publication a[href]')).map(function(link) {
          return {href: link.href, heading: (link.querySelector('h1,h2,h3,h4,h5,h6') || link).textContent.trim()};
        })
      JS
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      script = "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
      rendered, error, status = Open3.capture3('python3', '-c', script, stdin_data: payload.fetch('markdown'))
      raise error unless status.success?

      yield source, Nokogiri::HTML5.fragment(payload.fetch('html')), Nokogiri::HTML5.fragment(rendered), references, payload
    end
  end

  it 'keeps the exact heading ranks, full destinations and paragraphs of selected records across regions' do
    peers = 5.times.map do |index|
      sectioned_record("Independent complete report #{index}", url: "/reports/#{index}?edition=2&amp;view=full#details")
    end.join
    lead = <<~HTML
      <div class="feature-summary"><a href="https://records.example.test/report?edition=2&amp;view=complete#record">
      <h1>A physically owned lead report</h1><p>The complete report keeps its independently authored description.
      <span class="author">By Ari Reader</span></p></a></div>
    HTML
    material = lead + "<section><h2>Latest independent reports</h2><div class='story-grid'>#{peers}</div></section>"
    with_sectioned_result(sectioned_page(material)) do |source, native, rendered, references, _payload|
      expected_headings = source.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text.strip] }
      expected_paragraphs = source.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      [native, rendered].each do |document|
        expect(document.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text.strip] }).to eq(expected_headings)
        expect(document.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(expected_paragraphs)
        expect(document.css('a[href]').map { |node| node['href'] }).to eq(references.map { |reference| reference.fetch('href') })
      end
      expect(rendered.text.scan('By Ari Reader').length).to eq(1)
    end
  end

  it 'keeps independent identical records in different regions without dropping either full reference' do
    shared = sectioned_record('Independent recurring report', url: '/reports/shared?edition=2&amp;view=full#complete')
    first = sectioned_record('Regional separate report', url: '/reports/regional#complete', rank: 3)
    second = sectioned_record('International separate report', url: '/reports/international#complete', rank: 4)
    first += sectioned_record('Another regional record', url: '/reports/regional-additional#complete')
    second += sectioned_record('Another international record', url: '/reports/international-additional#complete')
    material = "<section><h2>Regional publication</h2>#{shared}#{first}</section>" \
      "<section><h2>International publication</h2>#{shared}#{second}</section>"
    with_sectioned_result(sectioned_page(material)) do |source, native, rendered, references, _payload|
      expected_headings = source.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text.strip] }
      [native, rendered].each do |document|
        expect(document.css('a[href]').map { |node| node['href'] }).to eq(references.map { |reference| reference.fetch('href') })
        expect(document.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text.strip] }).to eq(expected_headings)
        expect(document.css('p').map { |node| node.text.strip }).to eq(source.css('p').map { |node| node.text.strip })
      end
    end
  end

  it 'keeps an entire literal program and emphasized prose inside a complete linked record' do
    literal = "query(\"<kept>\")\n\nreturn \"a&b\""
    first = sectioned_record(
      'A complete literal record',
      url: '/program?edition=2&amp;view=full#named',
      extra: "<p><em>Exact emphasized context.</em></p><pre><code>query(\"&lt;kept&gt;\")\n\nreturn \"a&amp;b\"</code></pre>"
    )
    second = sectioned_record('An independent plain record', url: '/plain#complete')
    first += sectioned_record('Additional literal account', url: '/literal/additional#complete')
    first += sectioned_record('Third literal account', url: '/literal/third#complete')
    second += sectioned_record('Additional plain account', url: '/plain/additional#complete')
    second += sectioned_record('Third plain account', url: '/plain/third#complete')
    material = "<section><h2>Literal reports</h2>#{first}</section><section><h2>Independent reports</h2>#{second}</section>"
    with_sectioned_result(sectioned_page(material)) do |source, native, rendered, references, payload|
      expect(native.css('pre').map(&:text)).to eq([literal])
      fenced = payload.fetch('markdown').include?("```\n#{literal}\n```")
      expect(rendered.css('pre').map(&:text)).to eq([fenced ? "#{literal}\n" : literal])
      [native, rendered].each do |document|
        expect(document.css('em').map(&:text)).to eq(source.css('em').map(&:text))
        expect(document.css('a[href]').map { |node| node['href'] }).to eq(references.map { |reference| reference.fetch('href') })
      end
    end
  end

  it 'does not expose hidden or navigation-owned records while conserving visible sections' do
    excluded = sectioned_record('Excluded interface-only title', url: '/excluded?view=private#control')
    wrappers = ["<nav>#{excluded}</nav>", "<div hidden>#{excluded}</div>", "<div style='display:none'>#{excluded}</div>"]
    wrappers.each do |wrapper|
      with_sectioned_result(sectioned_page(ordinary_sectioned_material + wrapper)) do |_source, native, rendered, _references, _payload|
        [native, rendered].each do |document|
          expect(document.text).not_to include('Excluded interface-only title')
          expect(document.css('a[href]').map { |node| node['href'] }.any? { |url| url.include?('/excluded') }).to eq(false)
          expect(document.text).to include('First independent account', 'Second independent account')
        end
      end
    end
  end
end
