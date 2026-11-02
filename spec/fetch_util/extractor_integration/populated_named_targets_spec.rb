# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Populated named anchor declarations' do
  include_context 'extractor integration helpers'

  def named_anchor_document(content)
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

  def observe_named_anchor(html)
    with_url_page('https://research.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield Nokogiri::HTML5.fragment(payload.fetch('html')), payload
    end
  end

  it 'keeps an ordinary populated link target at its exact joined inline boundary' do
    content = '<p>Before<a id="contribute" class="button" href="https://manual.example.test/contribute?edition=full&amp;view=text#report">Contribute</a>after.</p>'
    observe_named_anchor(named_anchor_document(content)) do |native, payload|
      link = native.at_css('a#contribute')
      expect(link.text).to eq('Contribute')
      expect(link['href']).to eq('https://manual.example.test/contribute?edition=full&view=text#report')
      expect(native.text).to include('A final account describes the published methods')
      expect(payload.fetch('markdown')).to include(
        'Before<a id="contribute"></a>[Contribute](https://manual.example.test/contribute?edition=full&view=text#report)after.'
      )
    end
  end

  it 'keeps independent equal IDs and legacy names without flattening either linked label' do
    content = '<p>First <a id="same-position" name="legacy-first" href="/records/one?edition=full&amp;view=text#report">' \
      '<em>complete</em> first record</a> retains its physical declaration.</p>' \
      '<p>Second <a id="same-position" name="legacy-second" href="/records/two?edition=full&amp;view=text#report">' \
      '<strong>complete</strong> second record</a> retains its independent declaration.</p>'
    observe_named_anchor(named_anchor_document(content)) do |native, payload|
      expect(native.css('a[id="same-position"]').length).to eq(2)
      expect(native.css('a[id="same-position"]').map { |node| node['name'] }).to eq(%w[legacy-first legacy-second])
      markdown = payload.fetch('markdown')
      expect(markdown).to include(
        '[_complete_ first record](https://research.example.test/records/one?edition=full&view=text#report)',
        '[**complete** second record](https://research.example.test/records/two?edition=full&view=text#report)'
      )
      declarations = Nokogiri::HTML5.fragment(markdown).css('a[id="same-position"]')
      expect(declarations.map { |node| node['name'] }).to eq(%w[legacy-first legacy-second])
      expect(declarations.all? { |node| node.children.empty? && !node.key?('href') }).to be(true)
    end
  end

  it 'keeps the owning target once when an ordinary link is represented as a list record' do
    sections = %w[Research Methods Evidence].map.with_index do |label, group|
      links = 4.times.map do |index|
        identity = group.zero? && index.zero? ? ' id="contribute"' : ''
        heading = index.even? ? "<h3>#{label} record group #{index}</h3>" : ''
        <<~HTML
          #{heading}<a#{identity} class="button" href="https://manual.example.test/#{group}/#{index}?edition=full&amp;view=text#report">#{label} resource #{index}</a>
        HTML
      end.join
      "<section><h2>#{label} resources</h2><p>Complete independent #{label.downcase} resources " \
        "retain their physical destinations and original source ordering.</p>#{links}</section>"
    end.join
    observe_named_anchor("<html><head><title>Shared research resources</title></head><body><div id=\"page\">" \
      "<section class=\"content\">#{sections}</section></div></body></html>") do |native, payload|
      expect(native.css('a#contribute').length).to eq(1)
      expect(payload.fetch('contentType')).to eq('list')
      markdown = payload.fetch('markdown')
      %w[Research Methods Evidence].each.with_index do |label, group|
        4.times do |index|
          expect(markdown).to include("[#{label} resource #{index}](https://manual.example.test/#{group}/#{index}?edition=full&view=text#report)")
        end
      end
      expect(markdown.scan('<a id="contribute"></a>').length).to eq(1)
      expect(markdown.index('<a id="contribute"></a>')).to be < markdown.index('[Research resource 0]')
    end
  end

  it 'keeps hidden and interface identities excluded while preserving complete literal programs' do
    program = '<a id="literal-target" href="https://manual.example.test/literal">literal source</a>'
    content = '<p>Visible independent instructions <a hidden id="concealed-target" href="/concealed">remain concealed</a> retain their source order.</p>' \
      '<nav><a id="navigation-target" href="/navigation">Navigation controls</a></nav>' \
      '<div role="button"><a id="button-target" href="/button">Button controls</a></div>' \
      "<pre><code class=\"language-html\">#{CGI.escapeHTML(program)}</code></pre>"
    observe_named_anchor(named_anchor_document(content)) do |native, payload|
      expect(native.css('pre').map(&:text)).to include(program)
      markdown = payload.fetch('markdown')
      expect(markdown).to include("```\n#{program}\n```")
      expect(markdown).not_to include('id="concealed-target"', 'id="navigation-target"', 'id="button-target"')
    end
  end

  it 'keeps exact escaped identities and rich labels beside authored marker-like attributes' do
    identity = 'record & "Skip Ad" Ω'
    content = '<p>First <a data-fetch-util-named-anchor="0" ' \
      "id=\"#{CGI.escapeHTML(identity)}\" href=\"/records/escaped?edition=full&amp;view=text#report\">" \
      '<em>complete</em> escaped record</a> retains its complete rich label.</p>' \
      '<p>FETCHUTILNAMEDTARGET0END remains independent authored prose.</p>'
    observe_named_anchor(named_anchor_document(content)) do |native, payload|
      expect(native.css('a[id]').map { |node| node['id'] }).to include(identity)
      markdown = payload.fetch('markdown')
      declarations = Nokogiri::HTML5.fragment(markdown).css('a[id]')
      expect(declarations.map { |node| node['id'] }).to eq([identity])
      expect(declarations.all? { |node| node.children.empty? && !node.key?('href') }).to be(true)
      expect(markdown).to include(
        '[_complete_ escaped record](https://research.example.test/records/escaped?edition=full&view=text#report)',
        'FETCHUTILNAMEDTARGET0END remains independent authored prose.'
      )
      expect(markdown).not_to include('data-fetch-util-named-anchor', 'FETCHUTILNAMEDTARGETOWNED')
    end
  end
end
