# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Authored nonempty heading fragment targets' do
  include_context 'extractor integration helpers'

  def heading_target_document(content)
    <<~HTML
      <html><head><title>An open research framework</title></head><body><main>
      <h1>An open research framework</h1>
      <p>This open source framework provides a complete research workspace and documents how independent observations are collected and compared.</p>
      <p>The authors explain the physical organization of the evidence so every complete passage and reference retains its original owner.</p>
      #{content}
      <p>A final account describes the published methods, independent resource destinations, and the complete record of the observed results.</p>
      <p><a href="https://manual.example.test/docs/overview?edition=full&amp;view=text#methods">Documentation</a>
      <a href="https://github.com/example/research">Source code</a></p>
      </main></body></html>
    HTML
  end

  def observe_heading_targets(content)
    with_url_page('https://research.example.test/', heading_target_document(content)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload.fetch('readerMode')).to eq(false)
      expect(native.text).to include('A final account describes the published methods')
      expect(native.css('a[href]').map { |node| node['href'] }).to include(
        'https://manual.example.test/docs/overview?edition=full&view=text#methods',
        'https://github.com/example/research'
      )
      yield native, payload.fetch('markdown')
    end
  end

  it 'retains the identity and rank of a complete authored heading reached by a fragment reference' do
    content = '<p><a href="#complete-methods">Read the complete methods</a></p>' \
      '<h2 id="complete-methods">Complete methods</h2>' \
      '<p>The complete physical methods section describes all independent observations and their complete reference destinations.</p>'
    observe_heading_targets(content) do |native, markdown|
      heading = native.at_css('h2#complete-methods')
      expect(heading).not_to be_nil
      expect(heading.text).to eq('Complete methods')
      expect(native.css('a[href]').map { |node| node['href'] }).to include('https://research.example.test/#complete-methods')
      expect(markdown).to include('[Read the complete methods](https://research.example.test/#complete-methods)')
      expect(markdown).to match(/^## .*Complete methods/)
      expect(markdown.lines.map(&:chomp)).to include('## Complete methods')
      expect(Nokogiri::HTML5.fragment(markdown).css('[id]').map { |node| node['id'] }).to include('complete-methods')
      expect(markdown.index('id="complete-methods"')).to be < markdown.index('## Complete methods')
    end
  end

  it 'preserves independent equal heading identities in physical source order' do
    content = '<h2 id="shared-methods">First independent methods</h2><p>The first complete methods record retains its own physical heading.</p>' \
      '<h2 id="shared-methods">Second independent methods</h2><p>The second complete methods record remains an independent occurrence.</p>'
    observe_heading_targets(content) do |native, markdown|
      expect(native.css('h2#shared-methods').map(&:text)).to eq(['First independent methods', 'Second independent methods'])
      expect(markdown).to match(/^## .*First independent methods/)
      expect(markdown).to match(/^## .*Second independent methods/)
      expect(markdown.lines.map(&:chomp)).to include('## First independent methods', '## Second independent methods')
      expect(markdown.index('First independent')).to be < markdown.index('Second independent')
      expect(Nokogiri::HTML5.fragment(markdown).css('[id]').count { |node| node['id'] == 'shared-methods' }).to eq(2)
    end
  end

  it 'preserves an already represented empty target and complete literal heading-like markup' do
    program = "<h2 id=\"literal-heading\">Literal heading</h2>\nkeep_source_exact()"
    content = '<p><span id="existing-empty-methods"></span>Complete existing methods remain available.</p>' \
      "<pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    observe_heading_targets(content) do |native, markdown|
      expect(native.css('span#existing-empty-methods').length).to eq(1)
      expect(native.css('pre').map(&:text)).to include(program)
      expect(markdown).to include('<span id="existing-empty-methods"></span>', "```\n#{program}\n```")
      expect(markdown).not_to include('<span id="literal-heading">')
    end
  end

  it 'keeps positively hidden, navigation and closed-disclosure headings outside authored targets' do
    content = '<section style="display: none"><h2 id="hidden-heading">Hidden heading</h2></section>' \
      '<nav><h2 id="navigation-heading">Navigation heading</h2><a href="/login">Sign in</a></nav>' \
      '<details><summary>Closed methods</summary><h2 id="closed-heading">Closed heading</h2></details>' \
      '<p>Visible independent instructions remain complete and readable.</p>'
    observe_heading_targets(content) do |_native, markdown|
      expect(markdown).to include('Visible independent instructions remain complete and readable.')
      expect(markdown).not_to include('id="hidden-heading"', 'id="navigation-heading"', 'id="closed-heading"')
    end
  end

  (1..6).each do |rank|
    it "retains the independent fragment identity of a physical H#{rank}" do
      content = "<h#{rank} id=\"methods-rank-#{rank}\">Methods rank #{rank}</h#{rank}>" \
        '<p>The complete physical methods section retains its original heading rank and independent named destination.</p>'
      prefix = '#' * rank
      observe_heading_targets(content) do |native, markdown|
        expect(native.at_css("h#{rank}#methods-rank-#{rank}").text).to eq("Methods rank #{rank}")
        expect(markdown).to match(/^#{prefix} .*Methods rank #{rank}/)
        expect(markdown.lines.map(&:chomp)).to include("#{prefix} Methods rank #{rank}")
        expect(Nokogiri::HTML5.fragment(markdown).css('[id]').map { |node| node['id'] }).to include("methods-rank-#{rank}")
      end
    end
  end

  it 'preserves the exact decoded heading identity while escaping syntax and cleanup-like text' do
    identity = 'methods & "quoted" Skip Ad Ω'
    content = "<h3 id=\"#{CGI.escapeHTML(identity)}\">Escaped independent methods</h3>" \
      '<p>The complete methods remain attached to their exact independently authored fragment identity.</p>'
    observe_heading_targets(content) do |native, markdown|
      expect(native.css('h3[id]').map { |node| node['id'] }).to include(identity)
      expect(markdown).to match(/^### .*Escaped independent methods/)
      expect(markdown.lines.map(&:chomp)).to include('### Escaped independent methods')
      expect(Nokogiri::HTML5.fragment(markdown).css('[id]').map { |node| node['id'] }).to include(identity)
      expect(markdown).not_to include('FETCHUTILNAMEDTARGET')
    end
  end

  it 'preserves complete rich heading children and full independent destinations' do
    content = '<h2 id="rich-methods">Complete <em>linked</em> methods ' \
      '<a href="/guide?edition=full&amp;view=text#methods">Independent guide</a> <code>observe()</code></h2>' \
      '<p>Complete rich heading material remains independently represented and readable.</p>'
    observe_heading_targets(content) do |native, markdown|
      expect(native.at_css('h2#rich-methods').css('em,a,code').map(&:text)).to eq(['linked', 'Independent guide', 'observe()'])
      expect(markdown).to match(/^## Complete /)
      expect(markdown).to match(/[*_]linked[*_]/)
      expect(markdown).to include('[Independent guide](https://research.example.test/guide?edition=full&view=text#methods)', '`observe()`')
      expect(Nokogiri::HTML5.fragment(markdown).css('[id]').map { |node| node['id'] }).to include('rich-methods')
      expect(markdown.lines.grep(/^## /).join).not_to include('<span')
    end
  end

  it 'does not reinterpret an authored token used by a heading, prose and a literal program' do
    token = 'FETCHUTILNAMEDTARGET0END'
    program = "#{token}\nkeep_source_exact()"
    content = "<h2 id=\"#{token}\">Methods retaining an authored token</h2>" \
      "<p>#{token} remains independent literal prose.</p><pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    observe_heading_targets(content) do |native, markdown|
      expect(native.at_css('h2[id]')['id']).to eq(token)
      expect(native.css('pre').map(&:text)).to include(program)
      expect(markdown).to include("```\n#{program}\n```")
      expect(markdown.lines.map(&:chomp)).to include('## Methods retaining an authored token')
      expect(markdown.scan(token).length).to eq(3)
      expect(Nokogiri::HTML5.fragment(markdown).css('[id]').map { |node| node['id'] }).to include(token)
      expect(markdown).not_to include('FETCHUTILNAMEDTARGETOWNED')
    end
  end
end
