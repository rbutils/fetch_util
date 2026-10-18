# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'cgi'

RSpec.describe 'Physical reference bindings inside complete programs' do
  include_context 'extractor integration helpers'

  %w[sphinx mkdocs].each do |framework|
    it "retains visible program destinations and literal values in #{framework}" do
      url = 'https://reference.publication.example.test/manual/'
      resource = 'https://reference.publication.example.test/api/Module'
      other = 'https://reference.publication.example.test/api/Scalar'
      first = 'const π = Module("😀", "</pre>");'
      second = 'return Module(Scalar(π));'
      first_marked = CGI.escapeHTML(first).sub('Module', '<a href="/api/Module"><span>Module</span></a>')
      second_marked = CGI.escapeHTML(second).sub('Module', '<a href="/api/Module">Module</a>').sub('Scalar', '<a href="/api/Scalar">Scalar</a>')
      marked = "#{first_marked}\n#{second_marked}"
      main = <<~HTML
        <h1>Published package reference</h1>
        <p>This complete package reference documents the published dependency bindings and their exact program positions.</p>
        <h2>Complete declaration</h2>
        <pre><code class="language-javascript">#{marked}</code></pre>
        <p>Every genuine repeated destination remains independently bound to its own program token.</p>
        <h2>Plain declaration</h2><pre><code class="language-python">plain_value = 17
        print(plain_value)</code></pre>
        <div style="display:none"><pre><code>hidden_value = <a href="/api/Hidden">Hidden</a>()</code></pre></div>
        <p>Read the complete <a href="/guide/">published guide</a> after these declarations.</p>
      HTML
      owner = if framework == 'sphinx'
                "<div class=\"rst-content\"><div class=\"document\" role=\"main\">#{main}</div></div>"
              else
                "<main class=\"md-main\"><div class=\"md-content\"><article class=\"md-content__inner md-typeset\">#{main}</article></div></main>"
              end
      generator = framework == 'sphinx' ? 'Sphinx 8.0' : 'mkdocs-1.6.0'
      html = "<html><head><title>Published package reference</title><meta name=\"generator\" content=\"#{generator}\"></head><body>#{owner}</body></html>"

      with_url_page(url, html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        public_root = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expected = "#{first}\n#{second}"
        expect(public_root.css('pre code').map(&:text)).to eq([expected, "plain_value = 17\nprint(plain_value)"])
        expect(public_root.css('pre code a[href]').map { |node| [node['href'], node.text] }).to eq(
          [
            [resource, 'Module'], [resource, 'Module'], [other, 'Scalar']
          ]
        )
        linked_markdown = Nokogiri::HTML5.fragment(payload.fetch('markdown'))
        expect(linked_markdown.css('pre code').map(&:text)).to include(expected)
        expect(linked_markdown.css('pre code a[href]').map { |node| [node['href'], node.text] }).to eq(
          [
            [resource, 'Module'], [resource, 'Module'], [other, 'Scalar']
          ]
        )
        expect(payload.fetch('markdown')).to include("```python\nplain_value = 17\nprint(plain_value)\n```", '[published guide](https://reference.publication.example.test/guide/)')
        expect(payload.fetch('markdown')).not_to include('hidden_value', '/api/Hidden')
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
      end
    end
  end

  it 'preserves named targets and literal closing tags across normalized reference offsets' do
    html = <<~HTML
      <html><head><title>Published literal reference</title><meta name="generator" content="Sphinx 8.0"></head><body>
      <div class="rst-content"><div class="document" role="main"><h1>Published literal reference</h1>
      <p>This published declaration binds its exact program token and keeps the complete literal argument intact.</p>
      <pre><code class="language-javascript" id="declaration"></code></pre>
      <p>The <a href="/guide/">complete guide</a> follows the declaration.</p></div></div></body></html>
    HTML
    with_url_page('https://reference.publication.example.test/manual/', html) do |page|
      page.evaluate(<<~'JS')
        (() => {
          var code = document.getElementById("declaration");
          code.appendChild(document.createTextNode("\r\n😀\r\n"));
          var target = document.createElement("a"); target.id = "line-target"; code.appendChild(target);
          var reference = document.createElement("a"); reference.href = "/api/Call";
          reference.id = "call-target"; reference.title = 'Resource "</pre>"'; reference.textContent = "Call";
          code.appendChild(reference); code.appendChild(document.createTextNode('(</pre>);\r\n'));
        })()
      JS
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expected = "😀\nCall(</pre>);"
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        root = Nokogiri::HTML5.fragment(value)
        expect(root.at_css('pre code').text).to eq(expected)
        expect(root.css('pre code a[href]').map { |node| [node['href'], node.text, node['title']] }).to eq(
          [
            ['https://reference.publication.example.test/api/Call', 'Call', 'Resource "</pre>"']
          ]
        )
        expect(root.css('pre #line-target, pre #call-target').map { |node| node['id'] }).to eq(%w[line-target call-target])
        expect(root.css('pre #declaration').length).to eq(1)
      end
      expect(payload.fetch('markdown')).to include('[complete guide](https://reference.publication.example.test/guide/)')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains same-page symbol references as part of the complete literal program' do
    html = <<~HTML
      <html><head><title>Published local symbols</title><meta name="generator" content="Sphinx 8.0"></head><body>
      <div class="rst-content"><div class="document" role="main"><h1>Published local symbols</h1>
      <p>This complete declaration publishes a local symbol and binds its genuine reference inside the literal program.</p>
      <pre><code class="language-javascript">class <span id="Value">Value</span> {}
      return <a href="#Value">Value</a>();</code></pre>
      <p>The <a href="/guide/">complete guide</a> documents this independent declaration.</p></div></div></body></html>
    HTML
    with_url_page('https://reference.publication.example.test/manual/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      [payload.fetch('html'), payload.fetch('markdown')].each do |value|
        root = Nokogiri::HTML5.fragment(value)
        expect(root.at_css('pre code').text).to eq("class Value {}\nreturn Value();")
        expect(root.css('pre code a[href]').map { |node| [node['href'], node.text] }).to eq(
          [
            ['https://reference.publication.example.test/manual/#Value', 'Value']
          ]
        )
        expect(root.css('pre #Value').length).to eq(1)
      end
      expect(payload.fetch('markdown')).to include('[complete guide](https://reference.publication.example.test/guide/)')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
