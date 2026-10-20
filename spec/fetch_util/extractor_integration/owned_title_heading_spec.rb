# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'

RSpec.describe 'Physical title ownership after authored context' do
  include_context 'extractor integration helpers'

  def title_context_page(heading_markup, title:, program: "request --complete\nretain trailing spaces  ")
    references = (1..7).map do |number|
      %(<p>Authored resource number #{number}: <a href="/reference/#{number}">context #{number}</a> remains part of this publication.</p>)
    end.join
    <<~HTML
      <html><head><title>#{title}</title><meta name="generator" content="Mintlify"></head>
      <body><main id="content-area"><article><section>
      <div class="authored-context">#{references}</div><header>#{heading_markup}</header>
      <p>The complete explanation and its independent resources belong to this physical article and must retain their original order.</p>
      <h2>Supporting explanation</h2><p>This independently authored paragraph follows the publication title without replacing its context.</p>
      <pre><code class="language-text">#{program}</code></pre>
      <p>Final authored statement with the <a href="/final-resource">complete final resource</a>.</p>
      </section></article></main></body></html>
    HTML
  end

  def assert_title_context(page, payload, before, program)
    markdown = payload.fetch('markdown')
    native = Nokogiri::HTML5.fragment(payload.fetch('html'))
    references = native.css('a[href]').map { |node| [node.text, node['href']] }
    (1..7).each do |number|
      expect(markdown.scan("Authored resource number #{number}:").length).to eq(1)
      expect(references.count(["context #{number}", "https://docs.publication.example.test/reference/#{number}"])).to eq(1)
    end
    expect(native.css('pre').map(&:text)).to eq([program])
    expect(markdown).to include("```\n#{program}\n```", '[complete final resource](https://docs.publication.example.test/final-resource)')
    expect(page.evaluate('document.body.innerHTML')).to eq(before)
    native
  end

  it 'keeps one physical title after every authored reference without adding a synthetic copy' do
    title = 'Complete publication title'
    program = "request --complete\nretain trailing spaces  "
    with_url_page('https://docs.publication.example.test/guide/title/', title_context_page("<h1>#{title}</h1>", title: title, program: program)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = assert_title_context(page, payload, before, program)
      expect(native.css('h1').map(&:text)).to eq([title])
      expect(payload.fetch('markdown').scan(/^# #{Regexp.escape(title)}$/).length).to eq(1)
      expect(payload.fetch('markdown').index('Authored resource number 7:')).to be < payload.fetch('markdown').index("# #{title}")
    end
  end

  it 'retains both independent physical titles without creating a third occurrence' do
    title = 'Independent publication title'
    program = "request --complete\nretain trailing spaces  "
    markup = "<h1>#{title}</h1><p>Separate authored title context remains between the two independently materialized headings.</p><h1>#{title}</h1>"
    with_url_page('https://docs.publication.example.test/guide/titles/', title_context_page(markup, title: title, program: program)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = assert_title_context(page, payload, before, program)
      expect(native.css('h1').map(&:text)).to eq([title, title])
      expect(payload.fetch('markdown').scan(/^# #{Regexp.escape(title)}$/).length).to eq(2)
      expect(payload.fetch('markdown')).to include('Separate authored title context remains between the two independently materialized headings.')
    end
  end

  it 'matches the complete rendered linked and literal-code heading rather than flattened Markdown text' do
    title = 'Owned Rust publication'
    program = "request --complete\nretain trailing spaces  "
    markup = '<h1>Owned <code>Rust</code> <a href="/publication-reference">publication</a></h1>'
    with_url_page('https://docs.publication.example.test/guide/linked-title/', title_context_page(markup, title: title, program: program)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = assert_title_context(page, payload, before, program)
      expect(native.css('h1').map(&:text)).to eq([title])
      expect(native.css('h1 code').map(&:text)).to eq(['Rust'])
      expect(native.css('h1 a').map { |node| [node.text, node['href']] }).to eq([['publication', 'https://docs.publication.example.test/publication-reference']])
      headings = payload.fetch('markdown').lines.grep(/^# /)
      expect(headings.length).to eq(1)
      expect(headings.first).to include('`Rust`', '[publication](https://docs.publication.example.test/publication-reference)')
    end
  end

  it 'does not use a literal program title as evidence of a physical rendered heading' do
    title = 'Declared fallback publication'
    program = "# #{title}\nrequest --complete  "
    with_url_page('https://docs.publication.example.test/guide/fallback-title/', title_context_page('', title: title, program: program)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      native = assert_title_context(page, payload, before, program)
      expect(native.css('h1')).to be_empty
      outside_program = payload.fetch('markdown').sub("```\n#{program}\n```", '')
      expect(outside_program.scan(/^# #{Regexp.escape(title)}$/).length).to eq(1)
    end
  end
end
