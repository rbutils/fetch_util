# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Physical visibility of list descriptions' do
  include_context 'extractor integration helpers'

  def description_records(indices = 0...6)
    indices.map do |index|
      "<a data-record=\"#{index}\" href=\"https://records.example.test/#{index}?edition=2&amp;view=full#complete\">" \
        "<h2>Independent publication number #{index}</h2>" \
        "<p>This independent account preserves its complete separately authored explanation.</p></a>"
    end.join
  end

  def description_page(context)
    <<~HTML
      <html><head><title>Independent publications</title>
      <link rel="canonical" href="https://publication.example.test/">
      <meta name="generator" content="WordPress"><meta property="og:type" content="website"></head>
      <body><main id="publication"><section><h2>Regional publications</h2>#{description_records}</section>#{context}</main></body></html>
    HTML
  end

  def parsed_description(markdown)
    script = "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
    output, error, status = Open3.capture3('python3', '-c', script, stdin_data: markdown)
    raise error unless status.success?

    Nokogiri::HTML5.fragment(output)
  end

  def description_probe_source
    root = ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT') { File.expand_path('../../..', __dir__) }
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |name| name.empty? || name.start_with?('#') }
                 .map { |name| File.read(File.join(root, 'websieve', name)) }.join("\n")
    raise 'private closure changed' unless source.scan('})(window);').length == 1

    source.sub('})(window);', <<~JS)
      window.listDescriptionVisibilityProbe = function() {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var root = document.getElementById('publication');
            var before = root.outerHTML;
            var items = Array.from(root.querySelectorAll('a[data-record]')).map(function(link) {
              return { card: link, sourceNode: link, url: link.href,
                text: link.querySelector('h2').textContent, sourceOrderedHeadingCard: true };
            });
            var parts = listDescriptionParts(root, items, { includeInlineProse: true,
              preserveUnrepresentedText: true, sectionLabels: ['Regional publications'] });
            var references = listUnrepresentedMetadataReferences({ root: root, items: items }, parts);
            return { markdown: parts.concat(references).map(function(part) { return part.markdown; }).join('\\n\\n'),
              parts: parts.concat(references).map(function(part) {
                return { html: part.node.outerHTML, markdown: part.markdown };
              }), sourceUnchanged: root.outerHTML === before };
          })({});
        })({});
      };
      })(window);
    JS
  end

  def with_description_probe(context)
    with_url_page('https://publication.example.test/', description_page(context)) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: true)
      page.add_script_tag(content: description_probe_source)
      observation = page.evaluate('listDescriptionVisibilityProbe()')
      expect(observation.fetch('sourceUnchanged')).to eq(true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield observation, parsed_description(observation.fetch('markdown'))
    end
  end

  def withheld_description
    <<~HTML
      <h2>Withheld contextual heading</h2>
      <p>The withheld explanatory paragraph contains <a href="https://context.example.test/report?edition=2&amp;view=full#source">its complete reference</a>.</p>
      <blockquote><p>The withheld quotation keeps its independent complete wording.</p></blockquote>
      <figure><img src="https://context.example.test/figure.png?view=full#image" alt="Withheld illustration">
      <figcaption><h2>Withheld figure heading</h2><p>The complete withheld figure caption.</p></figcaption></figure>
      <a rel="tag" href="https://context.example.test/topic?edition=2&amp;view=full#topic">Withheld topic</a>
    HTML
  end

  it 'keeps closed heading, prose, quotation, figure and topic context out of description material' do
    with_description_probe("<details><summary>Optional context</summary>#{withheld_description}</details>") do |observation, rendered|
      expect(observation.fetch('parts')).to eq([])
      expect(observation.fetch('markdown')).to eq('')
      expect(rendered.element_children).to be_empty
      expect(rendered.css('a,img')).to be_empty
    end
  end

  it 'keeps the first summary and open content visible while respecting every enclosing closed boundary' do
    literal = "query(\"<kept>\")\n\nreturn \"a&b\""
    context = <<~HTML
      <details><summary><h2>Visible summary heading</h2>
      <p>The complete visible summary explains the optional publication context.</p>
      <a rel="tag" href="https://context.example.test/summary?view=full#topic">Visible summary topic</a></summary>
      <summary><h2>Second summary must stay closed</h2></summary>
      <details open><summary>Nested open control</summary><p>Enclosed content must stay closed despite its own open attribute.</p></details></details>
      <details open><summary>Open context control</summary><h2>Visible open heading</h2>
      <p>The complete visible open paragraph preserves its independently authored wording.</p>
      <blockquote><p>The visible quotation owns its complete literal example.</p>
      <pre><code>query("&lt;kept&gt;")

      return "a&amp;b"</code></pre></blockquote>
      <details><summary>Nested optional context</summary><h2>Nested closed heading</h2>
      <p>The nested closed paragraph must remain withheld from the rendered context.</p></details></details>
    HTML
    with_description_probe(context) do |observation, rendered|
      expect(rendered.css('h2').map(&:text)).to eq(['Visible summary heading', 'Visible open heading'])
      expected_paragraphs = [
        'The complete visible summary explains the optional publication context.',
        'The complete visible open paragraph preserves its independently authored wording.',
        'The visible quotation owns its complete literal example.',
        'Visible summary topic'
      ]
      expect(rendered.css('p').map(&:text)).to eq(expected_paragraphs)
      expect(rendered.css('a[href]').map { |node| node['href'] }).to eq(['https://context.example.test/summary?view=full#topic'])
      expect(rendered.css('pre').map(&:text)).to eq(["#{literal}\n"])
      quoted_fence = ['```', *literal.split("\n", -1), '```'].map { |line| "> #{line}" }.join("\n")
      expect(observation.fetch('markdown')).to include(quoted_fence)
    end
  end

  it 'excludes positively hidden context without changing the independent visible paragraph and reference' do
    visible = '<h2>Visible contextual heading</h2><p>The visible contextual paragraph contains ' \
      '<a href="https://context.example.test/visible?edition=2&amp;view=full#complete">a complete independent reference</a>.</p>'
    ['hidden', 'style="display:none"', 'style="visibility:hidden"'].each do |attribute|
      with_description_probe("#{visible}<div #{attribute}>#{withheld_description}</div>") do |_observation, rendered|
        expect(rendered.css('h2').map(&:text)).to eq(['Visible contextual heading'])
        expect(rendered.css('p').map(&:text)).to eq(['The visible contextual paragraph contains a complete independent reference.'])
        expect(rendered.css('a[href]').map { |node| node['href'] }).to eq(['https://context.example.test/visible?edition=2&view=full#complete'])
        expect(rendered.css('img,blockquote')).to be_empty
      end
    end
  end

  it 'preserves native closed state and all six visible records in the compiled result' do
    excluded = '<a href="https://context.example.test/closed?view=private#control">' \
      '<h2>Withheld independent account</h2><p>The complete closed account must not enter the visible description.</p></a>'
    html = description_page("<details id='optional-context'><summary>Optional context</summary>#{excluded}</details>")
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      rendered = parsed_description(payload.fetch('markdown'))
      expect(native.at_css('details#optional-context:not([open])').text).to include('Withheld independent account')
      expect(rendered.text).not_to include('Withheld independent account', 'complete closed account')
      expect(rendered.css('a[href]').map { |node| node['href'] }).to eq(
        6.times.map { |index| "https://records.example.test/#{index}?edition=2&view=full#complete" }
      )
      expect(rendered.css('h2').map(&:text)).to eq(['Regional publications', *6.times.map { |index| "Independent publication number #{index}" }])
      expect(rendered.css('p').map(&:text)).to eq(Array.new(6, 'This independent account preserves its complete separately authored explanation.') + ['Optional context'])
    end
  end

  it 'keeps a closed fallback record out of two visible publication regions' do
    excluded = '<a href="https://context.example.test/closed?view=private#control">' \
      '<h2>Withheld independent account</h2><p>The complete closed account must not enter visible records.</p></a>'
    context = "<section><h2>International publications</h2>#{description_records(3...6)}</section>" \
      "<details id='optional-context'><summary>Optional context</summary>#{excluded}</details>"
    html = description_page(context).sub(description_records, description_records(0...3))
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      rendered = parsed_description(payload.fetch('markdown'))
      expect(native.at_css('details#optional-context:not([open])').text).to include('Withheld independent account')
      expect(rendered.text).not_to include('Withheld independent account', 'complete closed account')
      expect(rendered.css('a[href]').map { |node| node['href'] }).to eq(
        6.times.map { |index| "https://records.example.test/#{index}?edition=2&view=full#complete" }
      )
      expected_headings = [
        'Regional publications', *3.times.map { |index| "Independent publication number #{index}" },
        'International publications', *3.times.map { |index| "Independent publication number #{index + 3}" }
      ]
      expect(rendered.css('h2').map(&:text)).to eq(expected_headings)
      expect(rendered.css('p').map(&:text)).to eq(Array.new(6, 'This independent account preserves its complete separately authored explanation.'))
    end
  end
end
