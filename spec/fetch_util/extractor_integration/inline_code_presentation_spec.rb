# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Complete inline code presentation' do
  include_context 'extractor integration helpers'

  def inline_presentation_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.inlinePresentationProbe = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'retains all literal tokens while omitting presentation descendants from Markdown work' do
    programs = (1..240).map do |number|
      "<p>Published literal #{number}: <code><span class='type'>Root</span><span class='punctuation'>&lt;</span>" \
        "<span class='value'>Value#{number}</span><span class='punctuation'>&gt;</span></code> " \
        "and <a href='/reference/#{number}'>reference #{number}</a>.</p>"
    end.join
    with_url_page('https://publication.example.test/reference/manual', "<article id='source'>#{programs}</article>") do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: inline_presentation_probe(<<~JS))
        var source = document.querySelector('#source');
        var plain = source.cloneNode(true);
        plain.querySelectorAll('code').forEach(function(code) { code.textContent = code.textContent; });
        var expected = markdownFor(plain.outerHTML, false, true, true);
        var spansAtConversion = -1;
        function convert(service, root) {
          spansAtConversion = root.querySelectorAll('code span').length;
          return service.turndown(root);
        }
        var actual = markdownFor(source.outerHTML, false, true, true, convert);
        return {actual: actual, expected: expected, spansAtConversion: spansAtConversion};
      JS
      result = page.evaluate('inlinePresentationProbe({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('actual')).to include('`Root<Value240>`', 'reference/240')
      expect(result.fetch('spansAtConversion')).to eq(0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains attributed descendants, literal references and named destinations' do
    html = '<p><code><span id="target">Identified token</span></code> ' \
           '<code><span title="Published annotation">Annotated token</span></code> ' \
           '<code><span role="term">Semantic token</span></code> ' \
           '<code><a href="/reference">Published reference</a></code> ' \
           '<code><span data-unit="quantity">Attributed token</span></code></p>'
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: inline_presentation_probe(<<~JS))
        var root = document.createElement('div'); root.innerHTML = document.body.innerHTML;
        preserveLiteralInlineCode(root);
        return {identified: !!root.querySelector('code span#target'), annotated: !!root.querySelector('code span[title]'),
          semantic: !!root.querySelector('code span[role]'), reference: !!root.querySelector('code a[href]'),
          attributed: !!root.querySelector('code span[data-unit]')};
      JS
      expect(page.evaluate('inlinePresentationProbe({})').values).to eq([true, true, true, true, true])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains all nested and adjacent literal values, angle text and linked code' do
    html = (1..160).map do |number|
      <<~HTML
        <p>Literal #{number}: <a name="value#{number}"><code>MODE_<code>VALUE#{number}</code></code></a>
        <code class="one">config</code><code class="two">['ENV']</code><code>['PATH#{number}']</code>
        <code>matrix</code><code>&lt;Value#{number}&gt;</code>
        and <a href="/reference/#{number}"><code>reference#{number}</code></a>.</p>
      HTML
    end.join
    html << '<p>Keep Root&gt;Branch&gt;Leaf and &lt;LiteralType&gt; as authored text.</p>'
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: inline_presentation_probe('return markdownFor(document.body.innerHTML, false, true, true);'))
      markdown = page.evaluate('inlinePresentationProbe({})')
      (1..160).each do |number|
        expect(markdown).to include("`MODE_VALUE#{number}`", "`config['ENV']['PATH#{number}']`", "`matrix<Value#{number}>`")
        expect(markdown).to include("reference/#{number}")
      end
      expect(markdown).to include('Root>Branch>Leaf', '\<LiteralType>')
      expect(markdown).not_to include('Root\>Branch')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains all literal table programs and backticks without swallowing real references or images' do
    rows = (1..160).map do |number|
      <<~HTML
        <tr><td><code>Vector&lt;Value#{number}&gt;</code></td><td><pre>fn&lt;T&gt;(row#{number});</pre></td>
        <td><code>&#96;edge#{number}&#96;</code></td></tr>
      HTML
    end.join
    html = '<table><tr><th>Literal</th><th>Program</th><th>Edge</th></tr>' \
           "#{rows}<tr><td><code><a href='/field'>Published field</a></code></td>" \
           '<td><code><img src="/diagram.svg" alt="Published diagram"></code></td><td>Complete</td></tr></table>'
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: inline_presentation_probe('return markdownFor(document.body.innerHTML, false, true, true);'))
      markdown = page.evaluate('inlinePresentationProbe({})')
      (1..160).each do |number|
        expect(markdown).to include("`Vector<Value#{number}>`", "`fn<T>(row#{number});`", "`` `edge#{number}` ``")
      end
      expect(markdown).to include('https://publication.example.test/field', 'https://publication.example.test/diagram.svg')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
