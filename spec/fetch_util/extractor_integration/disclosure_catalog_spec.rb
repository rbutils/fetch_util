# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Self-indexed disclosure catalogs', :integration do
  include_context 'extractor integration helpers'

  def disclosure_catalog_html(count = 603)
    index = (1..count).map { |number| %(<a href="#group-#{number}">Dataset #{number}</a>) }.join(' ')
    groups = (1..count).map do |number|
      <<~HTML
        <a name="group-#{number}"></a><button type="button" id="label-#{number}">Dataset #{number}</button>
        <div id="panel-#{number}"><h2>Release #{number}</h2>
        <p>Complete authored description #{number} retains the resource format, limitations and source relationships.</p>
        <ul><li><a href="/data/#{number}/sequence">Sequence #{number}</a></li>
        <li><a href="/data/#{number}/annotation">Annotation #{number}</a></li></ul>
        <pre><code class="language-text">fetch dataset_#{number}
        preserve_all_values_#{number}</code></pre></div>
      HTML
    end.join
    <<~HTML
      <!doctype html><html lang="en"><head><title>Dataset download catalog</title>
      <meta name="author" content="Unrelated site maintainer"></head><body>
      <nav><a href="/">Site home</a><a href="/help">Site help</a></nav><div><section id="catalog">
      <h1>Complete dataset downloads</h1><p>Published resource descriptions and every materialized dataset follow.</p>
      <nav id="catalog-index"><div id="index-category"><a href="#index-category">Catalog categories</a>
      <a href="#unresolved-source-reference">Unresolved source reference</a></div>#{index}</nav>#{groups}
      <p><a href="ftp://downloads.example.test/archive/data.bin">Original transfer resource</a></p>
      <p><a href="ftp://secret:password@downloads.example.test/private.bin">Credential-bearing reference</a></p>
      <footer><a href="/api">Published catalog API</a><a href="/sources">Source attribution</a></footer>
      <template><p>Inactive fallback must not become reporting.</p></template></section></div></body></html>
    HTML
  end

  def disclosure_catalog_namespace
    root = File.expand_path('../../../websieve', __dir__)
    files = File.readlines(File.join(root, 'manifest.txt'), chomp: true).reject { |line| line.empty? || line.start_with?('#') }
    script = files.map { |relative| File.read(File.join(root, relative)) }.join("\n")
    boundary = '})(window);'
    raise 'unexpected namespace boundary' unless script.scan(boundary).length == 1
    script.sub(boundary, "window.__catalogProof = disclosureCatalogContext;\n#{boundary}")
  end

  it 'retains every indexed disclosure, resource, program and footer in physical order' do
    with_url_page('https://archive.example.test/downloads.html', disclosure_catalog_html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      html = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(payload).to include('title' => 'Complete dataset downloads', 'contentType' => 'list',
                                 'byline' => nil, 'publishedTime' => nil, 'readerMode' => false)
      expect(html.css('h2').map(&:text)).to eq((1..603).map { |number| "Release #{number}" })
      expect(html.css('a[name]').map { |node| node['name'] }).to eq((1..603).map { |number| "group-#{number}" })
      expect(html.css('a[href]').map { |node| node['href'] }).to include(
        'https://archive.example.test/downloads.html#index-category',
        'https://archive.example.test/downloads.html#unresolved-source-reference'
      )
      expect(html.css('[id="unresolved-source-reference"]')).to be_empty
      expect(html.css('pre').map(&:text)).to eq((1..603).map { |number| "fetch dataset_#{number}\npreserve_all_values_#{number}" })
      (1..603).each do |number|
        expect(payload.fetch('markdown')).to include("Complete authored description #{number}",
                                                     "https://archive.example.test/data/#{number}/sequence",
                                                     "https://archive.example.test/data/#{number}/annotation", "preserve_all_values_#{number}")
      end
      expect(payload.fetch('markdown')).to include('Published catalog API', 'https://archive.example.test/api',
                                                   'Source attribution', 'Original transfer resource', 'ftp://downloads.example.test/archive/data.bin')
      expect(html.css('a[href^="ftp:"]')).to be_empty
      expect(payload.fetch('markdown')).not_to include('secret:password', 'Inactive fallback must not become reporting')
      expect(html.css('button, input, form, script, style, template')).to be_empty
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains current visibility without opening panels or changing disclosure state' do
    html = disclosure_catalog_html(3).sub('<div id="panel-2">', '<div id="panel-2" style="display:none">')
    with_url_page('https://archive.example.test/downloads.html', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('markdown')).to include('Complete authored description 1', 'Complete authored description 3')
      expect(payload.fetch('markdown')).not_to include('Complete authored description 2', 'preserve_all_values_2')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'declines incomplete, foreign, ambiguous and competing owners and observes restored source freshly' do
    with_url_page('https://archive.example.test/downloads.html', disclosure_catalog_html(3)) do |page|
      page.evaluate(disclosure_catalog_namespace)
      result = page.evaluate(<<~JS)
        (() => {
          const original = document.body.innerHTML;
          const test = window.__catalogProof;
          const initial = !!test();
          const mutations = [
            () => document.querySelector('#catalog').style.display = 'none',
            () => document.querySelector('a[name="group-1"]').removeAttribute('name'),
            () => document.querySelector('#panel-1 li a').remove(),
            () => document.querySelector('#catalog').insertAdjacentHTML('beforeend', '<article><p>Foreign reporting.</p></article>'),
            () => document.body.insertAdjacentHTML('beforeend', '<p>Authored material outside the proposed catalog.</p>'),
            () => document.querySelector('#panel-2').insertAdjacentHTML('beforeend', '<a name="group-1"></a>'),
            () => document.querySelectorAll('#catalog-index a').forEach(a => a.href = 'https://foreign.example.test/' + a.hash),
            () => document.querySelector('#catalog').insertAdjacentHTML('beforeend', '<form><input name="password"></form>'),
            () => document.querySelector('#catalog').insertAdjacentHTML('afterbegin', '<h1>Competing page identity</h1>')
          ];
          const declined = mutations.map(change => {
            document.body.innerHTML = original;
            change();
            return test() === null;
          });
          document.body.innerHTML = original;
          return { initial, declined, restored: !!test(), unchanged: document.body.innerHTML === original };
        })()
      JS
      expect(result).to include('initial' => true, 'restored' => true, 'unchanged' => true)
      expect(result.fetch('declined')).to eq([true] * 9)
    end
  end
end
