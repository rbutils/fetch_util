# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Source-owned heading-only resource cards' do
  include_context 'extractor integration helpers'

  def resource_cards
    (1..14).map do |number|
      identity = number == 14 ? 13 : number
      ["Resource #{identity}", "https://manual.example.test/resources/item-#{identity}?edition=full&view=text#reference"]
    end
  end

  def literal_card_program
    "sample = '<a href=\"/literal\"><h3>Literal resource</h3></a>'\nputs(sample)"
  end

  def resource_grid(entries)
    entries.map do |label, destination|
      <<~HTML
        <a data-card="true" href="#{CGI.escapeHTML(destination)}"><h3>#{label}</h3>
        <svg aria-hidden="true" viewBox="0 0 10 10"><path d="M1 1L9 9" /></svg></a>
      HTML
    end.join
  end

  def resource_document(boundary: nil)
    sections = resource_cards.each_slice(7).with_index.map do |entries, index|
      <<~HTML
        <section><h2>Reference group #{index + 1}</h2>
        <p>Each complete resource below belongs to this independently headed part of the handbook.</p>
        <div class="resource-grid">#{resource_grid(entries)}</div></section>
      HTML
    end.join
    sections = "<nav aria-label=\"Account navigation\"><form>#{sections}</form></nav>" if boundary == :interface
    sections = "<div style=\"display:none\">#{sections}</div>" if boundary == :hidden
    <<~HTML
      <html><head><title>Integration handbook | Example Labs</title>
      <link rel="canonical" href="https://manual.example.test/reference/">
      <meta property="og:type" content="article"></head>
      <body><main><article><h1>Integration handbook</h1>
      <p>This handbook documents the available resources for application developers and operators.
      The separately headed groups preserve each complete reference in its physical source order.</p>
      #{sections}
      <h2>Literal example</h2><pre><code>#{CGI.escapeHTML(literal_card_program)}</code></pre>
      <p>This concluding explanation belongs to the handbook and follows every resource group and the complete program.</p>
      </article></main></body></html>
    HTML
  end

  it 'retains every complete heading-only resource and its full destination, including independent equal records' do
    html = resource_document
    with_url_page('https://manual.example.test/reference/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(native.css('pre').map(&:text)).to eq([literal_card_program])
      expect(payload.fetch('readerMode')).to be(true)
      expect(native.css('h3').map { |heading| [heading.text, heading.ancestors('a').first&.[]('href')] }).to eq(resource_cards)
      resource_cards.uniq.each do |label, destination|
        expect(payload.fetch('markdown').scan("[#{label}](#{destination})").length).to eq(resource_cards.count([label, destination]))
      end
      expect(payload.fetch('markdown')).to include(literal_card_program, 'This concluding explanation belongs to the handbook')
    end
  end

  %i[interface hidden].each do |boundary|
    it "excludes #{boundary} resource groups without changing the literal program or live BODY" do
      with_url_page('https://manual.example.test/reference/', resource_document(boundary: boundary)) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract(page)
        native = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
        expect(native.css('pre').map(&:text)).to eq([literal_card_program])
        expect(native.css('h3')).to be_empty
        resource_cards.each { |label, destination| expect(payload.fetch('markdown')).not_to include(label, destination) }
        expect(payload.fetch('markdown')).to include(literal_card_program, 'This concluding explanation belongs to the handbook')
      end
    end
  end

  it 'retains complete nested prose-and-card regions with responsive resources in physical order' do
    source = Nokogiri::HTML5.parse(resource_document)
    source.css('.resource-grid').each do |grid|
      grid.wrap('<div data-record-composition="true"></div>')
      grid.add_previous_sibling('<p>The following resources form one complete authored group.</p>')
    end
    source.css('.resource-grid > a').each_with_index do |card, index|
      image = Nokogiri::XML::Node.new('img', source)
      image['src'] = "https://manual.example.test/logos/resource-#{index + 1}.svg?rendition=full#brand"
      image['alt'] = "Resource icon #{index + 1}"
      image['srcset'] = "https://manual.example.test/logos/resource-#{index + 1}.png 1x, " \
                        "https://manual.example.test/logos/resource-#{index + 1}@2.png 2x"
      image['sizes'] = '(max-width: 700px) 64px, 96px'
      image['width'] = '64'
      image['height'] = '64'
      card.at_css('svg').replace(image)
    end
    attributes = %w[src alt srcset sizes width height]
    expected_images = source.css('.resource-grid img').map { |image| attributes.map { |name| image[name] } }
    with_url_page('https://manual.example.test/reference/', source.to_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(payload.fetch('readerMode')).to be(true)
      expect(native.css('h3').map { |heading| [heading.text, heading.ancestors('a').first&.[]('href')] }).to eq(resource_cards)
      expect(native.css('img').map { |image| attributes.map { |name| image[name] } }).to eq(expected_images)
      expect(native.css('p').map(&:text).count('The following resources form one complete authored group.')).to eq(2)
      expect(native.css('pre').map(&:text)).to eq([literal_card_program])
      resource_cards.uniq.each do |label, destination|
        expect(payload.fetch('markdown').scan("[#{label}](#{destination})").length).to eq(resource_cards.count([label, destination]))
      end
    end
  end

  it 'preserves authored marker-like attributes independently of internal physical identities' do
    source = Nokogiri::HTML5.parse(resource_document)
    paragraph = source.at_css('article > p')
    paragraph['id'] = 'authored-heading-card-identities'
    authored = {
      'data-fetchutil-reader-heading-cards' => 'authored-region',
      'data-fetchutil-reader-heading-cards-card' => 'authored-card',
      'data-fetchutil-reader-heading-cards-owned' => 'another-authored-region',
      'data-fetchutil-reader-heading-cards-owned-card' => 'another-authored-card'
    }
    authored.each { |name, value| paragraph[name] = value }
    with_url_page('https://manual.example.test/reference/', source.to_html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      expect(payload.fetch('readerMode')).to be(true)
      retained = native.at_css('#authored-heading-card-identities')
      expect(retained).not_to be_nil
      expect(authored.keys.to_h { |name| [name, retained[name]] }).to eq(authored)
      expect(native.css('h3').map { |heading| [heading.text, heading.ancestors('a').first&.[]('href')] }).to eq(resource_cards)
      expect(native.css('pre').map(&:text)).to eq([literal_card_program])
    end
  end
end
