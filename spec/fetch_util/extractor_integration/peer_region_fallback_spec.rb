# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Complete small peer-region publications' do
  include_context 'extractor integration helpers'

  def peer_region_record(title, url, rank: 2, extra: '')
    <<~HTML
      <a class="story-card" href="#{url}"><h#{rank}>#{title}</h#{rank}>
        <p>#{title} keeps its complete independently authored account.</p>#{extra}
      </a>
    HTML
  end

  def peer_region_page(material)
    <<~HTML
      <html><head><title>Latest reports | Reference publication</title>
      <link rel="canonical" href="https://publication.example.test/">
      <meta name="generator" content="WordPress"><meta property="og:type" content="website"></head>
      <body><main id="publication">#{material}</main></body></html>
    HTML
  end

  def peer_region_material(shared: false, extra: '')
    first_url = '/reports/first?edition=2&amp;view=full#details'
    second_url = shared ? first_url : '/reports/second?edition=3&amp;view=full#details'
    first = peer_region_record('First independent account', first_url, extra: extra)
    second = peer_region_record('Second independent account', second_url, rank: 3)
    "<section><h2>Regional publication</h2>#{first}</section>" \
      "<section><h2>International publication</h2>#{second}</section>"
  end

  def check_peer_region_result(material)
    with_url_page('https://publication.example.test/', peer_region_page(material)) do |page|
      before = page.evaluate('document.body.outerHTML')
      source = Nokogiri::HTML5.fragment(before)
      records = source.css('main > section')
      references = page.evaluate("Array.from(document.querySelectorAll('main > section a[href]')).map(link => link.href)")
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      script = "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
      rendered, error, status = Open3.capture3('python3', '-c', script, stdin_data: payload.fetch('markdown'))
      raise error unless status.success?

      documents = [Nokogiri::HTML5.fragment(payload.fetch('html')), Nokogiri::HTML5.fragment(rendered)]
      expected_headings = records.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text.strip] }
      expected_paragraphs = records.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      expect(payload.fetch('title')).to eq('Latest reports | Reference publication')
      if records.css('pre').empty?
        reading = records.css('h1,h2,h3,h4,h5,h6,p').map(&:text).join(' ').gsub(/\s+/, ' ').strip
        expect(payload.fetch('readerMode')).to eq(false)
        expect(payload.fetch('textContent')).to eq(reading)
        expect(payload.fetch('excerpt')).to eq(reading)
      end
      documents.each_with_index do |document, index|
        headings = index.zero? ? expected_headings : [['h1', 'Latest reports | Reference publication']] + expected_headings
        expect(document.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text.strip] }).to eq(headings)
        expect(document.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(expected_paragraphs)
        expect(document.css('a[href]').map { |node| node['href'] }).to eq(references)
        expect(document.text).not_to include('Excluded interface-only title')
      end
      yield source, documents, payload if block_given?
    end
  end

  {
    'navigation' => '<nav>%s</nav>',
    'a hidden sibling' => '<div hidden>%s</div>',
    'a display-none sibling' => '<div style="display:none">%s</div>'
  }.each do |description, wrapper|
    it "keeps both complete regions beside #{description}" do
      excluded = peer_region_record('Excluded interface-only title', '/excluded?view=private#control')
      check_peer_region_result(peer_region_material + format(wrapper, excluded))
    end
  end

  it 'keeps independent equal-destination records and their full query and fragment' do
    check_peer_region_result("#{peer_region_material(shared: true)}<nav><a href=\"/menu\">Menu</a></nav>")
  end

  it 'preserves all record-owned literal bytes and inline emphasis' do
    literal = "query(\"<kept>\")\n\nreturn \"a&b\""
    extra = '<p><em>Exact emphasized context.</em></p>' \
      "<pre><code>query(\"&lt;kept&gt;\")\n\nreturn \"a&amp;b\"</code></pre>"
    material = "#{peer_region_material(extra: extra)}<nav><a href=\"/menu\">Menu</a></nav>"
    check_peer_region_result(material) do |source, documents, payload|
      expect(documents.first.css('pre').map(&:text)).to eq([literal])
      fenced = payload.fetch('markdown').include?("```\n#{literal}\n```")
      expect(documents.last.css('pre').map(&:text)).to eq([fenced ? "#{literal}\n" : literal])
      documents.each do |document|
        expect(document.css('em').map(&:text)).to eq(source.css('em').map(&:text))
      end
    end
  end
end
