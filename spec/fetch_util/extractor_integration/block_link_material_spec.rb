# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Independent block-linked paragraph boundaries' do
  include_context 'extractor integration helpers'

  def block_link_record(title, description, destination, extra: '')
    <<~HTML
      <a href="#{CGI.escapeHTML(destination)}"><div>
        <p><strong>#{title}</strong></p><p>#{description}</p>#{extra}
      </div></a>
    HTML
  end

  def block_link_document(content)
    <<~HTML
      <!doctype html><html><head><title>Independent record reference</title>
      <link rel="canonical" href="https://boundary.publication.example.test/article">
      <meta property="og:type" content="article"></head><body>
      <main><article><h1>Independent record reference</h1>
      <p>This authored introduction establishes a complete publication containing independent linked records and explanatory paragraphs.</p>
      <section><h2>Source-owned records</h2>#{content}</section>
      <pre><code>first_call();

      second_call("[A](https://literal.example.test/a)[B](https://literal.example.test/b)");</code></pre>
      <p>This complete closing paragraph remains after every record and the literal program.</p>
      <p><a href="https://reference.example.test/boundaries?mode=complete#source">Complete source reference</a></p>
      </article></main></body></html>
    HTML
  end

  def with_block_link_document(content)
    with_url_page('https://boundary.publication.example.test/article', block_link_document(content)) do |page|
      before = page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')
      payload = extract_payload(page)
      document = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = payload.fetch('markdown')
      expect(payload.fetch('title')).to eq('Independent record reference')
      expect(document.css('h1').map(&:text)).to eq(['Independent record reference'])
      expect(document.css('h2').map(&:text)).to eq(['Source-owned records'])
      expect(document.css('pre').map(&:text)).to eq(
        ["first_call();\n\nsecond_call(\"[A](https://literal.example.test/a)[B](https://literal.example.test/b)\");"]
      )
      expect(markdown).to include("first_call();\n\nsecond_call(", '```', 'Complete source reference')
      expect(document.text).to include('This complete closing paragraph remains after every record and the literal program.')
      expect(document.css('a[href]').map { |node| node['href'] }).to include(
        'https://reference.example.test/boundaries?mode=complete#source'
      )
      expect(page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')).to eq(before)
      yield document, markdown
      expect(page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')).to eq(before)
    end
  end

  def block_link_shape(node)
    return [:text, node.text] if node.text? && node.ancestors.any? { |parent| %w[pre code].include?(parent.name) }
    return nil if node.text? && node.text.strip.empty?
    return [:text, node.text.gsub(/\s+/, ' ')] if node.text?
    return nil unless node.element?

    attributes = node.attribute_nodes.filter_map do |attribute|
      [attribute.name, attribute.value] unless %w[class style].include?(attribute.name)
    end.sort
    [node.name, attributes, node.children.filter_map { |child| block_link_shape(child) }]
  end

  def complete_block_links(document, markdown)
    select = lambda do |root|
      root.css('a[href]').select { |link| link['href'].start_with?('https://resources.publication.example.test/record/') }
    end
    native = select.call(document)
    rendered = select.call(Nokogiri::HTML5.fragment(markdown))
    expect(native).not_to be_empty
    expect(rendered.map { |node| block_link_shape(node) }).to eq(native.map { |node| block_link_shape(node) })
    native
  end

  def with_materialized_block_link(input)
    directory = File.expand_path('../../../websieve', __dir__)
    modules = File.readlines(File.join(directory, 'manifest.txt')).map(&:strip)
                  .reject { |name| name.empty? || name.start_with?('#') }
    source = modules.map { |name| File.read(File.join(directory, name)) }.join("\n")
    expect(source.scan('})(window);').length).to eq(1)
    source = source.sub('})(window);', <<~JS)
      window.blockLinkMaterializationTest = function(value) { return materializedMarkdown(value, true); };
      })(window);
    JS
    with_url_page(
      'https://boundary.publication.example.test/round-trip',
      '<!doctype html><title>Complete block material</title><main>Literal input remains unchanged.</main>'
    ) do |page|
      before = page.evaluate('document.body.outerHTML')
      FetchUtil::Extractor.new.send(:inline_asset_scripts).first(2).each { |script| page.add_script_tag(content: script) }
      page.add_script_tag(content: source)
      output = page.evaluate_func('value => window.blockLinkMaterializationTest(value)', input)
      yield output
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains independent paragraph roles and boundaries between adjacent linked records' do
    records = [
      block_link_record('Follow updates', 'Updates appear as complete saved webpages.', 'https://resources.publication.example.test/record/updates'),
      block_link_record('Upload a copy', 'Upload a complete copy from your own browser.', 'https://resources.publication.example.test/record/upload'),
      block_link_record('Search everything', 'Search every independently saved record.', 'https://resources.publication.example.test/record/search')
    ].join
    with_block_link_document(records) do |document, markdown|
      links = complete_block_links(document, markdown)
      expect(links.map { |link| link.css('p').map(&:text) }).to eq(
        [
          ['Follow updates', 'Updates appear as complete saved webpages.'],
          ['Upload a copy', 'Upload a complete copy from your own browser.'],
          ['Search everything', 'Search every independently saved record.']
        ]
      )
    end
  end

  it 'retains complete formatting, literal inline text and image resources inside one block link' do
    record = block_link_record(
      'Complete <em>record</em>', 'Use <code>value --flag</code> without merging its words.',
      'https://resources.publication.example.test/record/material?view=full#detail',
      extra: '<img src="https://images.example.test/record.png?size=large#preview" alt="Independent record preview">'
    )
    with_block_link_document(record) do |document, markdown|
      link = complete_block_links(document, markdown).fetch(0)
      expect(link.css('p').map { |paragraph| paragraph.text.strip }).to eq(
        ['Complete record', 'Use value --flag without merging its words.', '']
      )
      expect(link.css('p').last.element_children.map(&:name)).to eq(['img'])
      expect(link.css('em').map(&:text)).to eq(['record'])
      expect(link.css('code').map(&:text)).to eq(['value --flag'])
      expect(link.css('img').map { |image| [image['src'], image['alt']] }).to eq(
        [['https://images.example.test/record.png?size=large#preview', 'Independent record preview']]
      )
    end
  end

  it 'retains separate equal-label equal-destination occurrences with their own descriptions' do
    destination = 'https://resources.publication.example.test/record/shared?mode=full#record'
    records = [
      block_link_record('Independent record', 'The first physical description remains complete.', destination),
      block_link_record('Independent record', 'The second physical description remains independent.', destination)
    ].join
    with_block_link_document(records) do |document, markdown|
      links = complete_block_links(document, markdown)
      expect(links.map { |link| link['href'] }).to eq([destination, destination])
      expect(links.map { |link| link.css('p').last.text }).to eq(
        ['The first physical description remains complete.', 'The second physical description remains independent.']
      )
    end
  end

  it 'preserves authored prose before, between and after independent block links' do
    records = [
      '<p>Before both physical linked records.</p>',
      block_link_record('First record', 'Complete first description.', 'https://resources.publication.example.test/record/first'),
      '<p>This paragraph belongs between the two records.</p>',
      block_link_record('Second record', 'Complete second description.', 'https://resources.publication.example.test/record/second'),
      '<p>After both physical linked records.</p>'
    ].join
    with_block_link_document(records) do |document, markdown|
      complete_block_links(document, markdown)
      expect(document.css('section > p').map(&:text)).to eq(
        ['Before both physical linked records.', 'This paragraph belongs between the two records.', 'After both physical linked records.']
      )
      expect(markdown.index('Before both physical linked records.')).to be < markdown.index('First record')
      expect(markdown.index('First record')).to be < markdown.index('This paragraph belongs between the two records.')
      expect(markdown.index('This paragraph belongs between the two records.')).to be < markdown.index('Second record')
      expect(markdown.index('Second record')).to be < markdown.index('After both physical linked records.')
    end
  end

  it 'keeps intentionally adjacent inline links within their original paragraph' do
    content = '<p>ratio:<a href="https://inline.example.test/a">A</a><a href="https://inline.example.test/b">B</a>:end</p>'
    with_block_link_document(content) do |document, markdown|
      expect(document.css('p').map(&:text)).to include('ratio:AB:end')
      expect(markdown).to include('ratio:[A](https://inline.example.test/a)[B](https://inline.example.test/b):end')
    end
  end

  it 'keeps hidden and closed block-link descriptions out of visible Markdown' do
    content = [
      '<div hidden>',
      block_link_record('Hidden record', 'Hidden record detail.', 'https://resources.publication.example.test/record/hidden'),
      '</div><details><summary>Optional linked records</summary>',
      block_link_record('Closed record', 'Closed record detail.', 'https://resources.publication.example.test/record/closed'),
      '</details>',
      block_link_record('Visible record', 'Visible record detail.', 'https://resources.publication.example.test/record/visible')
    ].join
    with_block_link_document(content) do |document, markdown|
      expect(markdown).to include('Optional linked records', 'Visible record detail.')
      expect(markdown).not_to include('Hidden record detail.', 'Closed record detail.')
      expect(document.css('details').any? { |details| details['open'].nil? }).to be(true)
    end
  end

  it 'retains a complete logical image block and literal line endings through raw HTML rematerialization' do
    input = '<div><a href="https://resources.publication.example.test/record/preview?mode=full#record"><div>' \
      '&#10;&#10;                <img src="https://images.example.test/preview.jpg?size=full#image" ' \
      'alt="Independent image preview"><p><code>first&#10;&#10;last</code></p>&#10;&#10;</div></a></div>'
    with_materialized_block_link(input) do |output|
      expect(output).not_to include("\n", "\r")
      rendered = Nokogiri::HTML5.fragment(output)
      expect(rendered.css('a').map { |node| node['href'] }).to eq(
        ['https://resources.publication.example.test/record/preview?mode=full#record']
      )
      expect(rendered.css('a img').map { |node| [node['src'], node['alt']] }).to eq(
        [['https://images.example.test/preview.jpg?size=full#image', 'Independent image preview']]
      )
      expect(rendered.css('code').map(&:text)).to eq(["first\n\nlast"])
      expect(rendered.css('pre')).to be_empty
    end
  end

  it 'keeps the original paragraph boundaries of an unrelated unowned raw division' do
    input = '<div>Before an authored boundary.&#10;&#10;After the authored boundary.</div>'
    with_materialized_block_link(input) do |output|
      expect(output).to include("Before an authored boundary.\n\nAfter the authored boundary.")
      expect(output).not_to include('&#10;')
    end
  end
end
