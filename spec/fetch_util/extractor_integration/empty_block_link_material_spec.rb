# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'nokogiri'
require 'support/extractor_integration_helpers'

RSpec.describe 'Readable destinations in complete block material' do
  include_context 'extractor integration helpers'

  def with_empty_block_references(extra = '', documentation: false)
    html = <<~HTML
      <html><head><title>Published reference resources</title></head><body><main>
        <h1>Published reference resources</h1>
        <p>Each resource is independently published in the following physical order.</p>
        <div id="peer-group">
          <a href="https://reference.example.test/first"><div style="width:100px;height:40px;background:#eef"></div></a>
          <a href="https://reference.example.test/first"><div style="width:100px;height:40px;background:#efe"></div></a>
          <a href="https://reference.example.test/named"><div>Named reference</div></a>
          <a id="selected-reference" href="/training"><div>Published training resource</div></a>
          <a hidden href="/hidden-reference"><div>Hidden resource</div></a>
        </div>
        #{extra}
      </main></body></html>
    HTML
    if documentation
      html = html.sub('<head>', '<head><meta name="generator" content="mkdocs-1.6.1, mkdocs-material-9.7.1">')
                 .sub('<main>', '<main><article class="md-content__inner md-typeset">')
                 .sub('</main>', '</article></main>')
    end
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')
      payload = extract_payload(page)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = payload.fetch('markdown')
      rendered = Nokogiri::HTML5.fragment(markdown)
      expect(payload.fetch('title')).to eq('Published reference resources')
      expect(native.css('a[href="https://reference.example.test/first"]').length).to eq(2)
      expect(markdown).not_to include('Hidden resource', '/hidden-reference')
      expect(page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')).to eq(before)
      yield native, rendered, markdown
      expect(page.evaluate('({html: document.body.innerHTML, text: document.body.innerText})')).to eq(before)
    end
  end

  it 'retains a readable URL for each independent equal-destination empty block' do
    with_empty_block_references do |native, rendered, _markdown|
      destination = 'https://reference.example.test/first'
      expect(native.css('a').select { |link| link['href'] == destination }.map { |link| link.text.strip }).to eq(['', ''])
      links = rendered.css('a').select { |link| link['href'] == destination }
      expect(links.map { |link| link.text.strip }).to eq([destination, destination])
      expect(rendered.css('a').map { |link| link['href'] }).to eq(
        [destination, destination, 'https://reference.example.test/named', 'https://publication.example.test/training']
      )
    end
  end

  it 'uses a declared title without changing its complete query or fragment' do
    destination = 'https://reference.example.test/title?word=%5Bfull%5D&other=2#exact'
    label = 'Display [reference] & more'
    extra = '<a id="titled-reference" data-record="independent" ' \
      "href=\"#{CGI.escapeHTML(destination)}\" title=\"#{CGI.escapeHTML(label)}\"><p></p></a>"
    with_empty_block_references(extra) do |native, rendered, _markdown|
      expect(native.at_css('#titled-reference').text.strip).to eq('')
      link = rendered.at_css('#titled-reference')
      expect([link['href'], link['title'], link['data-record'], link.text.strip]).to eq(
        [destination, label, 'independent', label]
      )
    end
  end

  it 'preserves an accessible label without appending an unrelated fallback URL' do
    extra = '<a id="accessible-reference" href="/accessible?mode=complete#record" ' \
      'aria-label="Complete accessible reference"><div></div></a>'
    with_empty_block_references(extra) do |_native, rendered, _markdown|
      link = rendered.at_css('#accessible-reference')
      expect(link['href']).to eq('https://publication.example.test/accessible?mode=complete#record')
      expect(link['aria-label']).to eq('Complete accessible reference')
      expect(link.text.strip).to eq('Complete accessible reference')
    end
  end

  it 'retains image-only material without inventing another text label' do
    extra = '<a id="image-reference" href="/image-record?mode=full#record" title="Image title"><figure>' \
      '<img src="https://images.example.test/record.png?size=large#preview" alt="Independent image record"></figure></a>'
    with_empty_block_references(extra) do |native, rendered, _markdown|
      original = native.at_css('#image-reference')
      link = rendered.at_css('#image-reference')
      expect(link['href']).to eq('https://publication.example.test/image-record?mode=full#record')
      expect(link.text.strip).to eq('')
      expect(link.css('img').map { |image| [image['src'], image['alt']] }).to eq(
        original.css('img').map { |image| [image['src'], image['alt']] }
      )
      expect(link.css('img').length).to eq(1)
    end
  end

  it 'retains readable empty destinations inside a complete mixed-role table' do
    destination = 'https://reference.example.test/table?mode=full#record'
    extra = '<table><tbody><tr><th scope="row">Complete resource</th><td>' \
      "<a id=\"table-reference\" href=\"#{destination}\"><div></div></a></td></tr></tbody></table>"
    with_empty_block_references(extra, documentation: true) do |native, rendered, _markdown|
      expect(native.css('table tr').map { |row| row.element_children.map(&:name) }).to eq([%w[th td]])
      expect(rendered.css('table tr').map { |row| row.element_children.map(&:name) }).to eq([%w[th td]])
      link = rendered.at_css('#table-reference')
      expect([link['href'], link.text.strip]).to eq([destination, destination])
      expect(rendered.at_css('th')['scope']).to eq('row')
    end
  end

  it 'keeps literal programs, closed resources and unique heading self controls separate' do
    program = "first_call('<a href=\"https://literal.example.test/resource\"><div></div></a>');\n\nlast_call();"
    extra = '<h2 id="exact-method"><a href="#exact-method"><div></div></a>Complete method</h2>' \
      "<pre><code>#{CGI.escapeHTML(program)}</code></pre>" \
      '<details><summary>Optional resources</summary>' \
      '<a href="https://private.example.test/closed"><div></div></a></details>'
    with_empty_block_references(extra) do |native, rendered, markdown|
      expect(native.css('pre').map(&:text)).to eq([program])
      expect(markdown).to include(program, '```', 'Complete method', 'Optional resources')
      expect(markdown).not_to include('https://private.example.test/closed')
      expect(rendered.css('a').map { |link| link['href'] }).not_to include('https://publication.example.test/#exact-method')
      expect(markdown.scan('https://literal.example.test/resource').length).to eq(1)
    end
  end
end
