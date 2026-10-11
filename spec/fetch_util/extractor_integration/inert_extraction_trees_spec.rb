# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Inert extraction working trees' do
  include_context 'extractor integration helpers'

  it 'preserves a complete large collection without re-running page element constructors' do
    entries = (1..125).map do |index|
      <<~HTML
        <article><working-card><h2><a href="/record/#{index}">Independent published record #{index}</a></h2>
          <p>Observation #{index} retains its full source context, including the independent authored explanation.</p>
          <p>Supporting <a href="/reference/#{index}">reference #{index}</a> and <code>value_#{index}</code>.</p>
        </working-card></article>
      HTML
    end.join
    html = "<html><head><title>Complete publication collection</title></head><body><main><h1>Complete publication collection</h1>#{entries}</main></body></html>"
    with_url_page('https://publication.example.test/', html) do |page|
      page.evaluate(<<~JS)
        (function() {
        window.__workingConstructors = 0;
        customElements.define('working-card', class extends HTMLElement {
          constructor() { super(); window.__workingConstructors += 1; }
        });
        return window.__workingConstructors;
        })()
      JS
      before = page.evaluate('document.body.innerHTML')
      expect(page.evaluate('window.__workingConstructors')).to eq(125)

      result = extractor_for(false).extract(page)

      (1..125).each do |index|
        expect(result['markdown']).to include("Independent published record #{index}", "Observation #{index}", "value_#{index}")
        expect(result['html']).to include("https://publication.example.test/record/#{index}", "https://publication.example.test/reference/#{index}")
      end
      expect(page.evaluate('window.__workingConstructors')).to eq(125)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains structured article resources, code, table cells and reciprocal references' do
    html = <<~HTML
      <html><head><title>Independent source report</title><meta name="generator" content="Sphinx"></head>
      <body><main class="document"><article><h1>Independent source report</h1>
        <div class="article-body" itemprop="articleBody"><p>The report explains the independently published evidence and its complete authored context.</p>
          <p>Source annotation<a id="ref" href="#note">1</a> links to an authored <a href="/resource">resource</a>.</p>
          <pre><code>return source_value &lt; limit;</code></pre>
          <table><tr><th>Source</th><th>Value</th></tr><tr><td>Independent measurement</td><td>42</td></tr></table>
          <img src="/diagram.png" alt="Published diagram">
          <div role="doc-footnote"><p>Independent annotation<a id="note" href="#ref">↑</a></p></div>
        </div></article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      result = extract(page)

      expect(result['markdown']).to include('return source_value < limit;', 'Independent measurement', '42', 'Independent annotation')
      expect(result['html']).to include('https://publication.example.test/resource', 'https://publication.example.test/diagram.png', 'report#ref')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'restores native operations after an extraction error and accepts immutable page methods' do
    source = fixture_contents(File.expand_path('../../../websieve/core/dom/inert_work.js', __dir__))
    with_url_page('https://publication.example.test/report', '<html><body><p>Independent source</p></body></html>') do |page|
      page.evaluate("(function() { #{source}; window.__inertWork = withInertDomWork; return true; })()")
      result = page.evaluate(<<~JS)
        (function() {
          var create = document.createElement, clone = Node.prototype.cloneNode;
          var owned = Object.prototype.hasOwnProperty.call(document, 'createElement');
          var failure;
          try { window.__inertWork(function() { throw new Error('planned extraction failure'); })({}); }
          catch (error) { failure = error.message; }
          var restored = document.createElement === create && Node.prototype.cloneNode === clone &&
            Object.prototype.hasOwnProperty.call(document, 'createElement') === owned;
          Object.defineProperty(document, 'createElement', {value: create, configurable: false, writable: false});
          Object.defineProperty(Node.prototype, 'cloneNode', {value: clone, configurable: false, writable: false});
          var text = window.__inertWork(function() { return document.body.cloneNode(true).textContent; })({});
          return {failure: failure, restored: restored, text: text};
        })()
      JS
      expect(result).to eq('failure' => 'planned extraction failure', 'restored' => true, 'text' => 'Independent source')
    end
  end
end
