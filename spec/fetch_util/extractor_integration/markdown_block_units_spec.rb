# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Complete Markdown block conversion' do
  include_context 'extractor integration helpers'

  def markdown_block_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.markdownBlockProbe = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'matches complete ordinary conversion without copying the disposable units' do
    sections = (1..240).map do |number|
      "<section><h2>Published section #{number}</h2><p>Every explanation #{number} " \
        "with <em>authored emphasis</em> and <a href='/reference/#{number}'>reference #{number}</a>.</p>" \
        "<pre><code class='language-cpp'>example_#{number}(&lt;Type&gt;);</code></pre>" \
        "<table><tr><th>Field #{number}</th><td><code>Value&lt;#{number}&gt;</code></td></tr></table></section>"
    end.join
    with_url_page('https://publication.example.test/reference/manual', "<article id='source'><h1>Reference Manual</h1>#{sections}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: markdown_block_probe(<<~JS))
        var html = document.querySelector('#source').outerHTML;
        var expected = markdownFor(html, false, true, true);
        var largestClone = 0, conversions = 0, fragmentCopies = 0;
        function convert(service, root) {
          var method = typeof service.turndownOwnedRoot === 'function' ? 'turndownOwnedRoot' : 'turndown';
          var original = service[method], nativeClone = Node.prototype.cloneNode;
          service[method] = function(unit) {
            conversions++;
            largestClone = Math.max(largestClone, unit.querySelectorAll('*').length);
            return original.call(this, unit);
          };
          Node.prototype.cloneNode = function(deep) {
            if (deep && this.nodeType === 11) fragmentCopies++;
            return nativeClone.call(this, deep);
          };
          try { return turndownBlockUnits(service, root); }
          finally { Node.prototype.cloneNode = nativeClone; }
        }
        function legacyConvert(service, root) {
          service.turndownOwnedRoot = undefined;
          return turndownBlockUnits(service, root);
        }
        return {expected: expected, actual: markdownFor(html, false, true, true, convert),
          legacy: markdownFor(html, false, true, true, legacyConvert),
          largestClone: largestClone, conversions: conversions, fragmentCopies: fragmentCopies};
      JS
      result = page.evaluate('markdownBlockProbe({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('legacy')).to eq(result.fetch('expected'))
      expect(result.fetch('actual')).to include('Published section 240', 'example_240(<Type>);', 'reference/240')
      expect(result.fetch('conversions')).to be >= 240
      expect(result.fetch('largestClone')).to be < 20
      expect(result.fetch('fragmentCopies')).to eq(0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps mixed inline runs, nested semantic blocks, tables, fields and references identical' do
    with_url_page('https://publication.example.test/reference/manual', '<p>Unchanged physical source</p>') do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: markdown_block_probe(<<~'JS'))
        var examples = [
          '<article> Before <em>inline</em> text. <section><h2>Heading</h2>After <strong>bold</strong> text.</section> Tail.</article>',
          '<div>alpha<span>joined</span><br>continued <code>token</code> end</div><p>Next paragraph.</p>',
          '<div>first<div></div>second<section>third</section>fourth</div>',
          '<section><ol start="7"><li>First item<ol><li>Nested item</li></ol></li><li>Second item</li></ol><p>After list.</p></section>',
          '<blockquote><p>Published quote</p><section><p>Quoted continuation</p></section></blockquote><p>After quote.</p>',
          '<div><p>Before</p><div data-fetch-util-structured-card-field="true"><p>Complete field</p><p>Repeated field</p></div><p>After</p></div>',
          '<section><table><caption>Field values</caption><tr><th>Type</th><td><pre>Root&lt;Branch&gt;</pre><a href="/reference">Reference</a></td></tr></table></section>',
          '<p>Footnote <a href="#note">1</a>.</p><ol><li id="note">Published note <a href="#return">Return</a>.</li></ol>',
          '<article><p>Repeated authored passage.</p><p>Repeated authored passage.</p><hr><p>Final passage.</p></article>',
          '<main>Inline prefix<section><h2>Heading</h2><p>Complete body</p></section>Inline suffix</main>',
          '<figure><img src="/illustration.png" alt="Authored illustration"><figcaption>Complete caption.</figcaption></figure>',
          '<section><pre><code class="language-text">literal ``` delimiter\n&lt;Template&gt;\n</code></pre><dl><dt>Term</dt><dd>Definition <a href="/field">Field</a></dd></dl></section>'
        ];
        return examples.map(function(html) {
          return {html: html, expected: markdownFor(html, false, true, true),
            actual: markdownFor(html, false, true, true, turndownBlockUnits)};
        });
      JS
      page.evaluate('markdownBlockProbe({})').each do |result|
        expect(result.fetch('actual')).to eq(result.fetch('expected')), result.fetch('html')
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
