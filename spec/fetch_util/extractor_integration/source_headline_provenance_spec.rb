# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reader source headline provenance' do
  include_context 'extractor integration helpers'

  def source_headline_page(headlines: '<h1 id="source-headline">River restoration findings</h1>', body: nil)
    body ||= <<~HTML
      <article class="story-record">
        <div class="story-title">#{headlines}</div>
        <p>The river restoration team measured the reopened channel after six months of work.</p>
        <p>Engineers documented improved flow and habitat throughout the restored river corridor.</p>
      </article>
    HTML
    <<~HTML
      <!doctype html><html><head><title>River restoration findings | Research Journal</title>
      <meta property="og:site_name" content="Research Journal"></head><body>
      <main>#{body}</main></body></html>
    HTML
  end

  def provenance_probe(page)
    extract_payload(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    page.add_script_tag(content: source.sub(
      '})(window);',
      'window.__retainedReaderHeadline = sourceOwnedReaderRetainedHeadline; ' \
      'window.__stripReaderSourceMarkers = stripReadabilitySourceNodeMarkers; ' \
      'window.__readerHeader = sourceOwnedReaderHeaderContent; })(window);'
    ))
  end

  def retained_headline_probe(page, duplicate_paragraph: false, reverse_paragraphs: false,
                              paragraph_selector: 'p', unmapped_paragraph: false)
    page.evaluate(<<~JS)
      (() => {
        const marker = 'focused-source-proof';
        const headline = document.querySelector('h1');
        const sourceClones = new Map();
        const sourceIdentities = new Map();
        const clonedHeadline = headline.cloneNode(true);
        clonedHeadline.setAttribute('data-fetchutil-reader-source-headline', marker);
        sourceClones.set(headline, clonedHeadline);
        sourceIdentities.set(headline, {id: headline.id, internalId: false, unique: true});
        const output = document.createElement('div');
        const outputHeadline = document.createElement('h2');
        outputHeadline.id = headline.id;
        outputHeadline.textContent = headline.textContent;
        output.appendChild(outputHeadline);
        const paragraphs = Array.from(document.querySelectorAll(#{JSON.generate(paragraph_selector)}));
        if (#{reverse_paragraphs}) paragraphs.reverse();
        paragraphs.forEach((source, index) => {
          const clone = source.cloneNode(true);
          const token = `${marker}:${index}`;
          const id = `fetchutil-reader-${marker}-paragraph-${index}`;
          clone.id = id;
          clone.setAttribute('data-fetchutil-reader-source-paragraph', token);
          sourceClones.set(source, clone);
          sourceIdentities.set(source, {id, internalId: true, unique: true});
          output.appendChild(clone.cloneNode(true));
          if (#{duplicate_paragraph}) output.appendChild(clone.cloneNode(true));
        });
        if (#{unmapped_paragraph}) {
          const foreign = document.createElement('p');
          foreign.textContent = 'Unmapped retained prose from another source node.';
          output.appendChild(foreign);
        }
        const title = `${headline.textContent.trim()} | Research Journal`;
        const article = {title, content: output.innerHTML};
        const result = window.__retainedReaderHeadline(article, {title, siteName: 'Research Journal'}, sourceClones, sourceIdentities, marker);
        const clean = result && window.__stripReaderSourceMarkers(result.content, marker, sourceIdentities);
        return {accepted: !!result, title: result && result.title, excerpt: result && result.excerpt,
          owned: !!(result && result.sourceOwnedArticleBoundary), html: clean,
          originalBody: document.body.innerHTML};
      })()
    JS
  end

  it 'promotes a retained source H1 and id for an unknown host when ordered owned paragraphs prove the article' do
    extract_from_url('https://reports.example/features/river-restoration', source_headline_page) do |payload|
      expect(payload['readerMode']).to be(true)
      expect(payload['title']).to eq('River restoration findings')
      expect(payload['html']).to include('<h1 id="source-headline">River restoration findings</h1>')
      expect(payload['markdown'].scan('# River restoration findings').length).to eq(1)
      expect(payload['html']).to include('The river restoration team measured', 'Engineers documented improved flow')
      expect(payload['html']).not_to match(/data-fetchutil-reader-source-(?:headline|paragraph)|fetchutil-reader-/)
    end

    with_url_page('https://reports.example/features/river-restoration', source_headline_page) do |page|
      original_body = page.evaluate('document.body.innerHTML')
      provenance_probe(page)
      result = retained_headline_probe(page)
      expect(result.fetch('accepted')).to be(true)
      expect(result.fetch('owned')).to be(true)
      expect(result.fetch('html')).to include('<h1 id="source-headline">River restoration findings</h1>')
      expect(result.fetch('html')).not_to match(/data-fetchutil-reader-source-(?:headline|paragraph)|fetchutil-reader-focused-source-proof/)
      expect(page.evaluate('document.body.innerHTML')).to eq(original_body)
    end
  end

  it 'rejects competing, hidden and sidebar headlines plus foreign selected paragraphs' do
    variants = [
      source_headline_page(headlines: '<h1 id="first">River restoration findings</h1><h1>Another report</h1>'),
      source_headline_page(headlines: '<h1 id="source-headline" hidden>River restoration findings</h1>'),
      source_headline_page(body: <<~HTML),
        <aside><h1 id="source-headline">River restoration findings</h1></aside>
        <article><p>The river restoration team measured the reopened channel after six months of work.</p>
        <p>Engineers documented improved flow and habitat throughout the restored river corridor.</p></article>
      HTML
      source_headline_page(body: <<~HTML)
        <article><h1 id="source-headline">River restoration findings</h1>
        <p>The river restoration team measured the reopened channel after six months of work.</p>
        <p>Engineers documented improved flow and habitat throughout the restored river corridor.</p></article>
        <p>A different report describes unrelated findings from another research team.</p>
      HTML
    ]

    variants.each do |html|
      with_url_page('https://reports.example/features/river-restoration', html) do |page|
        provenance_probe(page)
        expect(retained_headline_probe(page).fetch('accepted')).to be(false)
      end
    end
  end

  it 'rejects an external headline when the nested-article owner cannot contain it without unrelated prose' do
    html = source_headline_page(body: <<~HTML)
      <header><h1 id="source-headline">River restoration findings</h1></header>
      <p>Unrelated visible introduction outside the nested story record.</p>
      <section class="story-shell"><article class="story-record">
        <p>The river restoration team measured the reopened channel after six months of work.</p>
        <p>Engineers documented improved flow and habitat throughout the restored river corridor.</p>
      </article></section>
    HTML

    with_url_page('https://reports.example/features/river-restoration', html) do |page|
      provenance_probe(page)
      result = retained_headline_probe(page, paragraph_selector: 'article.story-record p')
      expect(result.fetch('accepted')).to be(false)
    end
  end

  it 'rejects material retained paragraphs without an exact source-node identity' do
    with_url_page('https://reports.example/features/river-restoration', source_headline_page) do |page|
      provenance_probe(page)
      result = retained_headline_probe(page, unmapped_paragraph: true)
      expect(result.fetch('accepted')).to be(false)
    end
  end

  it 'rejects duplicate or reordered retained paragraph identities' do
    [{ duplicate_paragraph: true }, { reverse_paragraphs: true }].each do |options|
      with_url_page('https://reports.example/features/river-restoration', source_headline_page) do |page|
        provenance_probe(page)
        expect(retained_headline_probe(page, **options).fetch('accepted')).to be(false)
      end
    end
  end

  it 'uses only visible text from an owned source header excerpt' do
    html = source_headline_page(body: <<~HTML)
      <article class="story-record"><header><h1 id="source-headline">River restoration findings</h1>
      <p class="dek">Public summary <span hidden>private hidden material</span>for the restoration.</p></header>
      <p>The river restoration team measured the reopened channel after six months of work.</p>
      <p>Engineers documented improved flow and habitat throughout the restored river corridor.</p></article>
    HTML

    with_url_page('https://reports.example/features/river-restoration', html) do |page|
      provenance_probe(page)
      result = retained_headline_probe(page, paragraph_selector: 'article.story-record > p')
      expect(result.fetch('accepted')).to be(true)
      expect(result.fetch('excerpt')).to eq('Public summary for the restoration.')
      expect(result.fetch('html')).not_to include('private hidden material')
    end
  end

  it 'leaves media-bearing source headers conservative when Reader omitted their image and caption' do
    source = <<~HTML
      <html><head><title>River restoration findings | Research Journal</title></head><body>
      <article><header><h1>River restoration findings</h1>
      <figure><img src="/river.jpg" alt="Restored river"><figcaption>River restoration work</figcaption></figure>
      </header><p>The river restoration team measured the reopened channel after six months of work.</p>
      <p>Engineers documented improved flow and habitat throughout the restored river corridor.</p>
      </article></body></html>
    HTML
    candidate = {
      title: 'River restoration findings', html: '<p>One body paragraph.</p><p>Another body paragraph.</p>',
      readerMode: true, contentType: 'article', excerpt: 'A useful lead.'
    }

    with_url_page('https://reports.example/features/river-restoration', source) do |page|
      provenance_probe(page)
      result = page.evaluate("window.__readerHeader(#{JSON.generate(candidate)})")
      expect(result.fetch('html')).to eq(candidate[:html])
      expect(result.fetch('html')).not_to include('river.jpg', 'River restoration work')
    end
  end
end
