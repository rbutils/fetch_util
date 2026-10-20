require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'nokogiri'
require 'uri'

RSpec.describe 'Physical linked program declarations' do
  include_context 'extractor integration helpers'

  def linked_program_page(wrapped:, dense:)
    types = dense ? %w[PublishedRegion PublishedRoute PublishedString] : %w[Region Route string]
    program = <<~HTML
      type Parcel struct {
        Origin <a href="/types/region/">#{types[0]}</a>
        Route  <a href="/types/route/">#{types[1]}</a>
        Label  <a href="https://language.example.test/string">#{types[2]}</a> // complete literal comment
      }
    HTML
    declarations = (1..5).map do |number|
      pre = "<pre>#{program.sub("Parcel", "Parcel#{number}")}</pre>"
      owner = wrapped ? "<div class=\"declaration-frame\">#{pre}</div>" : pre
      "<h2 id=\"parcel-#{number}\">type Parcel#{number}</h2>#{owner}"
    end.join
    methods = (1..8).map do |number|
      <<~HTML
        <h3 id="method-#{number}">func Parcel#{number}() string</h3>
        <pre>func Parcel#{number}() string</pre>
        <p>Parcel#{number} preserves the complete declared routing behavior and the independently published reference values.
        The original source description explains the input, returned value and every practical interpretation of the result.</p>
      HTML
    end.join
    <<~HTML
      <html><head><title>Parcel reference</title></head><body>
      <h1>Parcel reference</h1><p>This package reference publishes complete type declarations, literal programs and independently
      linked token definitions. Every declaration and method belongs to this same reference, in its physical source order.</p>
      #{declarations}#{methods}
      <nav><div><pre>type NAVIGATION_ONLY <a href="/navigation/">Navigation</a></pre></div></nav>
      <div hidden><pre>type HIDDEN_ONLY <a href="/hidden/">Hidden</a></pre></div>
      <details><summary>Closed example</summary><pre>type CLOSED_ONLY <a href="/closed/">Closed</a></pre></details>
      </body></html>
    HTML
  end

  [{ wrapped: true, dense: true }, { wrapped: false, dense: true }, { wrapped: true, dense: false }].each do |options|
    it "preserves complete declarations with #{options.inspect}" do
      html = linked_program_page(**options)
      source = Nokogiri::HTML5(html)
      source.css('nav, [hidden], details:not([open])').remove
      expected = source.css('pre').map { |node| node.text.sub(/\n\z/, '') }
      linked = source.css('pre').select { |node| node.at_css('a[href]') }
      expected_linked = linked.map { |node| node.text.sub(/\n\z/, '') }
      expected_references = linked.flat_map do |node|
        node.css('a[href]').map do |anchor|
          [anchor.text, URI.join('https://reference.publication.example.test/parcel/', anchor['href']).to_s]
        end
      end
      with_url_page('https://reference.publication.example.test/parcel/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        native = Nokogiri::HTML5(payload.fetch('html'))
        native.css('nav, details:not([open])').remove
        expect(native.css('pre').map { |node| node.text.sub(/\n\z/, '') }).to eq(expected)
        markdown_html = Nokogiri::HTML5.fragment(payload.fetch('markdown'))
        expect(markdown_html.css('pre').map { |node| node.text.sub(/\n\z/, '') }).to eq(expected_linked)
        expect(native.css('pre a[href]').map { |node| [node.text, node['href']] }).to eq(expected_references)
        expect(markdown_html.css('pre a[href]').map { |node| [node.text, node['href']] }).to eq(expected_references)
        source.css('pre').reject { |node| node.at_css('a[href]') }.each do |node|
          expect(payload.fetch('markdown')).to include(node.text.sub(/\n\z/, ''))
        end
        expect(payload.fetch('markdown')).not_to include('NAVIGATION_ONLY', 'HIDDEN_ONLY', 'CLOSED_ONLY')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end
end
