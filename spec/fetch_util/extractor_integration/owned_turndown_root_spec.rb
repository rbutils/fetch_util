# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Owned Turndown input' do
  include_context 'extractor integration helpers'

  it 'uses the same vendor rules while preserving ordinary, live and aliased inputs' do
    with_url_page('https://publication.example.test/manual', '<main id="caller"><p>Unchanged <em>published text</em>.</p></main>') do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      result = page.evaluate(<<~'JS')
        (() => {
          var service = new TurndownService({headingStyle: 'atx', codeBlockStyle: 'fenced'});
          var inert = document.implementation.createHTMLDocument('');
          var holder = inert.createElement('div');
          holder.innerHTML = '<h2>Complete heading</h2><p>  Published <em>emphasis</em> ' +
            '<a href="https://publication.example.test/reference">reference</a>.</p>' +
            '<pre><code>first\n&lt;Type&gt;\nlast</code></pre><ol start="7"><li>Ordered item</li></ol>';
          var fragment = inert.createDocumentFragment();
          while (holder.firstChild) fragment.appendChild(holder.firstChild);
          var nativeClone = fragment.cloneNode, copies = 0;
          var countingClone = function(deep) { copies++; return nativeClone.call(this, deep); };
          fragment.cloneNode = countingClone;
          var expected = service.turndown(fragment), ordinaryCopies = copies;
          copies = 0;
          var actual = service.turndownOwnedRoot(fragment), ownedCopies = copies;
          var physical = document.querySelector('#caller');
          var physicalBefore = physical.outerHTML;
          var physicalEqual = service.turndownOwnedRoot(physical) === service.turndown(physical);
          var liveFragment = document.createDocumentFragment();
          liveFragment.appendChild(document.createElement('p')).textContent = '  Live fragment  ';
          var liveBefore = liveFragment.firstChild.outerHTML;
          service.turndownOwnedRoot(liveFragment);
          holder.innerHTML = '<p>  Still owned by its inert parent  </p>';
          var alias = holder.firstChild, aliasBefore = alias.outerHTML;
          service.turndownOwnedRoot(alias);
          return {expected: expected, actual: actual, ordinaryCopies: ordinaryCopies, ownedCopies: ownedCopies,
            ownMethodUnchanged: fragment.cloneNode === countingClone, physicalEqual: physicalEqual,
            physicalUnchanged: physical.outerHTML === physicalBefore,
            liveUnchanged: liveFragment.firstChild.outerHTML === liveBefore,
            aliasUnchanged: alias.parentNode === holder && alias.outerHTML === aliasBefore};
        })()
      JS
      expect(result.fetch('actual')).to eq(result.fetch('expected'))
      expect(result.fetch('actual')).to include('Complete heading', 'https://publication.example.test/reference', '<Type>', 'last', '7.  Ordered item')
      expect(result.fetch('ordinaryCopies')).to eq(1)
      expect(result.fetch('ownedCopies')).to eq(0)
      %w[ownMethodUnchanged physicalEqual physicalUnchanged liveUnchanged aliasUnchanged].each do |key|
        expect(result.fetch(key)).to be(true), key
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'leaves ordinary conversion and DOM methods intact when a configured rule raises' do
    with_url_page('https://publication.example.test/manual', '<p>Unchanged source</p>') do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      result = page.evaluate(<<~'JS')
        (() => {
          var service = new TurndownService(), nativeClone = Node.prototype.cloneNode;
          var inert = document.implementation.createHTMLDocument(''), root = inert.createElement('div');
          root.innerHTML = '<p>  Published paragraph  </p>';
          var ordinaryBefore = root.innerHTML, messages = [];
          service.addRule('throwingParagraph', {filter: 'p', replacement: function() { throw new Error('rule failure'); }});
          try { service.turndown(root); } catch(error) { messages.push(error.message); }
          var ordinaryUnchanged = root.innerHTML === ordinaryBefore;
          try { service.turndownOwnedRoot(root); } catch(error) { messages.push(error.message); }
          return {messages: messages, ordinaryUnchanged: ordinaryUnchanged,
            prototypeUnchanged: Node.prototype.cloneNode === nativeClone,
            noOwnMethod: !Object.prototype.hasOwnProperty.call(root, 'cloneNode')};
        })()
      JS
      expect(result.fetch('messages')).to eq(['rule failure', 'rule failure'])
      expect(result.values_at('ordinaryUnchanged', 'prototypeUnchanged', 'noOwnMethod')).to eq([true, true, true])
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
