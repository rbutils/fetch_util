# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Disposable article ownership analysis' do
  include_context 'extractor integration helpers'

  def ownership_clone_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.ownershipCloneProbe = function(mode) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var source = document.querySelector('article'), before = source.outerHTML;
            function facts(root) {
              return {
                text: root.textContent,
                headings: Array.from(root.querySelectorAll('h1, h2, h3')).map(function(node) { return node.textContent; }),
                paragraphs: Array.from(root.querySelectorAll('p')).map(function(node) {
                  return [node.textContent, node.closest('article') === root];
                }),
                links: Array.from(root.querySelectorAll('a[href]')).map(function(node) {
                  return [node.getAttribute('href'), node.textContent, !!node.closest('p')];
                }),
                programs: Array.from(root.querySelectorAll('pre')).map(function(node) { return node.textContent; }),
                nestedArticles: root.querySelectorAll('article').length
              };
            }
            if (mode === 'compare') {
              var baseline = visibilityPrunedClone(source, document, new WeakMap());
              var ordinary = facts(baseline), ordinarySpans = baseline.querySelectorAll('span').length;
              baseline.replaceChildren();
              var clone = articleRouteOwnershipClone(source), projected = facts(clone);
              var projectedSpans = clone.querySelectorAll('span').length;
              clone.replaceChildren();
              var map = new WeakMap(), mapped = articleRouteOwnershipClone(source, map);
              var tokens = Array.from(source.querySelectorAll('span'));
              var mappedComplete = tokens.every(function(token) {
                return map.get(token) && map.get(token).textContent === token.textContent;
              });
              var mappedEqual = JSON.stringify(facts(mapped)) === JSON.stringify(ordinary);
              mapped.replaceChildren();
              return {equal: JSON.stringify(ordinary) === JSON.stringify(projected),
                mappedEqual: mappedEqual, mappedComplete: mappedComplete, ordinarySpans: ordinarySpans,
                projectedSpans: projectedSpans, paragraphs: ordinary.paragraphs.length,
                programs: ordinary.programs.length, links: ordinary.links.length, sourceUnchanged: source.outerHTML === before};
            }
            var original = articleRouteOwnershipClone, roots = [], caught = null;
            articleRouteOwnershipClone = function() {
              var clone = original.apply(null, arguments);
              roots.push(clone);
              if (mode === 'error') clone.querySelectorAll = function() { throw new Error('ownership probe failed'); };
              return clone;
            };
            try {
              var content = {contentType: 'article', title: document.title, html: source.outerHTML};
              var owns = articleRouteFocalContent(content);
              var owner = articleRouteFocalContent(content, true);
            } catch (error) {
              caught = error.message;
            } finally {
              articleRouteOwnershipClone = original;
            }
            return {owns: owns === true, sourceOwner: owner === source, error: caught,
              roots: roots.length, disposed: roots.every(function(root) { return !root.firstChild; }),
              sourceUnchanged: source.outerHTML === before};
          })({});
        })({});
      };
      })(window);
    JS
  end

  def complete_ownership_source
    sections = (1..240).map do |number|
      tokens = (1..5).map { |token| "<span class='token'>value_#{number}_#{token}; </span>" }.join
      "<section><h2>Complete section #{number}</h2><p>Published source explanation #{number} retains every authored detail, " \
        "ordered relationship and <a href='/record/#{number}'>reference #{number}</a> in this complete primary body.</p>" \
        "<pre><code>#{tokens}</code></pre></section>"
    end.join
    "<title>Complete technical reference</title><article role='main'><h1>Complete technical reference</h1>#{sections}</article>"
  end

  it 'preserves complete ordinary ownership evidence while avoiding pure presentation tokens' do
    with_url_page('https://publication.example.test/reference.html', complete_ownership_source) do |page|
      page.add_script_tag(content: ownership_clone_probe)
      expect(page.evaluate("ownershipCloneProbe('compare')")).to eq(
        'equal' => true, 'mappedEqual' => true, 'mappedComplete' => true, 'ordinarySpans' => 1200,
        'projectedSpans' => 0, 'paragraphs' => 240, 'programs' => 240, 'links' => 240, 'sourceUnchanged' => true
      )
    end
  end

  it 'retains line topology, named references, rich code and hidden descendant decisions' do
    html = <<~HTML
      <title>Complete technical reference</title><article role="main"><h1>Complete technical reference</h1>
      <p>Complete published explanation retains real references and code structure.</p>
      <pre><code><div>first_line</div><div>second_line</div></code></pre>
      <pre><code><span id="named-token">named_value</span><a href="/record">actual reference</a></code></pre>
      <pre><code><span style="display:none">hidden_value</span>public_value</code></pre>
      <pre><code><span role="note">authored annotation</span></code></pre>
      <div style="display:none"><pre><code>unpublished_value</code></pre></div>
      </article>
    HTML
    with_url_page('https://publication.example.test/reference.html', html) do |page|
      page.add_script_tag(content: ownership_clone_probe)
      result = page.evaluate("ownershipCloneProbe('compare')")
      expect(result).to include(
        'equal' => true, 'mappedEqual' => true, 'sourceUnchanged' => true,
        'ordinarySpans' => 2, 'projectedSpans' => 2, 'programs' => 4, 'links' => 1
      )
    end
  end

  it 'preserves presentation descendants for broad-route record-leaf ownership' do
    with_url_page('https://publication.example.test/category/reference/', complete_ownership_source) do |page|
      page.add_script_tag(content: ownership_clone_probe)
      result = page.evaluate("ownershipCloneProbe('compare')")
      expect(result).to include(
        'equal' => true, 'mappedEqual' => true, 'mappedComplete' => true, 'ordinarySpans' => 1200,
        'projectedSpans' => 1200, 'programs' => 240, 'links' => 240, 'sourceUnchanged' => true
      )
    end
  end

  it 'returns only primitive or physical-source results and disposes every transient analysis root' do
    with_url_page('https://publication.example.test/reference.html', complete_ownership_source) do |page|
      page.add_script_tag(content: ownership_clone_probe)
      result = page.evaluate("ownershipCloneProbe('ownership')")
      expect(result).to include(
        'owns' => true, 'sourceOwner' => true, 'error' => nil, 'disposed' => true, 'sourceUnchanged' => true
      )
      expect(result.fetch('roots')).to be >= 2
    end
  end

  it 'also releases a disposable ownership tree when an analysis fails' do
    with_url_page('https://publication.example.test/reference.html', complete_ownership_source) do |page|
      page.add_script_tag(content: ownership_clone_probe)
      result = page.evaluate("ownershipCloneProbe('error')")
      expect(result).to include('error' => 'ownership probe failed', 'disposed' => true, 'sourceUnchanged' => true)
      expect(result.fetch('roots')).to be >= 1
    end
  end
end
