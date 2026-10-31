# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Authored horizontal-rule boundaries' do
  include_context 'extractor integration helpers'

  def separator_paragraphs
    [
      'The field study records complete observations from the first research period and explains how the measurements were collected.',
      'A second independent section describes the later observations and preserves the source relationships between the reported findings.',
      'The researchers provide a complete account of the methods so readers can distinguish the separate stages and compare the evidence.',
      'The final account retains every authored passage, the independent section boundaries, and the complete reference destinations.'
    ]
  end

  def separator_document(content, navigation: '')
    paragraphs = separator_paragraphs.map { |text| "<p>#{text}</p>" }
    <<~HTML
      <html><head><title>A field study of authored boundaries</title></head>
      <body><main>#{navigation}<article><h1>A field study of authored boundaries</h1>
      #{paragraphs.first(2).join}#{content}#{paragraphs.drop(2).join}
      <p><a href="https://records.example.test/report?edition=full&amp;view=text#methods">Complete research record</a></p>
      </article></main></body></html>
    HTML
  end

  def observe_separator(content, expected_rules:, navigation: '')
    with_url_page('https://research.example.test/boundaries/', separator_document(content, navigation: navigation)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      separator_paragraphs.each { |text| expect(native.css('p').map(&:text)).to include(text) }
      expect(native.css('hr').length).to eq(expected_rules)
      expect(native.css('a').map { |node| node['href'] }).to include(
        'https://records.example.test/report?edition=full&view=text#methods'
      )
      yield native, payload.fetch('markdown')
    end
  end

  def rendered_boundary_nodes(markdown)
    markdown.lines.filter_map do |line|
      text = line.strip.sub(/\A> ?/, '')
      if text.match?(/\A(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})\z/)
        ['hr', '']
      elsif text.start_with?('## ')
        ['h2', text.delete_prefix('## ')]
      end
    end
  end

  it 'preserves three independently positioned authored thematic breaks' do
    content = '<hr><h2>Second observation period</h2><hr><h2>Comparison of the evidence</h2><hr>'
    observe_separator(content, expected_rules: 3) do |native, markdown|
      expect(rendered_boundary_nodes(markdown)).to eq(native.css('h2,hr').map { |node| [node.name, node.text] })
    end
  end

  it 'keeps two independent adjacent source rules rather than coalescing them' do
    observe_separator('<hr><hr>', expected_rules: 2) do |_native, markdown|
      expect(rendered_boundary_nodes(markdown)).to eq([['hr', ''], ['hr', '']])
    end
  end

  it 'preserves a complete rule inside its independently owned list item' do
    content = '<ul><li>First independent observation<hr>Second independent observation</li></ul>'
    observe_separator(content, expected_rules: 1) do |_native, markdown|
      expect(rendered_boundary_nodes(markdown)).to eq([['hr', '']])
      expect(markdown).to include('First independent observation', 'Second independent observation')
    end
  end

  it 'keeps an already represented quotation rule in the quotation' do
    content = '<blockquote><p>First quoted observation.</p><hr><p>Second quoted observation.</p></blockquote>'
    observe_separator(content, expected_rules: 1) do |_native, markdown|
      expect(markdown.lines.grep(/\A> /).join).to include('First quoted observation.', 'Second quoted observation.')
      expect(rendered_boundary_nodes(markdown)).to eq([['hr', '']])
    end
  end

  it 'retains literal rule-like program lines without turning them into separators' do
    program = "first_line()\n* * *\n---\n___\nlast_line()"
    content = "<pre><code class=\"language-text\">#{CGI.escapeHTML(program)}</code></pre>"
    observe_separator(content, expected_rules: 0) do |native, markdown|
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(markdown).to include("```\n#{program}\n```")
      expect(rendered_boundary_nodes(markdown.sub(/```[\s\S]*?```/, ''))).to be_empty
    end
  end

  it 'retains literal asterisk prose as prose rather than creating a rule' do
    observe_separator('<p>* * *</p>', expected_rules: 0) do |_native, markdown|
      expect(markdown).to include('\\* \\* \\*')
      expect(rendered_boundary_nodes(markdown)).to be_empty
    end
  end

  it 'does not promote a genuine navigation separator into the article' do
    navigation = '<nav aria-label="Breadcrumb"><a href="/">Home</a> / <hr><a href="/guide/">Guide</a></nav>'
    observe_separator('<h2>Independent research account</h2>', expected_rules: 0, navigation: navigation) do |_native, markdown|
      expect(rendered_boundary_nodes(markdown)).to eq([['h2', 'Independent research account']])
      expect(markdown).not_to include('[Home]', '[Guide]')
    end
  end
end
