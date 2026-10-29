# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'cgi'

RSpec.describe 'Physical list-context heading ranks' do
  include_context 'extractor integration helpers'

  def heading_records
    6.times.map do |index|
      "<a data-record='#{index}' href='https://records.example.test/#{index}?view=full&amp;edition=2#complete'>" \
        "<h2>Independent record #{index}</h2><p>Record #{index} retains its complete independently authored explanation.</p></a>"
    end.join
  end

  def heading_markdown(markdown)
    script = "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
    output, error, status = Open3.capture3('python3', '-c', script, stdin_data: markdown)
    raise error unless status.success?

    Nokogiri::HTML5.fragment(output)
  end

  def heading_probe_source
    root = ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT') { File.expand_path('../../..', __dir__) }
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |name| name.empty? || name.start_with?('#') }
                 .map { |name| File.read(File.join(root, 'websieve', name)) }.join("\n")
    raise 'private closure changed' unless source.scan('})(window);').length == 1

    probe = <<~JS
      window.listContextHeadingProbe = function() {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var root = document.getElementById('publication');
            var items = Array.from(root.querySelectorAll('a[data-record]')).map(function(link) {
              return { card: link, sourceNode: link, url: link.href,
                text: link.querySelector('h2').textContent, sourceOrderedHeadingCard: true };
            });
            var parts = listDescriptionParts(root, items, { includeInlineProse: true,
              preserveUnrepresentedText: true, sectionLabels: ['Independent records'] });
            return { markdown: parts.map(function(part) { return part.markdown; }).join('\\n\\n'),
              sources: parts.map(function(part) { return part.node.outerHTML; }) };
          })({});
        })({});
      };
      })(window);
    JS
    source.sub('})(window);') { probe }
  end

  def with_heading_context(context)
    html = "<html><head><title>Complete heading context</title></head><body><main id='publication'>" \
      "<section><h2>Independent records</h2>#{heading_records}</section>#{context}</main></body></html>"
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: true)
      page.add_script_tag(content: heading_probe_source)
      observation = page.evaluate('listContextHeadingProbe()')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield observation, heading_markdown(observation.fetch('markdown'))
    end
  end

  it 'preserves every admitted heading rank and complete interleaved paragraph in source order' do
    context = (1..6).map do |rank|
      "<h#{rank}>Physical context level #{rank}</h#{rank}><p>The complete explanation for context level #{rank} remains independently authored.</p>"
    end.join
    with_heading_context(context) do |_observation, rendered|
      expected = (1..6).flat_map do |rank|
        [["h#{rank}", "Physical context level #{rank}"], ['p', "The complete explanation for context level #{rank} remains independently authored."]]
      end
      expect(rendered.element_children.map { |node| [node.name, node.text] }).to eq(expected)
    end
  end

  it 'retains a linked context heading rank and both complete independent destinations' do
    context = '<h3><a href="https://reference.example.test/one?edition=2&amp;view=full#details">First complete reference</a> / ' \
      '<a href="https://reference.example.test/two?edition=3&amp;view=whole#appendix">Second complete reference</a></h3>' \
      '<p>The complete reference explanation remains alongside the independently declared destinations.</p>'
    with_heading_context(context) do |_observation, rendered|
      expected_links = [
        ['First complete reference', 'https://reference.example.test/one?edition=2&view=full#details'],
        ['Second complete reference', 'https://reference.example.test/two?edition=3&view=whole#appendix']
      ]
      expect(rendered.element_children.map(&:name)).to eq(%w[h3 p])
      expect(rendered.at_css('h3').text).to eq('First complete reference / Second complete reference')
      expect(rendered.css('a[href]').map { |node| [node.text, node['href']] }).to eq(expected_links)
      expect(rendered.at_css('p').text).to eq('The complete reference explanation remains alongside the independently declared destinations.')
    end
  end

  it 'preserves visible summary and open heading ranks without exposing closed or literal headings' do
    literal = '<h6>literal heading syntax</h6>'
    context = '<details><summary><h3>Visible summary heading</h3></summary><h4>Withheld closed heading</h4></details>' \
      '<details open><summary>Open context</summary><h4>Visible open heading</h4>' \
      '<p>The complete open context explanation remains visible and independently authored.</p></details>' \
      '<div hidden><h5>Withheld hidden heading</h5></div>' \
      "<pre><code>#{CGI.escapeHTML(literal)}</code></pre><blockquote><h5>Quoted context heading</h5>" \
      '<p>The complete quotation remains a separate source-owned context.</p></blockquote>'
    with_heading_context(context) do |_observation, rendered|
      expected_headings = [
        ['h3', 'Visible summary heading'], ['h4', 'Visible open heading'], ['h5', 'Quoted context heading']
      ]
      expected_paragraphs = [
        'The complete open context explanation remains visible and independently authored.',
        'The complete quotation remains a separate source-owned context.'
      ]
      expect(rendered.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text] }).to eq(expected_headings)
      expect(rendered.css('p').map(&:text)).to eq(expected_paragraphs)
      expect(rendered.css('pre').map(&:text)).to eq(["#{literal}\n"])
      expect(rendered.css('blockquote h5').length).to eq(1)
      expect(rendered.text).not_to include('Withheld closed heading', 'Withheld hidden heading')
    end
  end

  it 'keeps complete context heading roles in the compiled six-record result' do
    html = <<~HTML
      <html><head><title>Complete heading context</title><link rel="canonical" href="https://publication.example.test/">
      <meta name="generator" content="WordPress"><meta property="og:type" content="website"></head>
      <body><main id="publication"><section><h2>Independent records</h2>#{heading_records}</section>
      <h3>Method and limitations</h3><p>The complete authored method explains how each independent account was selected.</p>
      <h4>Boundary conditions</h4><p>The complete boundary conditions remain alongside all six source-owned records.</p>
      </main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expected_headings = [['h3', 'Method and limitations'], ['h4', 'Boundary conditions']]
      expected_paragraphs = [
        'The complete authored method explains how each independent account was selected.',
        'The complete boundary conditions remain alongside all six source-owned records.'
      ]
      [Nokogiri::HTML5.fragment(payload.fetch('html')), heading_markdown(payload.fetch('markdown'))].each do |root|
        expect(root.css('h3,h4').map { |node| [node.name, node.text] }).to eq(expected_headings)
        expect(root.css('h2').map(&:text)).to eq(['Independent records', *6.times.map { |index| "Independent record #{index}" }])
        expect(root.css('a[href]').map { |node| node['href'] }).to eq(
          6.times.map { |index| "https://records.example.test/#{index}?view=full&edition=2#complete" }
        )
        expect(root.css('p').to_a.last(2).map(&:text)).to eq(expected_paragraphs)
      end
    end
  end

  it 'retains context ranks beside two complete compiled record regions and an exact literal program' do
    peers = 5.times.map do |index|
      "<a class='story-card' href='/reports/#{index}?edition=2&amp;view=full#details'>" \
        "<h2>Independent complete report #{index}</h2>" \
        "<p>Report #{index} keeps every authored word and its own independently declared destination.</p></a>"
    end.join
    literal = "query(\"<h5>literal</h5>\")\n\nreturn \"a&b\""
    html = <<~HTML
      <html><head><title>Latest reports | Reference publication</title>
      <link rel="canonical" href="https://publication.example.test/">
      <meta name="generator" content="WordPress"><meta property="og:type" content="website"></head>
      <body><main id="publication"><div class="feature-summary">
      <a href="https://records.example.test/report?edition=2&amp;view=complete#record"><h1>A physically owned lead report</h1>
      <p>The complete report keeps its independently authored description. <span class="author">By Ari Reader</span></p></a></div>
      <section><h2>Latest independent reports</h2><div class="story-grid">#{peers}</div></section>
      <h3>Method and limitations</h3><p>The complete authored method explains how each independent account was selected.</p>
      <h4>Boundary conditions</h4><p>The complete boundary conditions remain alongside all six source-owned records.</p>
      <pre><code>#{CGI.escapeHTML(literal)}</code></pre><p>The final authored limitations remain complete.</p></main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      rendered = heading_markdown(payload.fetch('markdown'))
      expected_headings = [
        ['h1', 'A physically owned lead report'], ['h2', 'Latest independent reports'],
        *5.times.map { |index| ['h2', "Independent complete report #{index}"] },
        ['h3', 'Method and limitations'], ['h4', 'Boundary conditions']
      ]
      expected_links = [
        'https://records.example.test/report?edition=2&view=complete#record',
        *5.times.map { |index| "https://publication.example.test/reports/#{index}?edition=2&view=full#details" }
      ]
      expected_paragraphs = [
        'The complete authored method explains how each independent account was selected.',
        'The complete boundary conditions remain alongside all six source-owned records.',
        'The final authored limitations remain complete.'
      ]
      [native, rendered].each do |root|
        expect(root.css('h1,h2,h3,h4').map { |node| [node.name, node.text] }).to eq(expected_headings)
        expect(root.css('a[href]').map { |node| node['href'] }).to eq(expected_links)
        expect(root.css('p').to_a.last(3).map(&:text)).to eq(expected_paragraphs)
      end
      expect(native.css('pre').map(&:text)).to eq([literal])
      expect(rendered.css('pre').map(&:text)).to eq(["#{literal}\n"])
    end
  end
end
