# frozen_string_literal: true

RSpec.describe 'content fidelity contracts' do
  include_context 'extractor integration helpers'
  include_context 'content fidelity contracts'

  def card(item)
    ["- [#{item[:title]}](https://fidelity.test#{item[:href]})", item[:summary], item[:metadata]].compact.join("\n  ")
  end

  def payload(markdown, type: 'list', social_kind: nil)
    { 'contentType' => type, 'socialKind' => social_kind, 'markdown' => markdown }
  end

  def portal_contract
    inventory(
      shape: :homepage, types: 'list', chrome: %w[FID:chrome-header FID:chrome-sidebar FID:chrome-footer],
      focal: %w[FID:portal FID:world FID:world-01 FID:business FID:business-01 FID:sport FID:sport-01],
      regions: %w[world business sport].map { |name| { id: name, label: "FID:#{name}", required: true, focal: true } },
      items: %w[world business sport].map do |name|
        { id: name, title: "FID:#{name}-01", href: "/#{name}-01", summary: "FID:#{name}-summary", focal: true }
      end
    )
  end

  def compact_contract(shape, type, markers, headings: [markers.first], items: [], social_kind: nil)
    inventory(
      shape:, types: type, social_kinds: social_kind,
      chrome: %w[FID:chrome-header FID:chrome-footer FID:chrome-sidebar FID:chrome-related FID:chrome-ad FID:chrome-filter],
      focal: markers,
      regions: headings.map.with_index { |label, index| { id: "region-#{index}", label:, required: true, focal: true } },
      items:
    )
  end

  def fixture(name)
    fixture_contents(File.expand_path("../../fixtures/#{name}.html", __dir__))
  end

  it 'matches sanitized portal, feed, article, thread, search, and docs inventories' do
    portal = portal_contract
    portal_markdown = [
      '# FID:portal', '## FID:world', card(portal.items[0]), '## FID:business',
      card(portal.items[1]), '## FID:sport', card(portal.items[2])
    ].join("\n\n")
    tag_items = [
      { id: 'one', title: 'FID:tag-01', href: '/posts/01', summary: 'FID:tag-summary-01', metadata: 'FID:tag-meta-01', focal: true },
      { id: 'two', title: 'FID:tag-02', href: '/posts/02', summary: 'FID:tag-summary-02', metadata: 'FID:tag-meta-02', focal: true }
    ]
    tag = compact_contract(:feed, 'list', %w[FID:tag-ruby FID:tag-01 FID:tag-02], items: tag_items)
    search_items = [
      { id: 'one', title: 'FID:search-01', href: '/result-01', summary: 'FID:search-snippet-01', focal: true },
      { id: 'two', title: 'FID:search-02', href: '/result-02', summary: 'FID:search-snippet-02', focal: true }
    ]
    search = compact_contract(:search, 'search', %w[FID:search-query FID:search-count FID:search-01 FID:search-02], items: search_items)
    article = compact_contract(
      :article, 'article', %w[FID:article-title FID:article-lead FID:article-body-01 FID:article-caption FID:article-body-02],
      headings: %w[FID:article-title FID:article-body-01 FID:article-body-02]
    )
    thread = compact_contract(
      :social_thread, 'social', ['Czy jutro warto sadzić fasolę?', 'Sprawdziłam prognozę i przygotowałam trzy skrzynki.', 'Odpowiedź spod jabłoni', 'Głos z balkonu'],
      headings: ['Czy jutro warto sadzić fasolę?', 'Odpowiedź spod jabłoni'], social_kind: 'thread'
    )
    docs = compact_contract(
      :docs_index, 'list', %w[FID:docs-identity FID:docs-intro FID:docs-guides FID:docs-start FID:docs-reference FID:docs-api],
      headings: %w[FID:docs-identity FID:docs-guides FID:docs-reference]
    )
    article_markdown = <<~MARKDOWN
      # FID:article-title

      FID:article-lead

      FID:article-byline

      ## FID:article-body-01

      FID:article-body-copy-01

      FID:article-caption

      ## FID:article-body-02
    MARKDOWN
    thread_markdown = <<~MARKDOWN.chomp
      # Czy jutro warto sadzić fasolę?

      autor: Lena z podwórka

      Sprawdziłam prognozę i przygotowałam trzy skrzynki.

      ## Odpowiedź spod jabłoni

      U mnie ziemia jest jeszcze ciepła, więc poczekam do południa.

      ## Głos z balkonu
    MARKDOWN
    docs_markdown = <<~MARKDOWN
      # FID:docs-identity

      FID:docs-intro

      ## FID:docs-guides

      FID:docs-start

      FID:docs-start-description

      ## FID:docs-reference

      FID:docs-api

      FID:docs-api-description
    MARKDOWN
    examples = [
      [portal, payload(portal_markdown)],
      [tag, payload("# FID:tag-ruby\n\n#{card(tag_items[0])}\n\n#{card(tag_items[1])}")],
      [article, payload(article_markdown, type: 'article')],
      [thread, payload(thread_markdown, type: 'social', social_kind: 'thread')],
      [search, payload("# FID:search-query\n\nFID:search-count\n\n#{card(search_items[0])}\n\n#{card(search_items[1])}", type: 'search')],
      [docs, payload(docs_markdown)]
    ]
    examples.each { |contract, result| expect_content_fidelity(result, contract) }
  end

  it 'characterizes the current portal fixture without making baseline extraction a required pass' do
    with_url_page('https://fidelity.test/', fixture('fidelity_portal_sections')) do |page|
      result = ContentFidelity.match(extract_payload(page, reader_mode: false), portal_contract)
      expect(result).to be_a(ContentFidelity::Result)
      expect(result.metrics).to include(:classification_ok, :region_coverage, :chrome_hits)
    end
  end

  it 'extracts substantive named regions in DOM order' do
    with_url_page('https://fidelity.test/', fixture('fidelity_portal_sections')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      expect(result['title']).to eq('FID:portal')
      expect(result['markdown']).to include('FID:world-01', 'FID:world-summary')
      expect(result['markdown']).to include('FID:business-01', 'FID:business-summary')
      expect(result['markdown']).to include('FID:sport-01', 'FID:sport-summary')
      expect(result['markdown'].index('## FID:world')).to be < result['markdown'].index('## FID:business')
      expect(result['markdown'].index('## FID:business')).to be < result['markdown'].index('## FID:sport')
    end
  end

  it 'does not let a broader root replace ordered section coverage' do
    html = <<~HTML
      <header><a href="/header">FID:chrome-header</a></header>
      <main>
        <section><h2>FID:primary</h2><article><h3><a href="/primary">FID:primary-card</a></h3><p>FID:primary-summary</p></article></section>
        <section><h2>FID:secondary</h2><article><h3><a href="/secondary">FID:secondary-card</a></h3><p>FID:secondary-summary</p></article></section>
      </main>
      <aside>#{Array.new(8) { |index| "<a href=\"/rail-#{index}\">FID:rail-#{index}</a>" }.join}</aside>
    HTML

    with_url_page('https://fidelity.test/sections', html) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('FID:primary', 'FID:secondary')
      expect(result['markdown']).not_to include('FID:rail-0', 'FID:chrome-header')
    end
  end

  it 'preserves named sections made from post and entry cards' do
    html = <<~HTML
      <main><h1>FID:post-entry-sections</h1>
        <section><h2>FID:post-section</h2>
            <div class="post"><a href="/post-one">FID:post-one-title with sufficient text</a><p>FID:post-one-summary</p>
            <span class="item-meta"><h4><a rel="author" href="/authors/post-one">FID:post-one-author</a></h4></span>
            <div class="entry"><a href="/post-nested">FID:post-nested-title with sufficient text</a></div>
          </div>
          <div class="post"><a href="/post-two">FID:post-two-title with sufficient text</a></div>
        </section>
        <section><h2>FID:entry-section</h2>
          <div class="entry"><h3><a href="/entry-one">FID:entry-one-title</a></h3><p>FID:entry-one-summary</p></div>
          <div class="entry"><a href="/entry-two">FID:entry-two-title with sufficient text</a></div>
        </section>
        <section><h2>FID:row-section</h2><table><tbody><tr>
          <td><div class="entry"><a href="/row-one">FID:row-one-title with sufficient text</a></div></td>
          <td>FID:row-one-context</td>
        </tr></tbody></table></section>
      </main>
    HTML

    with_url_page('https://fidelity.test/post-entry-sections', html) do |page|
      result = extract_payload(page, reader_mode: false)
      markdown = result['markdown']

      expect(result['contentType']).to eq('list')
      expect(markdown).to include(
        '## FID:post-section', 'FID:post-one-summary', 'FID:post-nested-title', 'FID:post-two-title',
        '## FID:entry-section', 'FID:entry-one-summary', 'FID:entry-two-title',
        '## FID:row-section', 'FID:row-one-title', 'FID:row-one-context'
      )
      expect(markdown.scan(/^- \[/).length).to eq(6)
      expect(markdown.index('FID:post-one-title')).to be < markdown.index('FID:post-nested-title')
      expect(markdown.index('## FID:post-section')).to be < markdown.index('## FID:entry-section')
    end
  end

  it 'deduplicates responsive cards across named sections in production extraction' do
    with_url_page('https://fidelity.test/', fixture('fidelity_generic_cross_section_duplicate')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown'].scan('FID:shared-earliest').length).to eq(1)
      expect(result['markdown']).to include('FID:shared-earliest', 'FID:earliest-summary', 'FID:unique-story')
      expect(result['markdown']).not_to include('FID:shared-responsive-copy', 'FID:later-summary')
    end
  end

  it 'keeps nested card evidence within the accepted card boundary' do
    with_url_page('https://fidelity.test/', fixture('fidelity_generic_nested_card')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('FID:inner-title', 'FID:inner-summary', 'FID:inner-image', 'FID:inner-time')
      expect(result['markdown']).not_to include('FID:outer-action', 'FID:outer-summary', 'FID:outer-image')
    end
  end

  it 'recognizes mixed-case CSS module cards without splitting presentation wrappers' do
    cards = (1..12).map do |index|
      <<~HTML
        <div class="GridItem-styles__GridItemStyled">
          <div class="IndexCard-styles__IndexCardStyled">
            <img src="/images/#{index}.jpg" alt="FID:module-image-#{index}">
            <div class="Promo-styles__CardStyled">
              <div class="IndexCardHeading-styles__TitleGravityWrapper">
                <div class="IndexCardHeading-styles__TitleWrapperStyled">
                  <h3 class="IndexCardHeading-styles__CardHeadlineStyled"><a href="/news/#{index}">FID:module-title-#{index}</a></h3>
                </div>
              </div>
              <p>FID:module-summary-#{index}</p>
              <span class="CardMetadata-styles__MetaStyled">FID:module-meta-#{index}</span>
            </div>
          </div>
        </div>
      HTML
    end
    html = <<~HTML
      <main>
        <h1>FID:mixed-case-module-cards</h1>
        <div class="IndexPage-styles__IndexPageArticleStyled">
          <section><h2>FID:module-section-one</h2>#{cards.first(6).join}</section>
          <section><h2>FID:module-section-two</h2>#{cards.last(6).join}</section>
        </div>
      </main>
    HTML

    with_url_page('https://fidelity.test/news', html) do |page|
      result = extract_payload(page, reader_mode: false)
      lines = result['markdown'].lines.grep(/^- \[/)

      expect(result['contentType']).to eq('list')
      expect(lines.length).to eq(12)
      lines.each_with_index do |line, index|
        record = index + 1
        expect(line).to include(
          "FID:module-title-#{record}", "FID:module-summary-#{record}",
          "FID:module-meta-#{record}"
        )
        expect(line).not_to include("FID:module-summary-#{record == 12 ? 11 : record + 1}")
      end
    end
  end

  it 'keeps sibling anchor-wrapped records within their own cards' do
    titles = ['FID:short-one'] + (2..6).map { |index| "FID:direct-record-#{index}" }
    records = (1..6).map do |index|
      title = titles[index - 1]
      <<~HTML
        <a class="record-tile" href="/records/#{index}" title="#{title}">
          <img src="/records/#{index}.jpg" alt="FID:direct-image-#{index}">
          <span class="record-title">#{title}</span>
          <span class="record-age">FID:direct-age-#{index}</span>
          <span class="record-views">FID:direct-views-#{index}</span>
        </a>
      HTML
    end.join
    html = <<~HTML
      <main>
        <h1>FID:direct-anchor-records</h1>
        <div class="items">#{records}</div>
      </main>
    HTML

    with_url_page('https://fidelity.test/archive', html) do |page|
      result = extract_payload(page, reader_mode: false)
      lines = result['markdown'].lines.grep(/^- \[/)

      expect(result['contentType']).to eq('list')
      expect(lines.length).to eq(6)
      lines.each_with_index do |line, index|
        record = index + 1
        expect(line).to include(titles[index], "FID:direct-age-#{record}", "FID:direct-views-#{record}")
        expect(line.scan(titles[index]).length).to eq(1)
        expect(line).not_to include(titles[record == 6 ? 4 : record])
      end
    end
  end

  it 'keeps list metadata within an outer card instead of inheriting nested-card context' do
    with_url_page('https://fidelity.test/', fixture('fidelity_card_metadata_ownership')) do |page|
      result = extract_payload(page)

      expect(result['markdown']).to include('FID:outer-title', 'FID:outer-author', 'FID:outer-time', 'FID:outer-score', 'FID:outer-replies', 'FID:outer-community')
      expect(result['markdown']).not_to include('FID:nested-author', 'FID:nested-time', 'FID:nested-score', 'FID:nested-replies', 'FID:nested-community')
    end
  end

  it 'does not treat high-link sidebar sections as editorial coverage' do
    with_url_page('https://fidelity.test/', fixture('fidelity_generic_sidebar_sections')) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('FID:primary-title', 'FID:secondary-title')
      expect(result['markdown']).not_to include('FID:rail-0', 'FID:popular')
    end
  end

  it 'preserves all cards while letting the earliest canonical card win' do
    html = <<~HTML
      <main><h1>FID:portal</h1>
        <section><h2>FID:first</h2>
          #{(1..3).map { |index| "<article><h3><a href=\"/story/#{index}\">FID:first-#{index}</a></h3></article>" }.join}
          <article><h3><a href="/story/later">FID:over-quota-later</a></h3></article>
        </section>
        <section><h2>FID:second</h2>
          <article><h3><a href="/story/later">FID:later-emitted</a></h3><p>FID:later-summary</p></article>
          <article><h3><a href="/story/unique-later">FID:unique-later</a></h3></article>
        </section>
      </main>
    HTML

    with_url_page('https://fidelity.test/', html) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('FID:over-quota-later', 'FID:unique-later')
      expect(result['markdown']).not_to include('FID:later-emitted', 'FID:later-summary')
    end
  end

  it 'collapses tracking duplicates but preserves meaningful query-distinct cards' do
    html = <<~HTML
      <main><h1>FID:portal</h1>
        <section><h2>FID:tracking</h2>
          <article><h3><a href="/story/tracked">FID:tracked-first</a></h3></article>
          <article><h3><a href="/story/query?page=1">FID:query-one</a></h3></article>
        </section>
        <section><h2>FID:responsive</h2>
          <article><h3><a href="/story/tracked?utm_source=mobile">FID:tracked-copy</a></h3></article>
          <article><h3><a href="/story/query?page=2">FID:query-two</a></h3></article>
        </section>
      </main>
    HTML

    with_url_page('https://fidelity.test/', html) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('FID:tracked-first', 'FID:query-one', 'FID:query-two')
      expect(result['markdown']).not_to include('FID:tracked-copy')
    end
  end

  it 'uses the shared portal section collector and retains the flat fallback' do
    sectioned = fixture('fidelity_portal_sections')
    with_url_page('https://fidelity.test/', sectioned) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('## FID:world', '## FID:business', 'FID:world-summary')
    end

    flat = <<~HTML
      <main><h1>FID:flat-portal</h1>
        <article><h2><a href="/flat-one">FID:flat-one</a></h2><p>FID:flat-one-summary</p></article>
        <article><h2><a href="/flat-two">FID:flat-two</a></h2><p>FID:flat-two-summary</p></article>
      </main>
    HTML
    with_url_page('https://fidelity.test/', flat) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['markdown']).to include('FID:flat-one', 'FID:flat-two')
    end
  end

  it 'keeps flat list introductions without repeating card-local descriptions' do
    cards = Array.new(5) do |index|
      number = index + 1
      <<~HTML
        <article>
          <h2><a href="/flat-#{number}">FID:flat-card-#{number} with sufficient title</a></h2>
          <p>FID:flat-card-#{number}-summary with enough local context.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <main>
        <h1>FID:flat-portal</h1>
        <p>FID:flat-introduction explains the complete visible collection.</p>
        <div class="records">#{cards}</div>
      </main>
    HTML

    with_url_page('https://fidelity.test/', html) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      expect(result['markdown'].scan('FID:flat-introduction').length).to eq(1)
      expect(result['markdown'].scan('FID:flat-card-1-summary').length).to eq(1)
    end
  end

  it 'uses one post and entry boundary for flat list context' do
    remaining_cards = (2..8).map do |number|
      card_class = number.even? ? 'entry' : 'post'
      <<~HTML
        <li>
          <div class="#{card_class}">
            <h2><a href="/record-#{number}">FID:record-#{number} with sufficient title</a></h2>
            <span class="summary">FID:record-#{number}-summary with enough local context.</span>
          </div>
        </li>
      HTML
    end.join
    html = <<~HTML
      <main class="entry">
        <h1>FID:post-entry-portal</h1>
        <a href="/about">About</a>
        <p>FID:post-entry-introduction explains the complete visible collection.</p>
        <ul class="records itemlist">
          <li>
            <div class="post">
              <div class="card-body">
                <h2><a href="/record-outer">FID:outer-post with sufficient title</a></h2>
                <p>FID:outer-post-summary with enough local context.</p>
                <span class="status">FID:outer-post-status-open</span>
              </div>
              <span class="item-meta">
                <h4><a rel="author" href="/authors/outer">FID:outer-post-author</a></h4>
                <time datetime="2026-08-29">FID:outer-post-time</time>
              </span>
              <div class="entry">
                <h3><a href="/record-nested">FID:nested-entry with sufficient title</a></h3>
                <p>FID:nested-entry-summary with enough local context.</p>
              </div>
            </div>
          </li>
          <li>
            <div class="post">
              <div class="entry">
                <h2><a href="/record-wrapped">FID:wrapped-entry with sufficient title</a></h2>
                <ul class="attributes">
                  <li>Annual results remain visible.</li>
                  <li>FID:wrapped-entry-location-oslo</li>
                </ul>
              </div>
              <span class="author"><h4><a rel="author" href="/authors/ann">Ann</a></h4></span>
              <span class="author duplicate"><a rel="author" href="/authors/ann">Ann</a></span>
              <time datetime="2026-09-01">FID:wrapped-entry-time</time>
              <time class="duplicate" datetime="2026-09-01">FID:wrapped-entry-time</time>
            </div>
          </li>
          <li><div class="item-content"><h2><a href="/record-item-content">FID:item-content with sufficient title</a></h2><p>FID:item-content-summary with enough local context.</p><figure><img src="javascript:unsafeImage()" alt="FID:unsafe-image-alt"><figcaption>FID:unsafe-image-caption</figcaption></figure></div></li>
          <li><div class="post-content"><h2><a href="/record-post-content">FID:post-content with sufficient title</a></h2><p>FID:post-content-summary with enough local context.</p></div></li>
          <li><div class="entry-content"><h2><a href="/record-entry-content">FID:entry-content with sufficient title</a></h2><p>FID:entry-content-summary with enough local context.</p></div></li>
          #{remaining_cards}
        </ul>
      </main>
    HTML

    with_url_page('https://fidelity.test/archive', html) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('list')
      expect(result['markdown']).to include('- [FID:outer-post with sufficient title]')
      expect(result['markdown'].scan('FID:post-entry-introduction').length).to eq(1)
      expect(result['markdown'].scan('FID:outer-post-summary').length).to eq(1)
      expect(result['markdown'].scan('FID:outer-post-author').length).to eq(1)
      expect(result['markdown'].scan('2026-08-29').length).to eq(1)
      expect(result['markdown'].scan('FID:outer-post-status-open').length).to eq(1)
      expect(result['markdown'].scan('FID:nested-entry-summary').length).to eq(1)
      expect(result['markdown']).to include('FID:wrapped-entry with sufficient title', 'Ann', '2026-09-01')
      expect(result['markdown'].scan(/\bAnn\b/).length).to eq(1)
      expect(result['markdown'].scan('2026-09-01').length).to eq(1)
      expect(result['markdown'].scan('Annual results remain visible.').length).to eq(1)
      expect(result['markdown'].scan('FID:wrapped-entry-location-oslo').length).to eq(1)
      expect(result['markdown']).to include('FID:item-content-summary', 'FID:post-content-summary', 'FID:entry-content-summary')
      expect(result['markdown'].scan('FID:unsafe-image-caption').length).to eq(1)
      expect(result['markdown']).not_to include('javascript:unsafeImage')
      expect(result['markdown'].scan(/^- \[/).length).to eq(13)
      expect(result['markdown'].index('FID:outer-post with sufficient title')).to be < result['markdown'].index('FID:outer-post-summary')
      expect(result['markdown'].index('FID:outer-post-summary')).to be < result['markdown'].index('FID:nested-entry with sufficient title')
      expect(result['markdown'].index('FID:nested-entry with sufficient title')).to be < result['markdown'].index('FID:nested-entry-summary')
    end
  end

  it 'does not section-extract a long article with many paragraphs' do
    paragraphs = Array.new(8) { |index| "<p>FID:article-paragraph-#{index} #{"substantive article text " * 12}</p>" }.join
    html = <<~HTML
      <article><h1>FID:long-article</h1><div itemprop="articleBody">#{paragraphs}</div>
        <section><h2>FID:related-one</h2><article><h3><a href="/related-one">FID:related-card-one</a></h3></article></section>
        <section><h2>FID:related-two</h2><article><h3><a href="/related-two">FID:related-card-two</a></h3></article></section>
      </article>
    HTML

    with_url_page('https://fidelity.test/articles/long', html) do |page|
      result = extract_payload(page, reader_mode: false)

      expect(result['contentType']).to eq('article')
      expect(result['markdown']).to include('FID:article-paragraph-0')
      expect(result['markdown']).not_to include('## FID:related-one')
    end
  end

  it 'rejects correct-type long arbitrary links on coverage and context' do
    markdown = Array.new(12) do |index|
      "- [FID:arbitrary-#{index}](https://fidelity.test/random/#{index})\n  #{"plausible unrelated prose " * 8}"
    end.join("\n\n")
    result = ContentFidelity.match(payload(markdown), portal_contract)

    expect(markdown.length).to be > 500
    expect(result.failures).to include(:region_coverage, :context_ratio, :focal_coverage)
  end

  it 'detects reversed focal cards by ordered item ratio' do
    contract = portal_contract
    markdown = ['# FID:portal', '## FID:world', '## FID:business', '## FID:sport', *contract.items.reverse.map { |item| card(item) }].join("\n\n")
    result = ContentFidelity.match(payload(markdown), contract)

    expect(result.failures).to include(:ordered_item_ratio)
  end

  it 'detects duplicate responsive focal cards by canonical duplicate ratio' do
    contract = portal_contract
    cards = contract.items.map { |item| card(item) }
    markdown = ['# FID:portal', '## FID:world', cards[0], cards[0], '## FID:business', cards[1], '## FID:sport', cards[2]].join("\n\n")
    result = ContentFidelity.match(payload(markdown), contract)

    expect(result.failures).to include(:duplicate_ratio)
  end

  it 'detects a removed named section heading' do
    contract = portal_contract
    cards = contract.items.map { |item| card(item) }
    markdown = ['# FID:portal', '## FID:world', cards[0], cards[1], '## FID:sport', cards[2]].join("\n\n")
    result = ContentFidelity.match(payload(markdown), contract)

    expect(result.failures).to include(:section_coverage)
  end

  it 'detects sidebar dominance by chrome leakage and missing primary regions' do
    sidebar_cards = Array.new(8) { |index| "[FID:sidebar-#{index}](https://fidelity.test/sidebar/#{index})" }.join("\n")
    markdown = "# FID:portal\n\nFID:chrome-sidebar\n\n#{sidebar_cards}"
    result = ContentFidelity.match(payload(markdown), portal_contract)

    expect(result.failures).to include(:chrome_hits, :region_coverage)
  end

  it 'detects header and footer precedence by chrome, context, and focal coverage' do
    header_links = Array.new(5) { |index| "[FID:header-#{index}](https://fidelity.test/header/#{index})" }.join("\n")
    markdown = "FID:chrome-header\n\n#{header_links}\n\nFID:chrome-footer"
    result = ContentFidelity.match(payload(markdown), portal_contract)

    expect(result.failures).to include(:chrome_hits, :context_ratio, :focal_coverage)
  end
end
