# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Immutable manual visibility reads' do
  include_context 'extractor integration helpers'

  def indexed_manual_probe(body)
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', "window.readIndexedManual = withComposedDomRead(function(options) { #{body} }); })(window);")
  end

  it 'keeps all source material and actual visibility while reading each physical style once' do
    programs = (1..240).map do |number|
      "<section><h2>Published section #{number}</h2><p>Complete explanation #{number}.</p>" \
        "<pre><span>published_example_#{number}();</span></pre></section>"
    end.join
    html = "<article id='source'>#{programs}<p hidden>Private example</p>" \
           "<pre><a href='/reference'>Authored code reference</a></pre>" \
           "<section style='visibility:hidden'>Private text<a style='visibility:visible' href='/visible'>Visible override</a></section></article>"
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: indexed_manual_probe(<<~JS))
        var root = document.querySelector('#source');
        function rendered(clone) {
          var shell = document.createElement('div'); shell.appendChild(clone);
          var clean = cleanClone(shell); cleanupAgentRoot(clean); materializeHttpAttributes(clean, false, false);
          return {html: clean.innerHTML, markdown: markdownFor(clean.innerHTML, false, true, true).trim()};
        }
        var expected = rendered(visibilityPrunedClone(root, document));
        var original = window.getComputedStyle, calls = 0, programChildReads = 0, transformReads = 0;
        var childNodes = Object.getOwnPropertyDescriptor(Node.prototype, 'childNodes');
        Object.defineProperty(Node.prototype, 'childNodes', {configurable: true, get: function() {
          if (this.ownerDocument === document && this.isConnected && this.localName === 'span' && this.closest('pre')) programChildReads++;
          return childNodes.get.call(this);
        }});
        window.getComputedStyle = function(node) {
          if (node.ownerDocument === document && node.isConnected) calls++;
          var computed = original.apply(window, arguments);
          return new Proxy(computed, {get: function(target, property) {
            if (property === 'transform' && root.contains(node)) transformReads++;
            var value = Reflect.get(target, property, target);
            return typeof value === 'function' ? value.bind(target) : value;
          }});
        };
        try {
          var clone = physicalManualVisibilityClone(root);
          var cloneReads = calls, cloneTransformReads = transformReads;
          var actual = rendered(clone);
          return {actual: actual, expected: expected, calls: cloneReads, nodes: root.querySelectorAll('*').length + 1,
            programChildReads: programChildReads, transformReads: cloneTransformReads};
        } finally { window.getComputedStyle = original; Object.defineProperty(Node.prototype, 'childNodes', childNodes); }
      JS
      result = page.evaluate('readIndexedManual({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('calls')).to be <= result.fetch('nodes') + 8
      expect(result.fetch('programChildReads')).to eq(0)
      expect(result.fetch('transformReads')).to eq(0)
      expect(result.fetch('actual').fetch('markdown')).to include('published_example_240();', 'Visible override', 'Authored code reference')
      expect(result.fetch('actual').fetch('markdown')).not_to include('Private example', 'Private text')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains the transform proof needed by opacity-zero deferred reporting collections' do
    html = '<main id="source"><section style="opacity:0;will-change:transform;transform:translateY(12px)">' \
           '<article><h2>First published record</h2><p>Complete first description.</p><a href="/first">First reference</a></article>' \
           '<article><h2>Second published record</h2><p>Complete second description.</p><a href="/second">Second reference</a></article>' \
           '</section></main>'
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: indexed_manual_probe(<<~JS))
        var root = document.querySelector('#source');
        var expected = visibilityPrunedClone(root, document).outerHTML;
        var actual = physicalManualVisibilityClone(root).outerHTML;
        return {expected: expected, actual: actual};
      JS
      result = page.evaluate('readIndexedManual({})')
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('actual')).to include('First published record', 'Second published record', '/first', '/second')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'restores nested and exceptional reads and observes subsequent source changes' do
    with_url_page('https://publication.example.test/reference/manual',
                  '<article id="first"><p>First owner</p></article><article id="second"><p>Second owner</p></article>') do |page|
      page.add_script_tag(content: indexed_manual_probe(<<~JS))
        var first = document.querySelector('#first'), second = document.querySelector('#second');
        var nested = withIndexedPhysicalVisibility(first, function() {
          var inner = withIndexedPhysicalVisibility(second, function() { return visibilityPrunedClone(second).textContent; });
          return inner + ' / ' + visibilityPrunedClone(first).textContent;
        });
        try { withIndexedPhysicalVisibility(first, function() { throw new Error('read interrupted'); }); } catch (error) {}
        first.querySelector('p').hidden = true;
        var hidden = physicalManualVisibilityClone(first).textContent;
        first.querySelector('p').hidden = false;
        return {nested: nested, hidden: hidden, visible: physicalManualVisibilityClone(first).textContent};
      JS
      expect(page.evaluate('readIndexedManual({})')).to eq('nested' => 'Second owner / First owner', 'hidden' => '', 'visible' => 'First owner')
    end
  end

  it 'does not resolve styles or construct descendants beneath a physically hidden owner' do
    programs = (1..240).map { |number| "<pre><span>private_example_#{number}();</span></pre>" }.join
    html = "<article id='source'><h2>Published section</h2><p>Complete published explanation.</p>" \
           "<div hidden id='private'>#{programs}</div><pre><span>published_program();</span></pre></article>"
    with_url_page('https://publication.example.test/reference/manual', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: indexed_manual_probe(<<~JS))
        var root = document.querySelector('#source'), hidden = document.querySelector('#private');
        var style = window.getComputedStyle, clone = Node.prototype.cloneNode;
        var hiddenStyles = 0, hiddenCopies = 0;
        window.getComputedStyle = function(node) {
          if (node !== hidden && hidden.contains(node)) hiddenStyles++;
          return style.apply(window, arguments);
        };
        Node.prototype.cloneNode = function(deep) {
          if (this !== hidden && hidden.contains(this)) hiddenCopies++;
          return clone.call(this, deep);
        };
        try {
          var copy = physicalManualVisibilityClone(root);
          return {html: copy.outerHTML, hiddenStyles: hiddenStyles, hiddenCopies: hiddenCopies};
        } finally { window.getComputedStyle = style; Node.prototype.cloneNode = clone; }
      JS
      result = page.evaluate('readIndexedManual({})')
      expect(result.fetch('hiddenStyles')).to eq(0)
      expect(result.fetch('hiddenCopies')).to eq(0)
      expect(result.fetch('html')).to include('Complete published explanation.', 'published_program();')
      expect(result.fetch('html')).not_to include('private_example_')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps composed and mutable bridge readers on their fresh ordinary path' do
    with_url_page('https://publication.example.test/reference/manual', '<div id="host"></div><article id="source"><p>Complete physical record</p></article>') do |page|
      page.evaluate(<<~JS)
        (() => {
          document.querySelector('#host').attachShadow({mode: 'open'}).innerHTML = '<article><p>Complete component record</p></article>';
          window.bridgeReads = 0;
          Object.defineProperty(window, 'mutableManualReader', {configurable: true, get() {
            window.bridgeReads++; return function() { return null; };
          }});
        })()
      JS
      page.add_script_tag(content: indexed_manual_probe(<<~JS))
        var shadow = document.querySelector('#host').shadowRoot.querySelector('article');
        return {component: physicalManualVisibilityClone(shadow).textContent,
          physical: physicalManualVisibilityClone(document.querySelector('#source')).textContent, reads: window.bridgeReads};
      JS
      result = page.evaluate('readIndexedManual({shadow_root_reader_property: "mutableManualReader", shadow_root_token: "source"})')
      expect(result.fetch('component')).to eq('Complete component record')
      expect(result.fetch('physical')).to eq('Complete physical record')
      expect(result.fetch('reads')).to be_positive
    end
  end
end
