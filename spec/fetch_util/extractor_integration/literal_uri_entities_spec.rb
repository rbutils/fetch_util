# frozen_string_literal: true

require 'cgi'
require 'open3'

RSpec.describe 'Literal entity text in complete Markdown destinations' do
  include_context 'extractor integration helpers'

  def uri_entity_destinations
    [
      'https://reference.example.test/item?group=all&variant=2#complete',
      'https://reference.example.test/item?group=all&amp;variant=2#complete',
      'https://reference.example.test/item?word=&copy;&variant=2#complete',
      'https://reference.example.test/item?word=&#x26;variant=2',
      'https://reference.example.test/item?word=&notAnEntity;&variant=2#complete',
      'https://reference.example.test/item?path=C:\\ledger\\&amp;literal=2#complete',
      'https://reference.example.test/item?word=%26amp%3B&variant=2#complete'
    ]
  end

  def uri_entity_page(content)
    <<~HTML
      <title>Complete declared references</title>
      <link rel="canonical" href="https://publication.example.test/reference.html">
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"WebPage","name":"Complete declared references","url":"https://publication.example.test/reference.html"}</script>
      <article><h1>Complete declared references</h1>
      <p>This complete authored introduction establishes a single publication and preserves every
      independent reference, literal value and original reading boundary in the observed source.</p>
      #{content}
      <p>Independent closing prose retains the complete editorial explanation and all declared evidence.</p>
      </article>
      <div hidden><a href="https://hidden.example.test/item?word=&amp;amp;private=2">Unpublished reference</a></div>
    HTML
  end

  def with_uri_entity_observation(content)
    with_url_page('https://publication.example.test/reference.html', uri_entity_page(content)) do |page|
      before = page.evaluate('document.body.outerHTML')
      source = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('article');
          return {
            references: Array.from(root.querySelectorAll('a[href]')).map(node => [node.textContent, node.href]),
            images: Array.from(root.querySelectorAll('img[src]')).map(node => [node.getAttribute('alt'), node.src])
          };
        })()
      JS
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      parser = 'import sys; from markdown_it import MarkdownIt; print(MarkdownIt("commonmark").enable("table").render(sys.stdin.read()))'
      rendered, error, status = Open3.capture3('python3', '-c', parser, stdin_data: payload.fetch('markdown'))
      expect(status.success?).to be(true), error
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = Nokogiri::HTML5.fragment(rendered)
      expect(native.text).not_to include('Unpublished reference')
      expect(markdown.text).not_to include('Unpublished reference')
      yield source, native, markdown, payload
    end
  end

  def with_existing_entity_markdown(markdown)
    with_url_page('https://publication.example.test/reference.html', uri_entity_page('<p>Visible profile context.</p>')) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: false)
      results = page.evaluate(<<~JS)
        (() => {
          let value = #{JSON.generate(markdown)};
          window.registerHostAwareProfile(/publication\.example\.test$/, () => ({
            contentType: 'article', markdown: value, html: '<p>Visible profile context.</p>',
            textContent: 'Visible profile context.', readerMode: false, title: document.title
          }));
          const first = window.FetchUtilExtract.extract({ reader_mode: false });
          value = first.markdown;
          const second = window.FetchUtilExtract.extract({ reader_mode: false });
          return [first.markdown, second.markdown];
        })()
      JS
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(results.last).to eq(results.first)
      parser = 'import sys; from markdown_it import MarkdownIt; print(MarkdownIt("commonmark").enable("table").render(sys.stdin.read()))'
      documents = [markdown, *results].map do |value|
        rendered, error, status = Open3.capture3('python3', '-c', parser, stdin_data: value)
        expect(status.success?).to be(true), error
        Nokogiri::HTML5.fragment(rendered)
      end
      yield documents
    end
  end

  it 'preserves every literal named, numeric and invalid entity in ordered link destinations' do
    references = uri_entity_destinations.each_with_index.map do |uri, index|
      "<a href='#{CGI.escapeHTML(uri)}'>Complete reference #{index + 1}</a>"
    end.join(' and ')
    with_uri_entity_observation("<p>Declared resources: #{references}.</p>") do |source, native, markdown, _payload|
      expect(native.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      expect(markdown.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      source_paragraphs = native.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      expect(markdown.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(source_paragraphs)
    end
  end

  it 'preserves complete image destinations and independent repeated occurrences' do
    uris = [uri_entity_destinations[1], uri_entity_destinations[2], uri_entity_destinations[1], uri_entity_destinations[5]]
    images = uris.each_with_index.map do |uri, index|
      "<p><img src='#{CGI.escapeHTML(uri)}' width='480' height='320' alt='Independent diagram #{index + 1}'></p>"
    end.join
    with_uri_entity_observation(images) do |source, native, markdown, _payload|
      expect(native.css('img').map { |node| [node['alt'], node['src']] }).to eq(source.fetch('images'))
      expect(markdown.css('img').map { |node| [node['alt'], node['src']] }).to eq(source.fetch('images'))
      source_paragraphs = native.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      expect(markdown.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(source_paragraphs)
      expect(markdown.css('img').map { |node| node.parent.name }).to eq(native.css('img').map { |node| node.parent.name })
    end
  end

  it 'retains complete named paragraph owners around standalone literal destinations' do
    uri = CGI.escapeHTML(uri_entity_destinations[5])
    content = <<~HTML
      <p id='complete-reference'><a href='#{uri}'>Complete standalone reference</a></p>
      <p id='complete-diagram'><img src='#{uri}' width='480' height='320' alt='Complete standalone diagram'></p>
      <p>Independent inline context <a href='#{uri}'>complete inline reference</a> remains in its paragraph.</p>
    HTML
    with_uri_entity_observation(content) do |source, native, markdown, _payload|
      expect(markdown.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      expect(markdown.css('img').map { |node| [node['alt'], node['src']] }).to eq(source.fetch('images'))
      source_paragraphs = native.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      expect(markdown.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(source_paragraphs)
      %w[complete-reference complete-diagram].each do |identity|
        expect(native.at_css("p##{identity}")).not_to be_nil
        expect(markdown.at_css("p##{identity}").to_html).to eq(native.at_css("p##{identity}").to_html)
      end
    end
  end

  it 'keeps ordinary query text, percent encoding and literal program values unchanged' do
    program = "first_value('https://reference.example.test/item?word=&amp;literal=2')\n\nlast_value('&copy;')"
    inline = 'https://reference.example.test/item?word=&amp;literal=2'
    content = <<~HTML
      <p><a href='#{CGI.escapeHTML(uri_entity_destinations.first)}'>Ordinary complete reference</a>
      and <a href='#{CGI.escapeHTML(uri_entity_destinations.last)}'>Encoded complete reference</a>.</p>
      <p>Literal evidence: <code>#{CGI.escapeHTML(inline)}</code>.</p>
      <pre><code>#{CGI.escapeHTML(program)}</code></pre>
    HTML
    with_uri_entity_observation(content) do |source, native, markdown, payload|
      expect(markdown.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      expect(payload.fetch('markdown')).to include(uri_entity_destinations.first, uri_entity_destinations.last)
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(markdown.css('pre').map(&:text)).to eq(["#{program}\n"])
      expect(native.css('code').reject { |node| node.ancestors('pre').any? }.map(&:text)).to eq([inline])
      expect(markdown.css('code').reject { |node| node.ancestors('pre').any? }.map(&:text)).to eq([inline])
    end
  end

  it 'retains the same complete destinations inside source-owned block links' do
    records = [uri_entity_destinations[1], uri_entity_destinations[1], uri_entity_destinations[5]].each_with_index.map do |uri, index|
      "<a href='#{CGI.escapeHTML(uri)}'><h2>Independent record #{index + 1}</h2>" \
        "<p>Complete independent record context #{index + 1} is retained in its original owner.</p></a>"
    end.join
    with_uri_entity_observation(records) do |source, native, markdown, _payload|
      expect(native.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      expect(markdown.css('a').map { |node| node['href'] }).to eq(source.fetch('references').map(&:last))
      markdown.css('a').zip(native.css('a')).each do |reference, original|
        if reference.at_css('h2')
          expect(reference.to_html).to eq(original.to_html)
        else
          expect(reference.text).to eq(original.at_css('h2').text)
        end
      end
      expected_paragraphs = native.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }
      expect(markdown.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to eq(expected_paragraphs)
      expect(markdown.css('h2').map(&:text)).to eq(['Independent record 1', 'Independent record 2', 'Independent record 3'])
    end
  end

  it 'preserves complete table reference and image destinations with their cell roles' do
    rows = [uri_entity_destinations[1], uri_entity_destinations[2], uri_entity_destinations[5]].each_with_index.map do |uri, index|
      "<tr><td><a href='#{CGI.escapeHTML(uri)}'>Independent table reference #{index + 1}</a></td>" \
        "<td><img src='#{CGI.escapeHTML(uri)}' width='480' height='320' alt='Table diagram #{index + 1}'></td></tr>"
    end.join
    content = "<table><thead><tr><th>Reference</th><th>Diagram</th></tr></thead><tbody>#{rows}</tbody></table>"
    with_uri_entity_observation(content) do |source, native, markdown, _payload|
      expect(native.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      expect(markdown.css('a').map { |node| [node.text, node['href']] }).to eq(source.fetch('references'))
      expect(markdown.css('img').map { |node| [node['alt'], node['src']] }).to eq(source.fetch('images'))
      expect(markdown.css('tr').length).to eq(native.css('tr').length)
      expect(markdown.css('th').map(&:text)).to eq(native.css('th').map(&:text))
      expect(markdown.css('td').length).to eq(native.css('td').length)
    end
  end

  it 'keeps existing inline, reference and angle destinations stable across repeated materialization' do
    markdown = <<~'MARKDOWN'
      [Inline complete](https://reference.example.test/item?word=&amp;amp;literal=2#complete)
      [Reference complete][full]
      ![Referenced diagram][diagram]
      [Escaped ampersand](https://reference.example.test/item?word=\&amp;literal=2#complete)
      [Query backslash](https://reference.example.test/item?path=\\ledger#complete)
      [Named tab](https://reference.example.test/item?word=&Tab;end#complete)
      [Numeric newline][newline]
      ![Entity whitespace diagram](https://reference.example.test/item?word=&#9;end#complete)
      <https://reference.example.test/item?word=&amp;literal=2#complete>

      [full]: <https://reference.example.test/item?word=&amp;copy;&variant=2#complete> "Independent title"
      [diagram]: https://reference.example.test/item?word=&amp;amp;literal=2#complete
      [newline]: <https://reference.example.test/item?word=&#10;end#complete>

      Literal inline `https://reference.example.test/item?word=&amp;literal=2` evidence.

      ```text
      first_value('https://reference.example.test/item?word=&amp;literal=2')

      last_value('&copy;')
      ```
    MARKDOWN
    with_existing_entity_markdown(markdown) do |original, first, second|
      references = original.css('a').map { |node| [node.text, node['href'], node['title']] }
      images = original.css('img').map { |node| [node['alt'], node['src']] }
      programs = original.css('code').map(&:text)
      [first, second].each do |rendered|
        expect(rendered.css('a').map { |node| [node.text, node['href'], node['title']] }).to eq(references)
        expect(rendered.css('img').map { |node| [node['alt'], node['src']] }).to eq(images)
        expect(rendered.css('code').map(&:text)).to eq(programs)
      end
    end
  end
end
