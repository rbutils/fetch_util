# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned semantic article panels' do
  include_context 'extractor integration helpers'

  let(:article_title) { 'River restoration protects four districts' }
  let(:article_description) do
    'The restoration project reconnects four districts while protecting homes that flooded during three consecutive winters.'
  end

  def panel_result(html, path: 'source-owned-panel')
    url = "https://unknown.example/news/#{path}"
    result = nil
    with_url_page(url, html) do |page|
      source = page.evaluate('document.body.innerHTML')
      result = extract_payload(page, reader_mode: false)
      expect(page.evaluate('document.body.innerHTML')).to eq(source)
    end
    result
  end

  def panel_document(header: nil, article: nil, siblings: '', page_title: nil)
    page_title ||= "#{article_title} - Independent desk"
    <<~HTML
      <!doctype html>
      <html><head>
        <title>#{page_title}</title>
        <meta property="og:site_name" content="Independent desk">
        <meta name="description" content="#{article_description}">
      </head><body><main>
        #{header || <<~HEADER}
          <div class="record-title"><h1>#{article_title}</h1></div>
          <div class="record-attribution"><p>Mira Alavi</p><time datetime="2026-08-14T09:35:00Z">14 August 2026</time></div>
        HEADER
        #{article || <<~ARTICLE}
          <article>
            <p>#{article_description}</p>
            <p>Engineers rebuilt the riverbanks after reviewing historical maps, drainage records, and testimony from residents.</p>
            <p>Independent researchers measured water levels and published the complete monitoring data.</p>
            <p>The final design preserves wetlands beside the railway bridge and safer walking routes between neighborhoods.</p>
            <figure><img src="/media/river-levels.png" alt="Measured river levels"><figcaption>Monitoring data from the rebuilt riverbank.</figcaption></figure>
            <p>Read the <a href="/records/source-report">supporting source report</a> for the complete measurements.</p>
            <a href="/records/monitoring-data.csv" download>Download monitoring data</a>
            <p class="access-notice">Sign in to continue to the publisher's complete record.</p>
            <div class="article-tags"><a href="/topics/water-policy">Water policy</a></div>
          </article>
        ARTICLE
        #{siblings}
      </main></body></html>
    HTML
  end

  def most_read_collection(with_note: false)
    note = with_note ? '<p>Editors added a substantive explanation that belongs to the reporting page.</p>' : ''
    <<~HTML
      <section>
        <article>
          <h2><a href="/most-read">Most read</a></h2>
          <h3><a href="/news/district-one">District report one</a></h3>
          <h3><a href="/news/district-two">District report two</a></h3>
          #{note}
        </article>
      </section>
    HTML
  end

  def nested_most_read_collection(with_note: false, first_title: 'District report one')
    note = with_note ? '<p>Editors added a substantive explanation that belongs to the reporting page.</p>' : ''
    cards = [
      ['world/one', 'World', first_title],
      ['world/two', 'World', 'District report two'],
      ['sport/three', 'Sport', 'District report three']
    ].map do |path, category, title|
      <<~CARD
        <div class="card"><a href="/news/#{path}"><img src="/media/#{path}.jpg" alt="#{title}">
          <span>#{category}</span><h3>#{title}</h3></a></div>
      CARD
    end.join
    <<~HTML
      <section><h2><a href="/most-read">Most read</a></h2><div class="card-grid">#{cards}</div>#{note}</section>
    HTML
  end

  def nested_cards_with_material(material)
    cards = [
      ['world/one', 'World', 'District report one'],
      ['world/two', 'World', 'District report two']
    ].map do |path, category, title|
      <<~CARD
        <div class="card"><a href="/news/#{path}"><img src="/media/#{path}.jpg" alt="#{title}">
          <span>#{category}</span><h3>#{title}</h3></a>#{material}</div>
      CARD
    end.join
    %(<section><h2>Most read</h2><div class="card-grid">#{cards}</div></section>)
  end

  it 'ties a unique sibling headline and metadata header to one semantic article and excludes a proven related collection' do
    siblings = <<~HTML
      #{most_read_collection}
      <aside class="sidebar"><h2>District updates</h2><p>Independent page navigation.</p></aside>
    HTML
    payload = panel_result(panel_document(siblings: siblings))

    expect_content_type(payload, 'article')
    expect(payload.fetch('title')).to eq(article_title)
    expect(payload.fetch('html')).to include(article_title, 'Mira Alavi', '2026-08-14T09:35:00Z')
    expect(payload.fetch('html')).to include('The restoration project reconnects four districts')
    expect(payload.fetch('html')).to include('Measured river levels', 'Monitoring data from the rebuilt riverbank')
    expect(payload.fetch('html')).to include('supporting source report', 'monitoring-data.csv', 'Sign in to continue')
    expect(payload.fetch('html')).to include('Water policy')
    expect(payload.fetch('html')).not_to include('Most read', 'District report one', 'District report two')
    expect(payload.fetch('html')).not_to include('District updates', 'Independent page navigation')
  end

  it 'owns a source-linked article without main and excludes nested image-bearing related cards' do
    html = panel_document(siblings: nested_most_read_collection)
           .gsub('<main>', '<section class="article-layout">')
           .gsub('</main>', '</section>')
    payload = panel_result(html, path: 'nested-linked-records-without-main')

    expect(payload.fetch('title')).to eq(article_title)
    expect(payload.fetch('html')).to include('Mira Alavi', '2026-08-14T09:35:00Z')
    expect(payload.fetch('html')).to include('Measured river levels', 'monitoring-data.csv', 'Water policy')
    expect(payload.fetch('html')).not_to include('Most read', 'District report one', 'District report two', 'District report three')
    expect(payload.fetch('html')).not_to include('/media/world/one.jpg', '/media/world/two.jpg', '/media/sport/three.jpg')
  end

  it 'retains a complete linked card with a long source title in the proven related collection' do
    long_title = 'A' * 221
    payload = panel_result(
      panel_document(siblings: nested_most_read_collection(first_title: long_title)),
      path: 'long-related-record-title'
    )

    expect(payload.fetch('html')).to include(article_title, 'Measured river levels', 'monitoring-data.csv')
    html = payload.fetch('html')
    expect(html).to include(long_title, '/media/world/one.jpg', '/news/world/one', 'District report two', 'District report three')
    expect(html.index(long_title)).to be < html.index('District report two')
    expect(html.index('District report two')).to be < html.index('District report three')
    expect(payload.fetch('markdown')).to include(long_title, 'District report two', 'District report three')
  end

  it 'retains prose outside nested image-bearing related cards' do
    payload = panel_result(
      panel_document(siblings: nested_most_read_collection(with_note: true)),
      path: 'nested-related-cards-with-editorial-note'
    )

    expect(payload.fetch('html')).to include('Editors added a substantive explanation')
    expect(payload.fetch('html')).to include('Most read', 'District report one', 'District report two')
    expect(payload.fetch('markdown')).to include('The restoration project reconnects four districts')
  end

  it 'retains unowned text, media, captions, secondary links and references inside candidate cards' do
    material_cases = [
      ['paragraph', '<p>IN-CARD-EDITORIAL-PROSE: source context remains visible.</p>', 'IN-CARD-EDITORIAL-PROSE'],
      ['div', '<div>IN-CARD-EDITORIAL-DIV: source context remains visible.</div>', 'IN-CARD-EDITORIAL-DIV'],
      ['bare-text', 'IN-CARD-BARE-TEXT: source context remains visible.', 'IN-CARD-BARE-TEXT'],
      ['figure-caption', '<figure><img src="/media/card-extra.png"><figcaption>IN-CARD-CAPTION: image evidence.</figcaption></figure>', 'IN-CARD-CAPTION'],
      ['only-media', '<img src="/media/card-only-media.png" alt="" >', '/media/card-only-media.png'],
      ['secondary-resource', '<a href="/records/card-report.pdf">IN-CARD-RESOURCE: source report</a>', '/records/card-report.pdf'],
      ['reference-list', '<ul><li><a href="/references/card-source">IN-CARD-REFERENCE: source record</a></li></ul>', 'IN-CARD-REFERENCE']
    ]

    material_cases.each do |path, material, retained_marker|
      payload = panel_result(
        panel_document(siblings: nested_cards_with_material(material)),
        path: "card-material-#{path}"
      )

      expect(payload.fetch('html')).to include('Most read', 'District report one', 'District report two', retained_marker)
      if path == 'only-media'
        expect(payload.fetch('html')).to include(retained_marker)
      else
        expect(payload.fetch('markdown')).to include('Most read', retained_marker)
      end
    end
  end

  it 'preserves a title extension when publisher identity is not declared' do
    article = <<~HTML
      <article>
        <header><h1>#{article_title}</h1><p class="author-name">Mira Alavi</p>
          <time datetime="2026-08-14T09:35:00Z">14 August 2026</time></header>
        <p>#{article_description}</p>
        <p>Engineers rebuilt the riverbanks after reviewing historical maps and drainage records.</p>
        <p>Independent researchers measured water levels and published the complete monitoring data.</p>
        <p>The final design preserves wetlands beside the railway bridge and safe walking routes.</p>
      </article>
    HTML
    payload = panel_result(
      panel_document(header: '', article: article, page_title: "#{article_title} - Northern Gazette"),
      path: 'article-headline-brand-suffix'
    )

    expect(payload.fetch('title')).to eq("#{article_title} - Northern Gazette")
    expect(payload.fetch('html')).to include(article_title, 'Mira Alavi', '2026-08-14T09:35:00Z')
    expect(payload.fetch('html')).to include('The restoration project reconnects four districts')
  end

  it 'preserves a canonical article H1 when its legacy ownership proof has no title flag' do
    html = <<~HTML
      <!doctype html><html><head>
        <title>Source-owned research - River Gazette</title>
        <meta property="og:title" content="Source-owned research">
        <meta property="og:site_name" content="River Gazette">
        <link rel="canonical" href="https://journal.example/reports/source-owned-research">
      </head><body><main><article>
        <h1>Source-owned research</h1>
        <p>Researchers compared public records across four regions and published their verified methods for independent review.</p>
        <p>The report explains the results and preserves the source evidence for other researchers to examine.</p>
      </article></main></body></html>
    HTML
    payload = panel_result(html, path: 'canonical-source-headline')

    expect(payload.fetch('title')).to eq('Source-owned research')
    expect(payload.fetch('markdown')).to start_with('# Source-owned research')
  end

  it 'uses the existing canonical title when a direct legacy ownership object lacks titleIdentityProven' do
    html = <<~HTML
      <html><head><title>Canonical heading - Journal.example</title>
        <meta property="og:site_name" content="Journal.example"></head><body>
        <main><article><h1>Canonical heading</h1>
          <p>The public report presents verified results and records the complete method for independent review.</p>
        </article></main>
      </body></html>
    HTML
    with_url_page('https://journal.example/reports/canonical-heading', html) do |page|
      root = File.expand_path('../../../websieve', __dir__)
      source = File.readlines(File.join(root, 'manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, entry))
      end.join("\n")
      probe = source.sub('})(window);', 'window.__canonicalArticleBodyContent = canonicalArticleBodyContent; })(window);')
      page.add_script_tag(content: probe)
      titles = page.evaluate(<<~JS)
        (() => {
          const article = document.querySelector('article');
          const heading = article.querySelector('h1');
          const metadata = { title: document.title, siteName: 'Journal.example' };
          const ownership = { heading: heading, ownerRoot: document.querySelector('main'), title: heading.textContent,
            body: { sourceNode: article }, headerContext: null };
          const legacy = window.__canonicalArticleBodyContent(metadata, ownership);
          const differentPublication = window.__canonicalArticleBodyContent(
            { title: 'Canonical heading — Independent publication', siteName: 'Journal.example' }, ownership
          );
          const unproven = window.__canonicalArticleBodyContent(
            { title: 'Canonical heading — Unverified publication', siteName: 'Journal.example' },
            Object.assign({}, ownership, { titleIdentityProven: false })
          );
          return { legacy: legacy.title, differentPublication: differentPublication.title, unproven: unproven.title };
        })()
      JS

      expect(titles).to eq(
        'legacy' => 'Canonical heading',
        'differentPublication' => 'Canonical heading',
        'unproven' => 'Canonical heading — Unverified publication'
      )
    end
  end

  it 'ties a sibling headline to the article only when its branded title, exact lead, and attribution agree' do
    header = <<~HTML
      <div class="record-attribution"><p>Mira Alavi</p>
        <time datetime="2026-08-14T09:35:00Z">14 August 2026</time></div>
      <div class="record-title"><h1>#{article_title}</h1></div>
    HTML
    payload = panel_result(
      panel_document(header: header, page_title: "#{article_title}-Northern Gazette"),
      path: 'sibling-headline-branded-title'
    )

    expect(payload.fetch('title')).to eq(article_title)
    expect(payload.fetch('html')).to include('Mira Alavi', '2026-08-14T09:35:00Z')
    expect(payload.fetch('html')).to include('The restoration project reconnects four districts')
  end

  it 'does not bind an unrelated sibling headline to an article by main-region proximity' do
    header = <<~HTML
      <div class="record-attribution"><p>Mira Alavi</p>
        <time datetime="2026-08-14T09:35:00Z">14 August 2026</time></div>
      <div class="record-title"><h1>Regional transit briefing</h1></div>
    HTML
    page_title = 'The northern transport archive - Independent desk'
    payload = panel_result(panel_document(header: header, page_title: page_title), path: 'unrelated-sibling-headline')

    expect(payload.fetch('title')).to eq(page_title)
    expect(payload.fetch('markdown')).to include('Regional transit briefing', article_description)
    expect(payload.fetch('markdown')).to include('supporting source report')
  end

  it 'keeps a sibling references collection rather than treating its links as related-story chrome' do
    references = <<~HTML
      <section><h2>References</h2>
        <h3><a href="https://records.example/source-one">Source record one</a></h3>
        <h3><a href="https://records.example/source-two">Source record two</a></h3>
      </section>
    HTML
    payload = panel_result(panel_document(siblings: references), path: 'source-references')

    expect(payload.fetch('markdown')).to include(article_description, 'References', 'Source record one', 'Source record two')
    expect(payload.fetch('markdown')).to include('supporting source report')
  end

  it 'keeps visible prose interleaved with a related-looking heading group' do
    payload = panel_result(panel_document(siblings: most_read_collection(with_note: true)), path: 'interleaved-collection-note')

    expect(payload.fetch('html')).to include('Editors added a substantive explanation'), payload.fetch('html')
    expect(payload.fetch('markdown')).to include('Editors added a substantive explanation')
    expect(payload.fetch('markdown')).to include('District report one', 'District report two')
    expect(payload.fetch('markdown')).to include('The restoration project reconnects four districts')
  end

  it 'does not exclude unlinked editorial headings as an independently identified record collection' do
    notes = <<~HTML
      <section><h2>Related articles</h2>
        <div><h3>First editorial context heading</h3></div>
        <div><h3>Second editorial context heading</h3></div>
      </section>
    HTML
    payload = panel_result(panel_document(siblings: notes), path: 'unlinked-editorial-headings')

    expect(payload.fetch('markdown')).to include(
      article_description, 'Related articles', 'First editorial context heading', 'Second editorial context heading'
    )
  end

  it 'does not infer that a visible body belongs to a title when a different story is declared' do
    html = panel_document.sub(article_title, 'Different page-level headline')
    payload = panel_result(html, path: 'mismatched-title')

    expect(payload.fetch('markdown')).to include('Different page-level headline')
    expect(payload.fetch('markdown')).to include('The restoration project reconnects four districts')
    expect(payload.fetch('markdown')).to include('supporting source report')
  end

  it 'does not choose one long semantic article when a second independent article remains in the same main region' do
    second_article = <<~HTML
      <article><h2>Separate reporting record</h2>
        <p>This independent report documents a different public event using separate interviews and public records.</p>
        <p>Its conclusions concern another district and are not part of the river restoration article.</p>
        <p>Readers can follow the separate archive for source material and measurements.</p>
      </article>
    HTML
    payload = panel_result(panel_document(siblings: second_article), path: 'two-semantic-articles')

    expect(payload.fetch('markdown')).to include('The restoration project reconnects four districts')
    expect(payload.fetch('markdown')).to include('Separate reporting record', 'different public event', 'separate archive')
  end
end
