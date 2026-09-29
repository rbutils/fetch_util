# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Source-owned article bylines and dates' do
  include_context 'extractor integration helpers'

  def byline_payload(html, path)
    payload = nil
    with_url_page("https://unknown.example/articles/#{path}", html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
    payload
  end

  def byline_extension(html, content_byline:, path:, selected_selector: 'article', record_source: true)
    extension = nil
    with_url_page("https://unknown.example/articles/#{path}", html) do |page|
      root = File.expand_path('../../../websieve', __dir__)
      source_paths = File.readlines(File.join(root, 'manifest.txt'), chomp: true).reject(&:empty?)
      source = source_paths.map { |source_path| File.read(File.join(root, source_path)) }.join("\n")
      exports = 'window.__ownedBylinePolicy = { collect: collectMetadata, semantic: sourceOwnedSemanticArticleOwnership, extend: readerSourceOwnedBylineExtension };'
      probe = source.sub('})(window);', "#{exports} })(window);")
      page.add_script_tag(content: probe)
      evidence = page.evaluate(<<~JS)
        (() => {
          const metadata = window.__ownedBylinePolicy.collect();
          const selectedBody = document.querySelector(#{selected_selector.to_json});
          const semantic = window.__ownedBylinePolicy.semantic(metadata).ownership;
          const content = {
            contentType: 'article',
            sourceOwnedFocalArticle: true,
            readerMode: false,
            html: selectedBody.outerHTML,
            siteName: metadata.siteName
          };
          if (#{record_source.to_json}) {
            Object.defineProperty(content, 'sourceOwnedArticleBody', { value: selectedBody });
          }
          return {
            semanticPresent: !!semantic,
            ownsSelection: !!semantic && semantic.body.sourceNode.contains(selectedBody),
            extension: window.__ownedBylinePolicy.extend(content, metadata, #{content_byline.to_json}, metadata.byline)
          };
        })()
      JS
      expect(evidence).to include('semanticPresent' => true, 'ownsSelection' => false) if selected_selector != 'article'
      extension = evidence.fetch('extension')
    end
    extension
  end

  def source_article(title, header:, article:)
    first_paragraph = article.split("<p>").drop(1).first.to_s.split("</p>").first
    <<~HTML
      <!doctype html>
      <html><head>
        <title>#{title} - River Gazette</title>
        <meta property="og:site_name" content="River Gazette">
        <meta name="author" content="River Gazette">
        <meta name="description" content="#{first_paragraph}">
        <meta property="article:published_time" content="٢٠٢٦-٠٧-٠٧T١٤:٣٠:٠٠+٠٣:٠٠">
      </head><body><main>
        #{header}
        #{article}
      </main></body></html>
    HTML
  end

  let(:title) { 'A river corridor brings safer routes to four districts' }
  let(:first_paragraph) do
    'The river authority published a detailed plan after engineers reviewed flood records, drainage maps, and interviews with residents.'
  end

  it 'retains a unique source byline beside a source date when every article paragraph matches the selected body' do
    article = <<~HTML
      <section class="reporting-body">
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </section>
    HTML
    header = <<~HTML
      <h1>#{title}</h1>
      <div><time datetime="2026-07-07T14:30:00+03:00">7 July 2026, 14:30</time>
        <p>Regional reporting desk — North District</p></div>
    HTML
    payload = byline_payload(source_article(title, header: header, article: article), 'owned-header-byline')

    expect(payload.fetch('title')).to eq(title)
    expect(payload.fetch('byline')).to eq('Regional reporting desk — North District'), payload.inspect
    expect(payload.fetch('publishedTime')).to eq('2026-07-07T14:30:00+03:00')
    expect(payload.fetch('markdown')).to include(first_paragraph, 'Researchers measured water levels')
  end

  it 'uses one same-origin author link and date in the owned header before a sibling headline' do
    description = 'Engineers documented the shoreline repairs after reviewing public records, flood gauges, and neighborhood reports.'
    header = <<~HTML
      <div class="publication-details">
        <time datetime="2026-07-06T11:16:42Z">2026-07-06 11:16:42</time>
        <a href="/authors/city-ledger">city-ledger</a>
      </div>
      <div class="headline"><h1>City ledger documents shoreline repairs</h1></div>
    HTML
    article = <<~HTML
      <article>
        <p>#{description}</p>
        <p>Public engineers compared repair schedules with measurements from the regional flood network.</p>
        <p>Residents can review the source records and report additional damaged locations through the city portal.</p>
      </article>
    HTML
    html = <<~HTML
      <!doctype html><html><head>
        <title>City ledger documents shoreline repairs - River Gazette</title>
        <meta property="og:site_name" content="River Gazette">
        <meta name="description" content="#{description}">
        <meta property="article:published_time" content="2026-07-06T11:16:42Z">
      </head><body><main>#{header}#{article}</main></body></html>
    HTML
    payload = byline_payload(html, 'linked-header-author')

    expect(payload.fetch('title')).to eq('City ledger documents shoreline repairs')
    expect(payload.fetch('byline')).to eq('city-ledger')
    expect(payload.fetch('publishedTime')).to eq('2026-07-06T11:16:42Z')
    expect(payload.fetch('html')).to include('authors/city-ledger', description)
  end

  it 'does not replace a different declared person with an unmarked visible header line' do
    article = <<~HTML
      <article>
        <time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </article>
    HTML
    header = <<~HTML
      <div><h1>#{title}</h1><time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <p>Mira Reporter</p></div>
    HTML
    html = source_article(title, header: header, article: article).sub(
      '<meta name="author" content="River Gazette">', '<meta name="author" content="Synthetic Reporter">'
    )
    payload = byline_payload(html, 'conflicting-declared-person')

    expect(payload.fetch('byline')).to eq('Synthetic Reporter')
    expect(payload.fetch('html')).to include('Mira Reporter')
  end

  it 'does not replace a conflicting declared person with a same-origin author link' do
    description = 'Engineers documented the shoreline repairs after reviewing public records, flood gauges, and neighborhood reports.'
    header = <<~HTML
      <div class="publication-details">
        <time datetime="2026-07-06T11:16:42Z">2026-07-06 11:16:42</time>
        <a href="/authors/mira-reporter">Mira Reporter</a>
      </div>
      <div class="headline"><h1>City ledger documents shoreline repairs</h1></div>
    HTML
    article = <<~HTML
      <article><p>#{description}</p>
        <p>Public engineers compared repair schedules with measurements from the regional flood network.</p>
        <p>Residents can review the source records and report additional damaged locations through the city portal.</p>
      </article>
    HTML
    html = <<~HTML
      <!doctype html><html><head>
        <title>City ledger documents shoreline repairs - River Gazette</title>
        <meta property="og:site_name" content="River Gazette">
        <meta name="author" content="Synthetic Reporter">
        <meta name="description" content="#{description}">
      </head><body><main>#{header}#{article}</main></body></html>
    HTML
    payload = byline_payload(html, 'conflicting-linked-person')

    expect(payload.fetch('byline')).to eq('Synthetic Reporter')
    expect(payload.fetch('html')).to include('authors/mira-reporter', description)
  end

  it 'keeps multiple marked authors only when they form one source-owned byline group' do
    article = <<~HTML
      <article><h1>#{title}</h1>
        <div class="writers-names"><span class="writer-name-item">Mira Alavi</span>
          <span class="writer-name-item">Noah Kim</span></div>
        <time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </article>
    HTML
    payload = byline_payload(source_article(title, header: '', article: article), 'coherent-multiple-authors')

    expect(payload.fetch('byline')).to eq('Mira Alavi Noah Kim')
  end

  it 'does not join separately marked authors from unrelated header blocks' do
    article = <<~HTML
      <article><time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </article>
    HTML
    header = <<~HTML
      <div><h1>#{title}</h1><time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <div class="author-name">Mira Alavi</div><div class="writer-name">Noah Kim</div></div>
    HTML
    payload = byline_payload(source_article(title, header: header, article: article), 'ambiguous-multiple-authors')

    expect(payload.fetch('byline')).to eq('River Gazette')
  end

  it 'preserves an existing content-owned person and permits only an exact visible extension' do
    article = <<~HTML
      <article>
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </article>
    HTML
    header = <<~HTML
      <div><h1>#{title}</h1><time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <p>Mira Reporter — North District</p></div>
    HTML
    html = source_article(title, header: header, article: article)

    expect(byline_extension(html, content_byline: 'Existing article editor', path: 'existing-content-owner-conflict')).to be_nil
    expect(byline_extension(html, content_byline: 'Mira Reporter', path: 'existing-content-owner-extension'))
      .to eq('Mira Reporter — North District')
  end

  it 'does not attribute a differently selected body to another semantic article header' do
    article = <<~HTML
      <article><p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and published their complete monitoring records.</p>
        <p>The completed route reconnects homes with the district transit station.</p>
      </article>
    HTML
    header = <<~HTML
      <h1>#{title}</h1>
      <div><time datetime="2026-07-07T14:30:00Z">7 July 2026</time><p>Mira Reporter</p></div>
    HTML
    selected = <<~HTML
      <article id="independent-selected-record"><p>The independent archive documents the history of regional railway construction.</p>
        <p>Its records identify the original contractors and include the complete engineering drawings.</p>
      </article>
    HTML

    html = source_article(title, header: header, article: article).sub('</main>', "</main><aside>#{selected}</aside>")
    [true, false].each do |record_source|
      expect(byline_extension(
               html,
               content_byline: nil,
               path: 'different-selected-body',
               selected_selector: '#independent-selected-record',
               record_source: record_source
             )).to be_nil
    end
  end

  it 'does not use an aside author or ambiguous header paragraphs as the article byline' do
    article = <<~HTML
      <article>
        <header><h1>#{title}</h1><time datetime="2026-07-07T14:30:00Z">7 July 2026</time></header>
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </article>
    HTML
    header = <<~HTML
      <aside><p class="author-name">Regional reporting desk — North District</p></aside>
      <div><h1>#{title}</h1><time datetime="2026-07-07T14:30:00Z">7 July 2026</time>
        <p>Regional reporting desk</p><p>North District updates</p></div>
    HTML
    payload = byline_payload(source_article(title, header: header, article: article), 'ambiguous-header-byline')

    expect(payload.fetch('byline')).to eq('River Gazette')
    expect(payload.fetch('markdown')).to include(first_paragraph)
  end

  it 'preserves a source byline suffix longer than 160 characters' do
    suffix = (1..35).map { |index| "regional bureau #{index}" }.join(' / ')
    byline = "River Gazette — #{suffix}"
    article = <<~HTML
      <section>
        <p>#{first_paragraph}</p>
        <p>Researchers measured water levels through three winters and compared the readings with public infrastructure reports.</p>
        <p>The completed route follows the riverbank and reconnects homes with the district transit station.</p>
      </section>
    HTML
    payload = byline_payload(
      source_article(title, header: "<h1>#{title}</h1><div><time datetime=\"2026-07-07T14:30:00Z\">7 July 2026</time><div>#{byline}</div></div>", article: article),
      'long-literal-byline'
    )

    expect(byline.length).to be > 160
    expect(payload.fetch('byline')).to eq(byline), payload.inspect
  end
end
