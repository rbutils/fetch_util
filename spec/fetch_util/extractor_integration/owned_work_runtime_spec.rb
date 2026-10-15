# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Owned extraction runtime', :integration do
  include_context 'extractor integration helpers'

  def owned_manual_html
    sections = (1..160).map do |index|
      <<~HTML
        <section><h2>Instruction #{index}</h2>
        <p>Authored explanation #{index} describes the complete instruction, its operands, observable effects,
        relationships and all relevant constraints in enough detail to form the technical manual's primary material.</p>
        <p><a href="/reference/#{index}">Reference #{index}</a> remains part of this complete explanation.</p>
        <pre><code class="language-text">instruction_#{index}(value)
        complete_example_#{index}</code></pre></section>
      HTML
    end.join
    <<~HTML
      <!doctype html><html lang="en"><head><title>Engine Reference Manual</title>
      <style>p { color: black; }</style></head><body><article role="main"><h1>Engine Reference Manual</h1>
      <p class="dynamic-sensitive">A visible paragraph whose rendering must be refreshed after a stylesheet mutation.</p>
      #{sections}</article></body></html>
    HTML
  end

  def owned_runtime_probe(page, body)
    extractor = FetchUtil::Extractor.new
    preparation = extractor.__send__(:owned_preparation_call)
    page.evaluate(<<~JS)
      (() => {
        const originalClone = Node.prototype.cloneNode;
        const originalCreate = document.createElement;
        const task = #{preparation};
        const preparedScopesRestored = Node.prototype.cloneNode === originalClone && document.createElement === originalCreate;
        #{body}
      })()
    JS
  end

  it 'matches the ordinary complete payload while collecting between restored extraction scopes' do
    with_url_page('https://reference.example.test/manual.html', owned_manual_html) do |page|
      inject_standalone_extractor(page)
      before = page.evaluate('document.body.innerHTML')
      ordinary = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      calls = []
      allow(page).to receive(:command).and_wrap_original do |original, method, **parameters|
        calls << method
        original.call(method, **parameters)
      end
      actual = FetchUtil::Extractor.new.extract(page)
      expect(actual).to eq(ordinary)
      expect(calls.count('HeapProfiler.collectGarbage')).to eq(1)
      expect(actual.fetch('html').scan('<pre').length).to eq(160)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'falls back to current complete source after a DOM mutation and consumes work only once' do
    with_url_page('https://reference.example.test/manual.html', owned_manual_html) do |page|
      inject_standalone_extractor(page)
      result = owned_runtime_probe(page, <<~JS)
        const owned = task.owned;
        const paragraph = document.createElement('p');
        paragraph.textContent = 'Newly published instruction material added after preparation must be included.';
        document.querySelector('article').appendChild(paragraph);
        const payload = task.finish();
        let repeatedError = false;
        try { task.finish(); } catch (error) { repeatedError = /already been consumed/.test(error.message); }
        return { owned, payload, preparedScopesRestored, repeatedError,
          finishedScopesRestored: Node.prototype.cloneNode === originalClone && document.createElement === originalCreate };
      JS
      expect(result).to include('owned' => true, 'preparedScopesRestored' => true, 'finishedScopesRestored' => true, 'repeatedError' => true)
      expect(result.fetch('payload').fetch('markdown')).to include('Newly published instruction material')
      expect(result.fetch('payload').fetch('html').scan('<pre').length).to eq(160)
    end
  end

  it 'invalidates prepared visibility after CSSOM changes even when serialized DOM is identical' do
    with_url_page('https://reference.example.test/manual.html', owned_manual_html) do |page|
      inject_standalone_extractor(page)
      result = owned_runtime_probe(page, <<~JS)
        const html = document.documentElement.outerHTML;
        document.styleSheets[0].insertRule('p.dynamic-sensitive { display: none; }', 0);
        const unchangedHtml = html === document.documentElement.outerHTML;
        return { owned: task.owned, payload: task.finish(), unchangedHtml, preparedScopesRestored };
      JS
      expect(result).to include('owned' => true, 'unchangedHtml' => true, 'preparedScopesRestored' => true)
      expect(result.fetch('payload').fetch('markdown')).not_to include('A visible paragraph whose rendering')
      expect(result.fetch('payload').fetch('html').scan('<pre').length).to eq(160)
    end
  end

  it 'leaves ordinary extraction and the standalone public facade on their existing paths' do
    html = '<html><head><title>Published reporting</title></head><body><main><h1>Published reporting</h1>' \
           '<p>A complete authored report with primary material and a source reference for the current publication.</p>' \
           '<p>A second complete paragraph provides the rest of the reporting without a standalone technical manual.</p></main></body></html>'
    with_url_page('https://reference.example.test/report.html', html) do |page|
      inject_standalone_extractor(page)
      expect(page.evaluate('Object.keys(window.FetchUtilExtract)')).to eq(['extract'])
      result = owned_runtime_probe(page, 'return { owned: task.owned, payload: task.finish(), preparedScopesRestored };')
      expect(result).to include('owned' => false, 'preparedScopesRestored' => true)
      expect(result.fetch('payload').fetch('markdown')).to include('A complete authored report', 'A second complete paragraph')
    end
  end

  it 'invalidates prepared material when new composed content leaves serialized HTML unchanged' do
    html = owned_manual_html.sub('</article>', '<div id="new-composed-host"></div></article>')
    with_url_page('https://reference.example.test/manual.html', html) do |page|
      inject_standalone_extractor(page)
      result = owned_runtime_probe(page, <<~JS)
        const html = document.documentElement.outerHTML;
        document.querySelector('#new-composed-host').attachShadow({mode: 'open'}).innerHTML =
          '<p>Newly composed authored reference material must remain available.</p>';
        return { owned: task.owned, unchangedHtml: html === document.documentElement.outerHTML,
          payload: task.finish(), preparedScopesRestored };
      JS
      expect(result).to include('owned' => true, 'unchangedHtml' => true, 'preparedScopesRestored' => true)
      expect(result.fetch('payload').fetch('markdown')).to include('Newly composed authored reference material')
    end
  end
end
