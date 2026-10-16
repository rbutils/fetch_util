# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Documentation authored reference labels' do
  include_context 'extractor integration helpers'

  def linked_reference_page(content)
    <<~HTML
      <html><head><title>Command guide | Example documentation</title>
      <meta name="generator" content="mkdocs, mkdocs-material"></head><body>
      <main><article class="md-content__inner md-typeset">
      <h1>Command guide</h1><p>This guide explains complete command signatures and their documented options.</p>
      #{content}
      </article></main></body></html>
    HTML
  end

  it 'retains all definition and short heading labels, destinations and source order' do
    definitions = (1..603).map do |index|
      <<~HTML
        <dt><a href="#entry-#{index}"><code>reader argument#{index}</code></a></dt>
        <dd id="entry-#{index}"><p>Complete documented description for argument #{index}.</p></dd>
      HTML
    end.join
    headings = (1..64).map do |index|
      %(<h2 id="topic-#{index}"><a class="toclink" href="#topic-#{index}">API #{index}</a></h2>)
    end.join
    html = linked_reference_page("#{headings}<dl>#{definitions}</dl>")
    base = 'https://docs.publication.example.test/reference/commands/'

    with_url_page(base, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      selected = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(selected.css('dt a[href]').map { |node| [node.text, node['href']] }).to eq(
        (1..603).map { |index| ["reader argument#{index}", "#{base}#entry-#{index}"] }
      )
      expect(selected.css('h2 a[href]').map { |node| [node.text, node['href']] }).to eq(
        (1..64).map { |index| ["API #{index}", "#{base}#topic-#{index}"] }
      )
      markdown = payload.fetch('markdown')
      positions = (1..603).map do |index|
        markdown.index("[`reader argument#{index}`](#{base}#entry-#{index})")
      end
      expect(positions).not_to include(nil)
      expect(positions).to eq(positions.sort)
      (1..64).each { |index| expect(markdown).to include("## [API #{index}](#{base}#topic-#{index})") }
      expect(selected.css('dd p').map(&:text)).to eq(
        (1..603).map { |index| "Complete documented description for argument #{index}." }
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps linked code and emphasized heading markup while removing only its permalink suffix' do
    html = linked_reference_page(<<~HTML)
      <h2 id="linked"><span><a href="#linked"><code>α-reader</code></a> <em>setup</em></span><a class="headerlink" href="#linked" title="Link for this heading">¶</a></h2>
      <p>Every setup option and its reference remains available in this complete documentation section.</p>
      <nav aria-label="Table of contents"><a href="#one">One</a><a href="#two">Two</a><a href="#three">Three</a><a href="#four">Four</a></nav>
      <p>Read the command description before applying these settings.</p>
    HTML
    base = 'https://docs.publication.example.test/reference/commands/'

    with_url_page(base, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      selected = Nokogiri::HTML5.fragment(payload.fetch('html'))
      heading = selected.at_css('h2#linked')
      expect(heading.at_css('a[href]')['href']).to eq("#{base}#linked")
      expect(heading.at_css('a code').text).to eq('α-reader')
      expect(heading.at_css('em').text).to eq('setup')
      expect(heading.text).to eq('α-reader setup')
      expect(selected.css('a.headerlink, nav')).to be_empty
      expect(payload.fetch('markdown')).to include("[`α-reader`](#{base}#linked)", 'setup')
      expect(payload.fetch('markdown')).not_to include('¶', 'Table of contents')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
