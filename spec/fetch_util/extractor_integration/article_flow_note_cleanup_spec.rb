# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil generic article flow-note cleanup' do
  include_context 'extractor integration helpers'

  def extract_without_source_mutation(url, html)
    with_url_page(url, html) do |page|
      extractor_for(true).__send__(:inject_assets, page)
      before = page.evaluate('document.documentElement.outerHTML')
      payload = page.evaluate('window.FetchUtilExtract.extract({reader_mode: true})')
      expect(page.evaluate('document.documentElement.outerHTML')).to eq(before)
      yield payload
    end
  end

  def article_flow_note_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub(
      '})(window);',
      'global.__cleanupGenericArticleFlowNote = cleanupGenericArticleFlowNote; })(window);'
    )
  end

  def clean_flow_note_clone(url, html, selector)
    with_url_page(url, html) do |page|
      page.add_script_tag(content: article_flow_note_source)
      yield page.evaluate(<<~JS)
        (() => {
          const original = document.documentElement.outerHTML;
          const clone = document.querySelector(#{selector.to_json}).cloneNode(true);
          window.__cleanupGenericArticleFlowNote(clone);
          return {html: clone.innerHTML, sourceUnchanged: document.documentElement.outerHTML === original};
        })()
      JS
    end
  end

  let(:body) do
    <<~HTML
      <p>Residents described the first verified change in enough detail to establish a substantive focal article body for readers.</p>
      <p>Officials explained the second verified change and its practical consequences in another independently useful paragraph.</p>
      <p>The final article paragraph records the remaining evidence and completes the report without relying on interface furniture.</p>
    HTML
  end

  it 'removes one short terminal exact flow-note widget' do
    html = <<~HTML
      <html><head><title>Verified city report</title></head><body>
        <article><h1>Verified city report</h1>#{body}<div class="article-flow-note">Latest news flow</div></article>
      </body></html>
    HTML

    extract_without_source_mutation('https://reports.example/city/verified-change', html) do |payload|
      expect(payload.fetch('markdown')).to include('Residents described', 'The final article paragraph')
      expect(payload.fetch('markdown').scan('Residents described').length).to eq(1)
      expect(payload.fetch('markdown').scan('The final article paragraph').length).to eq(1)
      expect(payload.fetch('markdown')).not_to include('Latest news flow')
    end
  end

  it 'preserves ambiguous or substantive flow-note lookalikes' do
    cases = {
      near_match: ['<div class="article-flow-notes">Near-match editorial note</div>', ['Near-match editorial note']],
      linked: ['<div class="article-flow-note"><a href="/live">Follow the verified live report</a></div>', ['verified live report']],
      paragraph: ['<div class="article-flow-note"><p>Editors added a material correction with important context.</p></div>', ['material correction']],
      attributed: ['<div class="article-flow-note" data-state="verified">Attributed editorial note</div>', ['Attributed editorial note']],
      semantic_root: ['<p class="article-flow-note">Paragraph-owned editorial note</p>', ['Paragraph-owned editorial note']],
      interactive: ['<div class="article-flow-note"><details><summary>Editorial note details</summary></details></div>', ['Editorial note details']],
      unlinked_anchor: ['<div class="article-flow-note"><a>Editorial note anchor</a></div>', ['Editorial note anchor']],
      nonterminal: ['<div class="article-flow-note">Editorial transition</div><p>A later material paragraph must keep its preceding transition note.</p>',
                    ['Editorial transition', 'later material paragraph']],
      nonterminal_media: ['<div class="article-flow-note">Image transition</div><figure><img src="/evidence.jpg" alt="Material evidence"></figure>',
                          ['Image transition', 'Material evidence']],
      nested_nonterminal: ['<div><div class="article-flow-note">Nested transition</div></div><p>A later owner paragraph remains material.</p>',
                           ['Nested transition', 'later owner paragraph']],
      repeated: ['<div class="article-flow-note">First editorial note</div><div class="article-flow-note">Second editorial note</div>',
                 ['First editorial note', 'Second editorial note']]
    }

    cases.each do |name, (note, expected)|
      html = <<~HTML
        <html><head><title>#{name} report</title></head><body>
          <article><h1>#{name} report</h1>#{body}#{note}</article>
        </body></html>
      HTML

      extract_without_source_mutation("https://reports.example/#{name}", html) do |payload|
        expect(payload.fetch('markdown')).to include(*expected)
      end
    end
  end

  it 'does not remove a flow note from a short or non-article owner' do
    short_article = <<~HTML
      <html><head><title>Short report</title></head><body>
        <article><h1>Short report</h1><p>One short report paragraph.</p><div class="article-flow-note">Editorial note</div></article>
      </body></html>
    HTML
    collection = <<~HTML
      <html><head><title>Report collection</title></head><body>
        <div><p>#{"Collection context " * 20}</p><p>#{"More collection context " * 20}</p><div class="article-flow-note">Collection note</div></div>
      </body></html>
    HTML

    extract_without_source_mutation('https://reports.example/short', short_article) do |payload|
      expect(payload.fetch('markdown')).to include('Editorial note')
    end
    extract_without_source_mutation('https://reports.example/', collection) do |payload|
      expect(payload.fetch('markdown')).to include('Collection note')
    end
  end

  it 'does not borrow qualifying prose from sibling articles or from after the note' do
    sibling_articles = <<~HTML
      <html><head><title>Article collection</title></head><body><main>
        <article><h2>First report</h2><p>#{"First report evidence " * 20}</p><p>#{"More first report evidence " * 20}</p></article>
        <div class="article-flow-note">Collection editorial note</div>
        <article><h2>Second report</h2><p>#{"Second report evidence " * 20}</p><p>#{"More second report evidence " * 20}</p></article>
      </main></body></html>
    HTML
    later_prose = <<~HTML
      <html><head><title>Later prose report</title></head><body><article>
        <h1>Later prose report</h1><p>Short opening paragraph.</p>
        <div><div class="article-flow-note">Earlier editorial note</div></div>
        <p>#{"Later evidence cannot qualify an earlier note " * 12}</p>
        <p>#{"Additional later evidence remains material " * 12}</p>
      </article></body></html>
    HTML
    article_body_collection = <<~HTML
      <html><head><title>Structured article collection</title></head><body>
        <div itemprop="articleBody">
          <article><h2>Nested report</h2><p>#{"Nested report evidence " * 20}</p><p>#{"More nested report evidence " * 20}</p></article>
          <div class="article-flow-note">Structured collection note</div>
        </div>
      </body></html>
    HTML
    nested_article_collection = <<~HTML
      <html><head><title>Nested article collection</title></head><body>
        <article id="outer">
          <article><h2>Nested article</h2><p>#{"Nested article evidence " * 20}</p><p>#{"More nested article evidence " * 20}</p></article>
          <div class="article-flow-note">Outer article collection note</div>
        </article>
      </body></html>
    HTML

    clean_flow_note_clone('https://reports.example/collection', sibling_articles, 'main') do |result|
      expect(result.fetch('html')).to include('Collection editorial note')
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
    clean_flow_note_clone('https://reports.example/later-prose', later_prose, 'article') do |result|
      expect(result.fetch('html')).to include('Earlier editorial note', 'Later evidence cannot qualify')
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
    clean_flow_note_clone('https://reports.example/article-body-collection', article_body_collection, '[itemprop="articleBody"]') do |result|
      expect(result.fetch('html')).to include('Structured collection note')
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
    clean_flow_note_clone('https://reports.example/nested-article-collection', nested_article_collection, '#outer') do |result|
      expect(result.fetch('html')).to include('Outer article collection note')
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
  end
end
