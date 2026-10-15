# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Disposable extraction clone cleanup' do
  include_context 'extractor integration helpers'

  def disposable_clone_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.disposableCloneProbe = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'cleans every section, reference and program without another deep working copy' do
    sections = (1..240).map do |number|
      "<section><h2>Reference section #{number}</h2><p>Published explanation #{number} " \
        "with <a href='/reference/#{number}'>complete reference #{number}</a>.</p>" \
        "<pre><code>example_#{number}(&lt;Type&gt;);</code></pre>" \
        "<table><tr><th>Field #{number}</th><td>Complete value #{number}</td></tr></table></section>"
    end.join
    html = "<article id='source'><h1>Reference Manual</h1>#{sections}" \
           '<form><input name="email"><button>Subscribe</button></form></article>'
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: disposable_clone_probe(<<~JS))
        var source = document.querySelector('#source');
        var expected = cleanClone(visibilityPrunedClone(source));
        var owned = visibilityPrunedClone(source);
        var original = Node.prototype.cloneNode, deepCopies = 0, actual;
        Node.prototype.cloneNode = function(deep) {
          if (deep) deepCopies++;
          return original.apply(this, arguments);
        };
        try { actual = cleanDisposableClone(owned); }
        finally { Node.prototype.cloneNode = original; }
        return {expected: expected.outerHTML, actual: actual.outerHTML, reused: actual === owned,
          deepCopies: deepCopies, sections: actual.querySelectorAll('section').length,
          resources: actual.querySelectorAll('a[href]').length, programs: actual.querySelectorAll('pre').length,
          last: actual.querySelectorAll('pre')[239].textContent};
      JS
      result = page.evaluate('disposableCloneProbe({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result).to include('reused' => true, 'deepCopies' => 0, 'sections' => 240,
                                'resources' => 240, 'programs' => 240, 'last' => 'example_240(<Type>);')
      expect(result.fetch('actual')).not_to include('<form', '<input', '<button')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'copies physical, live-document and still-aliased roots instead of consuming them' do
    with_url_page('https://publication.example.test/reference/manual', '<article id="source"><p>Published material</p><button>Subscribe</button></article>') do |page|
      before = page.evaluate('document.body.innerHTML')
      page.evaluate("window.detachedSource = document.createElement('article'); window.detachedSource.innerHTML = '<p>Detached source</p><button>Subscribe</button>'")
      page.add_script_tag(content: disposable_clone_probe(<<~JS))
        var inert = document.implementation.createHTMLDocument('');
        var parent = inert.createElement('div');
        parent.innerHTML = '<article><p>Aliased material</p><button>Subscribe</button></article><p>Sibling material</p>';
        var inputs = [document.querySelector('#source'), window.detachedSource, parent.firstChild];
        var before = inputs.map(function(node) { return node.outerHTML; });
        var outputs = inputs.map(function(node) { return cleanDisposableClone(node); });
        return {copies: outputs.map(function(node, index) { return node !== inputs[index]; }),
          unchanged: inputs.map(function(node, index) { return node.outerHTML === before[index]; }),
          cleaned: outputs.every(function(node) { return !node.querySelector('button'); }),
          sibling: parent.lastChild.textContent};
      JS
      expect(page.evaluate('disposableCloneProbe({})')).to eq(
        'copies' => [true, true, true], 'unchanged' => [true, true, true],
        'cleaned' => true, 'sibling' => 'Sibling material'
      )
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
