# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Disposable Markdown roots' do
  include_context 'extractor integration helpers'

  def disposable_markdown_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.disposableMarkdownProbe = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'keeps complete public HTML while consuming only an owned conversion tree' do
    with_url_page('https://publication.example.test/reference/manual',
                  '<article id="source"><h1>Reference Manual</h1>' \
                  '<p>Published <em>explanation</em> with <a href="/reference">a complete reference</a>.</p>' \
                  '<pre><code>Root&lt;Value&gt;</code></pre><table><tr><th>Field</th><td>Complete value</td></tr></table></article>') do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: disposable_markdown_probe(<<~JS))
        var html = document.querySelector('#source').outerHTML;
        var expected = markdownFor(html, false, true, true);
        var owner = document.implementation.createHTMLDocument('');
        var owned = owner.createElement('div'); owned.innerHTML = html;
        var publicHtml = owned.innerHTML;
        var sameRoot = false;
        function convert(service, root) {
          sameRoot = root === owned;
          return turndownBlockUnits(service, root);
        }
        var actual = markdownFromDisposableRoot(owned, false, true, true, convert);
        return {actual: actual, expected: expected, sameRoot: sameRoot,
          publicHtml: publicHtml, expectedHtml: html, remaining: owned.childNodes.length};
      JS
      result = page.evaluate('disposableMarkdownProbe({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('publicHtml')).to eq(result.fetch('expectedHtml'))
      expect(result).to include('sameRoot' => true, 'remaining' => 0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'copies live or aliased conversion containers and leaves their owners intact' do
    with_url_page('https://publication.example.test/reference/manual',
                  '<div id="source"><p>Published <span>material</span> and <code>literal</code>.</p></div>') do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: disposable_markdown_probe(<<~JS))
        var owner = document.implementation.createHTMLDocument('');
        var parent = owner.createElement('div'); parent.innerHTML = '<div><p>Aliased material</p></div><p>Complete sibling</p>';
        var liveOwner = Document.prototype.createElement.call(document, 'div');
        liveOwner.innerHTML = '<p>Detached live-document material</p>';
        var inputs = [document.querySelector('#source'), liveOwner, parent.firstChild];
        var before = inputs.map(function(node) { return node.outerHTML; });
        var reused = [];
        var actual = inputs.map(function(node) {
          return markdownFromDisposableRoot(node, false, true, true, function(service, root) {
            reused.push(root === node); return turndownBlockUnits(service, root);
          });
        });
        return {reused: reused, unchanged: inputs.map(function(node, index) { return node.outerHTML === before[index]; }),
          actual: actual, sibling: parent.lastChild.textContent};
      JS
      result = page.evaluate('disposableMarkdownProbe({})')
      expect(result).to include('reused' => [false, false, false], 'unchanged' => [true, true, true], 'sibling' => 'Complete sibling')
      expect(result.fetch('actual').first).to include('Published material', '`literal`')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
