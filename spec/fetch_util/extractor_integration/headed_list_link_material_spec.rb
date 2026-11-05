# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Complete heading and prose links inside authored lists' do
  include_context 'extractor integration helpers'

  def headed_record(heading, description, destination, attributes: '', extra: '')
    <<~HTML
      <li><a href="#{CGI.escapeHTML(destination)}" #{attributes}><div>
      <h2>#{heading}</h2><p>#{description}</p>#{extra}</div></a></li>
    HTML
  end

  def headed_document(content)
    <<~HTML
      <!doctype html><html><head><title>Complete collection references</title>
      <meta property="og:type" content="article">
      <link rel="canonical" href="https://collection.publication.example.test/article"></head>
      <body><main><article><h1>Complete collection references</h1>
      <p>This complete introduction describes independently authored collection records and the source material attached to each physical reference.</p>
      <p>Readers need every destination, complete heading and explanatory paragraph rather than a flattened collection of repeated labels.</p>
      #{content}
      <pre><code>first_collection_call();

      second_collection_call("preserve literal bytes");</code></pre>
      <p>This complete closing paragraph follows all independent records and the literal program without losing its authored position.</p>
      <p><a href="https://reference.example.test/collections?edition=full#source">Complete source reference</a></p>
      </article></main></body></html>
    HTML
  end

  def observe_headed_list(content)
    with_url_page('https://collection.publication.example.test/article', headed_document(content)) do |page|
      before = page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')
      payload = extract_payload(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = payload.fetch('markdown')
      expect(payload.fetch('title')).to eq('Complete collection references')
      expect(native.css('h1').map(&:text)).to eq(['Complete collection references'])
      expect(native.css('pre').map(&:text)).to eq(
        ["first_collection_call();\n\nsecond_collection_call(\"preserve literal bytes\");"]
      )
      expect(markdown).to include('```', "first_collection_call();\n\nsecond_collection_call(")
      expect(native.text).to include('This complete closing paragraph follows all independent records')
      expect(markdown).to include('https://reference.example.test/collections?edition=full#source')
      expect(page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')).to eq(before)
      yield native, markdown
      expect(page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')).to eq(before)
    end
  end

  def headed_shape(node)
    return [:text, node.text] if node.text? && node.ancestors.any? { |parent| %w[pre code].include?(parent.name) }
    return nil if node.text? && node.text.strip.empty?
    return [:text, node.text.gsub(/\s+/, ' ')] if node.text?
    return nil unless node.element?

    attributes = node.attribute_nodes.filter_map do |attribute|
      [attribute.name, attribute.value] unless %w[class style].include?(attribute.name)
    end.sort
    [node.name, attributes, node.children.filter_map { |child| headed_shape(child) }]
  end

  def complete_headed_links(native, markdown, headings, paragraphs)
    select = lambda do |root|
      root.css('a[href]').select { |link| link['href'].start_with?('https://records.publication.example.test/') }
    end
    original = select.call(native)
    expect(original.map { |link| link.css('h2').map(&:text) }).to eq(headings.map { |value| [value] })
    expect(original.map { |link| link.css('p').map { |paragraph| paragraph.text.strip } }).to eq(paragraphs)
    rendered = select.call(Nokogiri::HTML5.fragment(markdown))
    expect(rendered.map { |link| headed_shape(link) }).to eq(original.map { |link| headed_shape(link) })
    original
  end

  it 'retains every complete heading, prose block and destination in an unordered collection' do
    headings = ['Archive records', 'Measured profiles', 'Independent samples']
    paragraphs = [
      ['The full archive includes every independent collection record and its original acquisition context.'],
      ['The measured profiles retain all complete observations and explanatory descriptions from the physical source.'],
      ['The independent samples preserve each original destination rather than substituting another matching label.']
    ]
    records = headings.each_with_index.map do |heading, index|
      headed_record(
        heading, paragraphs.fetch(index).first,
        "https://records.publication.example.test/collection/#{index + 1}?edition=full&view=text#record"
      )
    end.join
    observe_headed_list("<ul>#{records}</ul>") do |native, markdown|
      complete_headed_links(native, markdown, headings, paragraphs)
    end
  end

  it 'retains rich inline material, named attributes and the full linked image resource' do
    description = 'Preserve <strong>complete</strong> observations, <em>independent</em> context and <code>value --flag</code>.<br>Keep the second authored line.'
    extra = '<p><img src="https://images.example.test/record.png?size=large#preview" alt="Independent record preview"></p>'
    record = headed_record(
      'Resource collection', description,
      'https://records.publication.example.test/resource?edition=full&view=text#detail',
      attributes: 'id="resource-target" name="legacy-resource" title="Complete record reference"', extra: extra
    )
    observe_headed_list("<ul>#{record}</ul>") do |native, markdown|
      links = complete_headed_links(
        native, markdown, ['Resource collection'],
        [['Preserve complete observations, independent context and value --flag.Keep the second authored line.', '']]
      )
      expect(links.first.css('code').map(&:text)).to eq(['value --flag'])
      expect(links.first.css('br').length).to eq(1)
      expect(links.first.css('img').map { |image| [image['src'], image['alt']] }).to eq(
        [['https://images.example.test/record.png?size=large#preview', 'Independent record preview']]
      )
      expect(%w[id name title].map { |attribute| links.first[attribute] }).to eq(
        ['resource-target', 'legacy-resource', 'Complete record reference']
      )
    end
  end

  it 'preserves independent equal destinations and descriptions in an ordered collection' do
    destination = 'https://records.publication.example.test/shared?edition=full#record'
    paragraphs = [
      ['The first physical description remains independently attached to its complete source record.'],
      ['The second physical description remains separate even when its heading and full destination are equal.']
    ]
    records = paragraphs.map { |reading| headed_record('Independent record', reading.first, destination) }.join
    observe_headed_list("<ol start=\"4\">#{records}</ol>") do |native, markdown|
      links = complete_headed_links(native, markdown, ['Independent record', 'Independent record'], paragraphs)
      expect(links.map { |link| link['href'] }).to eq([destination, destination])
      expect(native.css('ol').map { |list| list['start'] }).to include('4')
    end
  end

  it 'keeps the existing outside-list heading reference and ordinary inline reference complete' do
    content = '<a href="https://outside.example.test/record?view=full#heading"><div>' \
      '<h2>Outside heading</h2><p>This complete description stays outside the authored list.</p></div></a>' \
      '<p>Read <a href="https://inline.example.test/record?view=full#reading">the independent inline reference</a> in its original paragraph.</p>'
    observe_headed_list(content) do |native, markdown|
      expect(native.css('h2').map(&:text)).to eq(['Outside heading'])
      expect(markdown).to include(
        'https://outside.example.test/record?view=full#heading',
        'This complete description stays outside the authored list.',
        'https://inline.example.test/record?view=full#reading', 'in its original paragraph.'
      )
    end
  end

  it 'keeps genuinely hidden and closed list descriptions out of visible Markdown' do
    hidden = headed_record(
      'Hidden collection', 'Hidden collection description must remain excluded.',
      'https://hidden.example.test/record'
    )
    closed = headed_record(
      'Closed collection', 'Closed collection description must remain excluded.',
      'https://closed.example.test/record'
    )
    observe_headed_list("<div hidden><ul>#{hidden}</ul></div><details><summary>Optional collections</summary><ul>#{closed}</ul></details>") do |native, markdown|
      expect(markdown).to include('Optional collections')
      expect(markdown).not_to include('Hidden collection description', 'Closed collection description')
      expect(native.css('details').any? { |node| node['open'].nil? }).to be(true)
    end
  end

  it 'preserves an unsafe-link reading without publishing its executable destination' do
    content = '<ul><li><a href="javascript:collection_action()"><div><h2>Unsafe destination</h2>' \
      '<p>This source reading does not authorize an executable link resource.</p></div></a></li></ul>'
    observe_headed_list(content) do |native, markdown|
      expect(native.text).to include('Unsafe destination', 'This source reading does not authorize an executable link resource.')
      expect(markdown).not_to include('](javascript:', 'href="javascript:')
      expect(markdown).to include('first_collection_call();', 'second_collection_call(')
    end
  end
end
