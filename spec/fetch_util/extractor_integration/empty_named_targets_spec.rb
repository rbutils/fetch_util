# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Ordinary empty named target declarations' do
  include_context 'extractor integration helpers'

  def target_document(content)
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

  def observe_target(content)
    with_url_page('https://research.example.test/', target_document(content)) do |page|
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

  it 'retains the complete empty inline target reached by an authored fragment reference' do
    content = '<p><a href="#methods-intro">Read the complete methods</a></p>' \
      '<p><span id="methods-intro"></span>The complete introduction owns this target before every following instruction.</p>'
    observe_target(content) do |native, markdown|
      target = native.at_css('span#methods-intro')
      expect(target).not_to be_nil
      expect(target.children).to be_empty
      expect(native.css('a[href]').map { |node| node['href'] }).to include('https://research.example.test/#methods-intro')
      expect(markdown).to include('The complete introduction owns this target before every following instruction.')
      expect(markdown).to include('[Read the complete methods](https://research.example.test/#methods-intro)')
      expect(markdown).to include(target.to_html)
    end
  end

  it 'retains an independent legacy anchor name and ID without adding a destination' do
    content = '<p><a name="legacy-methods" id="legacy-position"></a>Complete legacy methods remain available at their original location.</p>'
    observe_target(content) do |native, markdown|
      target = native.at_css('a[name="legacy-methods"]')
      expect(target).not_to be_nil
      expect(target['id']).to eq('legacy-position')
      expect(target['href']).to be_nil
      expect(markdown).to include(target.to_html)
    end
  end

  it 'preserves independent equal declarations rather than deduplicating their identities' do
    content = '<p><span id="repeated-methods"></span>First independent physical methods declaration.</p>' \
      '<p><span id="repeated-methods"></span>Second independent physical methods declaration.</p>'
    observe_target(content) do |native, markdown|
      expect(native.css('span#repeated-methods').length).to eq(2)
      expect(markdown.scan('<span id="repeated-methods"></span>').length).to eq(2)
      expect(markdown.index('First independent')).to be < markdown.index('Second independent')
    end
  end

  it 'preserves exact parsed identities while escaping syntax and cleanup-like attribute values' do
    identity = 'methods & "quoted" Skip Ad Ω'
    content = "<p><span id=\"#{CGI.escapeHTML(identity)}\"></span>Complete methods follow the escaped declaration.</p>"
    observe_target(content) do |native, markdown|
      expect(native.css('span[id]').map { |node| node['id'] }).to include(identity)
      expect(Nokogiri::HTML5.fragment(markdown).css('span[id]').map { |node| node['id'] }).to include(identity)
      expect(markdown).not_to include('FETCHUTILNAMEDTARGET')
    end
  end

  it 'does not reinterpret authored placeholder-like text or complete literal programs' do
    token = 'FETCHUTILNAMEDTARGET0END'
    program = "#{token}\nkeep_source_exact()"
    content = "<p>#{token}<span id=\"collision-methods\"></span>Complete independent prose follows.</p>" \
      "<pre><code>#{CGI.escapeHTML(program)}</code></pre>"
    observe_target(content) do |native, markdown|
      expect(native.css('pre').map(&:text)).to include(program)
      expect(markdown).to include("```\n#{program}\n```")
      expect(markdown.scan(token).length).to eq(2)
      expect(markdown).to include('<span id="collision-methods"></span>')
      expect(markdown).not_to include('FETCHUTILNAMEDTARGETOWNED')
    end
  end

  it 'keeps intentionally joined inline prose and excludes positively hidden declarations' do
    content = '<p><span id="concealed-target" hidden></span>Visible independent instructions remain available.</p>' \
      '<p><span style="display: none"><span id="display-none-target"></span></span>Other visible instructions.</p>' \
      '<p>joined<a href="/inline?edition=full&amp;view=text#record">Inline label</a>continuation.</p>'
    observe_target(content) do |native, markdown|
      expect(native.text).to include('Visible independent instructions remain available.')
      expect(markdown).to include('joined[Inline label](https://research.example.test/inline?edition=full&view=text#record)continuation.')
      expect(markdown).not_to include('id="concealed-target"', 'id="display-none-target"')
    end
  end

  it 'keeps complete target-like source markup inside a literal program' do
    program = "<span id=\"literal-marker\"></span>\nkeep_source_exact()"
    observe_target("<pre><code class=\"language-html\">#{CGI.escapeHTML(program)}</code></pre>") do |native, markdown|
      expect(native.css('pre').map(&:text)).to include(program)
      expect(native.css('span#literal-marker')).to be_empty
      expect(markdown).to include("```\n#{program}\n```")
    end
  end

  it 'retains open disclosure declarations while excluding closed disclosure bodies' do
    content = '<details><summary>Closed methods</summary><p><span id="closed-methods"></span>Closed body.</p></details>' \
      '<details open><summary>Open methods</summary><p><span id="open-methods"></span>Open body.</p></details>'
    observe_target(content) do |_native, markdown|
      expect(markdown).to include('<span id="open-methods"></span>', 'Open body.')
      expect(markdown).not_to include('id="closed-methods"', 'Closed body.')
    end
  end
end
