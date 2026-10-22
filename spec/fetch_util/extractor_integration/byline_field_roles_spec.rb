# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'inferred byline field roles' do
  include_context 'extractor integration helpers'

  def field_role_paragraphs
    [
      'The regional archive preserves complete public records and explains how readers can inspect the evidence behind every published summary. ' \
        'Its catalogue combines historical documents with contemporary accounts from the communities that contributed them.',
      'Each entry retains its original context, attribution and supporting resources. Readers can compare the source documents, ' \
        'follow the editorial method and understand which details remain uncertain without losing the surrounding explanation.',
      'The reference collection is maintained through a documented review process. Its curators record corrections, ' \
        'preserve independently contributed material and make the complete supporting information available to researchers and local readers.'
    ]
  end

  def field_role_program
    "author = \"literal program value\"\nreturn author"
  end

  def field_role_page(body_class: '', heading_class: '', section_class: '', program_class: '', attribution: '')
    <<~HTML
      <html><head><title>A complete public reference</title></head>
      <body class="#{body_class}"><div class="publication">
        <h1 class="#{heading_class}">A complete public reference</h1>
        #{attribution}
        <section class="#{section_class}">
          #{field_role_paragraphs.map { |text| "<p>#{text}</p>" }.join}
          <p><a href="/references/method">Read the complete editorial method</a>.</p>
        </section>
        <pre><code class="#{program_class}">#{field_role_program}</code></pre>
      </div></body></html>
    HTML
  end

  def inspect_field_role_page(html, expected_byline)
    with_url_page('https://journal.publication.example.test/reports/reference', html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      expect(payload).to include('title' => 'A complete public reference', 'byline' => expected_byline)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(native.css('p').map(&:text)).to include(*field_role_paragraphs)
      field_role_paragraphs.each { |text| expect(payload.fetch('markdown')).to include(text) }
      expect(native.css('pre').map(&:text)).to eq([field_role_program])
      expect(payload.fetch('markdown')).to include(field_role_program)
      expect(native.css('a').map { |link| [link.text, link['href']] }).to include(
        ['Read the complete editorial method', 'https://journal.publication.example.test/references/method']
      )
      Nokogiri::HTML5.fragment(html).css('[itemprop="jobTitle"]').each do |field|
        expect(native.text).to include(field.text)
        expect(payload.fetch('markdown')).to include(field.text)
      end
    end
  end

  it 'does not treat a document presentation class as an author field' do
    inspect_field_role_page(field_role_page(body_class: 'layout-byline-disabled'), nil)
  end

  it 'does not turn authored paragraph-layout classes into authorship' do
    inspect_field_role_page(field_role_page(section_class: 'paragraph-authored-spacing'), nil)
  end

  it 'does not interpret a heading typeface as the publication author' do
    inspect_field_role_page(field_role_page(heading_class: 'font-author'), nil)
  end

  it 'does not interpret automatic rotation styling as a localized author field' do
    inspect_field_role_page(field_role_page(section_class: 'carousel autorotation-enabled'), nil)
  end

  it 'retains a literal program whose class contains an author marker' do
    inspect_field_role_page(field_role_page(program_class: 'author'), nil)
  end

  it 'preserves a genuine compound byline field alongside typography classes' do
    attribution = '<p class="font-author articleByline">Ari Reader and Bo Editor</p>'
    inspect_field_role_page(field_role_page(attribution: attribution), 'Ari Reader and Bo Editor')
  end

  it 'preserves the structured name within a declared author entity' do
    attribution = <<~HTML
      <div itemprop="author" itemscope itemtype="https://schema.org/Person">
        <span itemprop="name">Ari Reader</span><span itemprop="jobTitle">Editor</span>
      </div>
    HTML
    inspect_field_role_page(field_role_page(attribution: attribution), 'Ari Reader')
  end

  it 'retains original author-field evidence when inline cleanup removes its child markers' do
    attribution = <<~HTML
      <p itemprop="author" itemscope itemtype="https://schema.org/Person">
        <span itemprop="name">Ari Reader</span><span itemprop="jobTitle">Editor</span>
      </p>
    HTML
    inspect_field_role_page(field_role_page(attribution: attribution), 'Ari Reader')
  end

  it 'preserves independently proved localized profile attribution without an author class' do
    attribution = '<p class="credit">Par <a href="/auteur/ari-reader/">Ari Reader</a></p>'
    inspect_field_role_page(field_role_page(attribution: attribution), 'Ari Reader')
  end
end
