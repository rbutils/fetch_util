# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Physical unlabeled reference peers' do
  include_context 'extractor integration helpers'

  def peer_reference_markdown(page, structured: false)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |line|
      line.empty? || line.start_with?('#')
    end
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    raise 'source-module test boundary changed' unless source.scan(outro).size == 1

    source = source.sub(outro, <<~JS)
      window.__peerReferenceMarkdown = function(structured) {
        var root = visibleListClone(document.body);
        var card = root.querySelector('#peer-group');
        var link = card.querySelector('#selected-reference');
        return listMarkdown([{sourceNode: link, card: card, url: link.href, text: link.textContent,
          sourceOrderedStructuredCard: structured}]);
      };
      })(window);
    JS
    inject_standalone_extractor(page)
    page.add_script_tag(content: source)
    page.evaluate("window.__peerReferenceMarkdown(#{structured})")
  end

  it 'retains independent unlabeled occurrences before a later selected reference' do
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
      </main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = peer_reference_markdown(page)
      first = '[https://reference.example.test/first](https://reference.example.test/first)'
      named = '[Named reference](https://reference.example.test/named)'
      selected = '[Published training resource](https://publication.example.test/training)'
      expect(markdown.scan(first).size).to eq(2)
      expect(markdown).to include(named, selected)
      expect(markdown.index(first)).to be < markdown.index(named)
      expect(markdown.index(named)).to be < markdown.index(selected)
      expect(markdown).not_to include('Hidden resource', '/hidden-reference')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves the complete inline formatting of named peers in their physical order' do
    html = <<~HTML
      <html><head><title>Formatted references</title></head><body><main>
        <div id="peer-group">
          <a href="/first"><span style="display:block;width:80px;height:30px;background:#eef"></span></a><a href="/named"><div><strong>Named resource</strong> with <em>authored emphasis</em></div></a>
          <a id="selected-reference" href="/selected">Selected reference</a>
        </div>
      </main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = peer_reference_markdown(page)
      first = '[https://publication.example.test/first](https://publication.example.test/first)'
      named = '[**Named resource** with _authored emphasis_](https://publication.example.test/named)'
      selected = '[Selected reference](https://publication.example.test/selected)'
      expect(markdown).to include(first, named, selected)
      expect(markdown.gsub(/[[:space:]]+/, ' ')).to include("#{first} #{named}")
      expect(markdown.index(first)).to be < markdown.index(named)
      expect(markdown.index(named)).to be < markdown.index(selected)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'preserves separately authored prose, program values and references around a selection' do
    html = <<~HTML
      <html><head><title>Authored material</title></head><body><main>
        <div id="peer-group">
          <p>Independently authored prose links to <a href="/prose">its own reference</a>.</p>
          <pre><code>printf 'peer - item\n'
      return '&lt;owner&gt;'</code></pre>
          <a href="/unlabeled"><span style="display:block;width:80px;height:30px;background:#eef"></span></a>
          <h2><a id="selected-reference" href="/selected">Selected reference</a></h2>
        </div>
      </main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      markdown = peer_reference_markdown(page, structured: true)
      expect(markdown).to include(
        'Independently authored prose links to',
        '[its own reference](https://publication.example.test/prose)',
        "printf 'peer - item\n'\nreturn '<owner>'",
        '[Selected reference](https://publication.example.test/selected)'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
