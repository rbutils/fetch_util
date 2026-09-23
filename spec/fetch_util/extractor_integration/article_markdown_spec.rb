# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "preserves collected site metadata in fallback article extraction" do
    body = ("Detailed reporting preserves the publication identity while explaining the public record. " * 8).strip
    html = <<~HTML
      <html>
        <head>
          <title>Fallback metadata report</title>
          <meta property="og:site_name" content="Reports Journal">
        </head>
        <body><main><article><h1>Fallback metadata report</h1><p>#{body}</p></article></main></body>
      </html>
    HTML

    source_snapshot = lambda do |page|
      page.evaluate(<<~JS)
        (() => {
          const head = document.head.cloneNode(true);
          head.querySelectorAll("script").forEach((node) => node.remove());
          return {
            htmlAttributes: Array.from(document.documentElement.attributes).map((attribute) => [attribute.name, attribute.value]),
            head: head.innerHTML,
            body: document.body.outerHTML
          };
        })()
      JS
    end

    with_url_page("https://reports.example/story", html) do |page|
      before = source_snapshot.call(page)
      payload = extract_payload(page, reader_mode: false)

      expect(payload).to include(
        "siteName" => "Reports Journal",
        "contentType" => "article",
        "readerMode" => false
      )
      expect(payload.fetch("markdown")).to include("Detailed reporting preserves the publication identity")
      expect(source_snapshot.call(page)).to eq(before)
    end

    without_site_name = html.sub('<meta property="og:site_name" content="Reports Journal">', '')
    with_url_page("https://reports.example/story", without_site_name) do |page|
      before = source_snapshot.call(page)
      expect(extract_payload(page, reader_mode: false)).to include("siteName" => "reports.example")
      expect(source_snapshot.call(page)).to eq(before)
    end
  end

  it "uses the first substantial cleaned body paragraph as the fallback excerpt" do
    opening = "The verified opening paragraph cites Jane Doe as a source and explains the public record, the " \
      "decisions made by local officials, and the evidence available to residents without repeating page chrome."
    continuation = "The second paragraph preserves the remaining testimony, dates, and practical context needed " \
      "to understand how the reported changes affect the surrounding community."
    html = <<~HTML
      <html>
        <head>
          <title>Fallback excerpt report</title>
          <meta name="description" content="Promotional metadata that is not visible in the article body.">
        </head>
        <body>
          <main>
            <article class="privacy">
              <h1>Fallback excerpt report</h1>
              <p class="article-author"><a rel="author" href="/authors/verified-reporter">Verified Reporter writes this report for the journal.</a></p>
              <header><p>An unlabelled publication header contains enough text to look substantial but does not own the report body or its evidence.</p></header>
              <div class="siteHeader"><p>Site header notices contain lengthy account and subscription information that should not become an article excerpt.</p></div>
              <div itemprop="author"><p>A semantic author biography contains enough background information to exceed the paragraph threshold but is not body prose.</p></div>
              <div class="navigation"><p>A navigation summary contains enough explanatory text to exceed the paragraph threshold but is not body prose.</p></div>
              <address><p>A semantic contact block contains a long biography and publication address that must not become the report excerpt.</p></address>
              <div class="masthead"><p>Publication branding and membership information contains enough text to exceed the threshold but is not report prose.</p></div>
              <div role="search"><p>A search panel explains its filters and archive scope with enough text to exceed the threshold but is not report prose.</p></div>
              <section class="recommended-stories"><p>A recommended story summary contains enough text to exceed the threshold but belongs to another report.</p></section>
              <div class="cookie-notice" data-nosnippet="true"><p>#{opening}</p></div>
              <aside class="related"><p>Related coverage provides a long but separate summary that must not become the article excerpt. Related coverage provides more context.</p></aside>
              <p>Short standfirst.</p>
              <p>The verified opening paragraph cites <a rel="author" href="/authors/jane-doe">Jane Doe</a> as a source and explains the public record, the decisions made by local officials, and the evidence available to residents without repeating page chrome.</p>
              <p>#{continuation}</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://reports.example/fallback-excerpt", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page, reader_mode: false)

      expect(payload.fetch("excerpt")).to eq("#{opening} #{continuation}"[0, 280])
      expect(payload.fetch("excerpt")).not_to include("Fallback excerpt report", "Verified Reporter", "Related coverage", "Promotional metadata")
      expect(payload.fetch("markdown")).to include(
        "[Jane Doe](https://reports.example/authors/jane-doe)",
        continuation.strip
      )
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "preserves non-Latin body leads and the prior fallback when no paragraph qualifies" do
    non_latin_lead = "這段經過核實的開場內容說明公共紀錄、地方官員作出的決定，以及居民可以查閱的證據，並保留理解這份報告所需的日期、背景和實際影響。" * 2
    with_url_page("https://reports.example/non-latin-excerpt", <<~HTML) do |page|
      <main><article><h1>公共紀錄報告</h1><p>#{"😀" * 79}</p><div itemprop="description"><p>#{non_latin_lead}</p></div></article></main>
    HTML
      expect(extract_payload(page, reader_mode: false).fetch("excerpt")).to eq(non_latin_lead[0, 280])
    end

    legacy_text = "Legacy fallback text remains available when the cleaned article has no substantial paragraph. " * 5
    with_url_page("https://reports.example/legacy-excerpt", <<~HTML) do |page|
      <main><article><h1>Legacy fallback title</h1><div>#{legacy_text}</div><p>Short body.</p></article></main>
    HTML
      payload = extract_payload(page, reader_mode: false)
      expect(payload.fetch("excerpt")).to start_with("Legacy fallback titleLegacy fallback text")
      expect(payload.fetch("excerpt").length).to eq(280)
    end

    with_url_page("https://reports.example/astral-fallback", <<~HTML) do |page|
      <main><article><h1>Astral fallback</h1><div>#{"😀" * 300}</div></article></main>
    HTML
      excerpt = extract_payload(page, reader_mode: false).fetch("excerpt")
      expect(excerpt.each_char.count).to eq(280)
      expect(excerpt).to end_with("😀")
    end
  end

  it "accepts explicit article header leads but rejects unlabelled header prose" do
    lead = "This explicit standfirst explains the verified findings, their public impact, and the evidence readers need before the detailed report begins."
    with_url_page("https://reports.example/header-lead", <<~HTML) do |page|
      <main>
        <article>
          <header>
            <h1>Header lead report</h1>
            <p>An unlabelled publication line contains enough words to exceed the threshold but has no lead ownership.</p>
            <div class="article-standfirst"><p>#{lead}</p></div>
          </header>
          <p>The detailed body continues with enough verified evidence and context to qualify as substantial article prose.</p>
        </article>
      </main>
    HTML
      expect(extract_payload(page, reader_mode: false).fetch("excerpt")).to eq(lead)
    end

    with_url_page("https://reports.example/header-owned-lead", <<~HTML) do |page|
      <main>
        <article>
          <header class="article-standfirst">
            <h1>Header-owned lead report</h1>
            <p>#{lead}</p>
          </header>
          <p>The detailed body continues with enough verified evidence and context to qualify as substantial article prose.</p>
        </article>
      </main>
    HTML
      expect(extract_payload(page, reader_mode: false).fetch("excerpt")).to eq(lead)
    end
  end

  it "prefers a visible metadata summary over a flattened short reader excerpt" do
    description = "Diabetes is a long-lasting health condition that affects how the body turns food into energy."
    body = "#{description} This overview explains prevention, diagnosis, treatment, and community support. " * 5
    html = <<~HTML
      <html><head>
        <title>About diabetes</title>
        <meta name="description" content="#{description}">
      </head><body><main><article>
        <h1>About diabetes</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <h2>For Everyone</h2>
        <p>#{body}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/about-diabetes", html) do |page|
      payload = extract_payload(page, reader_mode: true)

      expect(payload["excerpt"]).to eq(description)
      expect(payload["excerpt"]).not_to end_with("bod")
    end
  end

  it "expands a short reader excerpt from one substantive body block" do
    lead = ("The health overview explains prevention, diagnosis, treatment, and community support for people living with chronic conditions. " * 4).strip
    html = <<~HTML
      <html><head><title>Community health overview</title></head><body><main><article>
        <h1>Community health overview</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <h2>For Everyone</h2>
        <p>#{lead}</p>
        <p>Additional guidance explains how residents can find local services and evidence-based care.</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/community-overview", html) do |page|
      excerpt = extract_payload(page, reader_mode: true).fetch("excerpt")

      expect(excerpt).to start_with("The health overview explains prevention")
      expect(excerpt.length).to be <= 280
      expect(lead).to start_with(excerpt)
      expect(excerpt).to end_with(/[.!?]/)
    end
  end

  it "prefers repeated compact CJK body paragraphs over a taxonomy-only reader excerpt" do
    first = "地域の皆さまへ向けて今夏の公開資料を詳しく紹介します。必要な背景と確認方法を説明します。"
    second = "公開資料には重要な日程や担当部署の記録が含まれています。住民の皆さまも内容を確認できます。"
    paragraphs = (1..6).map { |index| "<p>#{index}回目の報告では追加の資料と公開記録を紹介します。自治体が説明会で回答した内容も含みます。</p>" }.join
    html = <<~HTML
      <html><head><title>公開記録の案内</title></head><body><main><article>
        <h1>公開記録の案内</h1><div class="entry-themes">テーマ：地域の活動</div>
        <div id="entryBody"><p>#{first}</p><p>#{second}</p><h2>公開資料について</h2>#{paragraphs}</div>
      </article></main></body></html>
    HTML

    with_url_page("https://journal.example/entries/public-records", html) do |page|
      payload = extract_payload(page, reader_mode: true)

      expect(payload.fetch("excerpt")).to start_with(first)
      expect(payload.fetch("excerpt")).to include(second)
      expect(payload.fetch("excerpt")).not_to include("テーマ：")
      expect(payload.fetch("markdown")).to include("公開資料について", "6回目の報告")
    end
  end

  it "derives a structured div article excerpt from its body instead of category metadata" do
    lead = "The structured report explains the source-backed policy changes, implementation evidence, and practical consequences for affected communities."
    html = <<~HTML
      <html><head><title>Structured energy report | Example News</title>
        <script type="application/ld+json">{
          "@context":"https://schema.org",
          "@type":"NewsArticle",
          "url":"https://example.test/reports/structured-energy",
          "headline":"Structured energy report"
        }</script>
      </head><body><main>
        <div class="article">
          <div class="print-branding-header"><img alt="Example News" src="/brand.svg"></div>
          <div class="top-part"><h1>Structured energy report</h1><div class="meta"><span class="categories">Green Economy</span> <span>News</span> <span class="date-time">7 July 2026 15:56 (UTC +04:00)</span></div></div>
          <div class="left-part"><div class="sticky-content"></div></div>
          <div class="right-part">
            <div class="image-wrapper"><img alt="Structured energy project" src="/energy.jpg"></div>
            <div class="article-paddings"><span class="author">Example Economics Correspondent</span></div>
            <div class="article-content article-paddings">
              <p>#{lead}</p>
              <p>Additional evidence describes the implementation timeline, independent review, and regional cooperation in sufficient detail.</p>
            </div>
          </div>
          <div class="print-branding-footer"><p>Source: https://example.test/reports/structured-energy</p></div>
        </div>
        <article class="related"><h2>Related report</h2><p>This separate article card must not disqualify the uniquely structured current-page article body.</p></article>
      </main></body></html>
    HTML

    with_url_page("https://example.test/reports/structured-energy", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page, reader_mode: true)

      expect(payload.fetch("excerpt")).to eq(lead)
      expect(payload.fetch("excerpt")).not_to include("Green Economy")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "does not let foreign structured data change an ordinary div article excerpt" do
    lead = "The unstructured report contains a substantial paragraph, but its broad layout provides no unique current-page article provenance."
    html = <<~HTML
      <html><head><title>Unstructured energy report | Example News</title>
        <script type="application/ld+json">{
          "@context":"https://schema.org",
          "@type":"NewsArticle",
          "url":"https://other.example.test/reports/unstructured-energy",
          "headline":"Unstructured energy report"
        }</script>
      </head><body><main>
        <div class="article">
          <div class="print-branding-header"><img alt="Example News" src="/brand.svg"></div>
          <div class="top-part"><h1>Unstructured energy report</h1><div class="meta"><span class="categories">Green Economy</span> <span>News</span> <span class="date-time">7 July 2026 15:56 (UTC +04:00)</span></div></div>
          <div class="left-part"><div class="sticky-content"></div></div>
          <div class="right-part">
            <div class="image-wrapper"><img alt="Unstructured energy project" src="/energy.jpg"></div>
            <div class="article-paddings"><span class="author">Example Economics Correspondent</span></div>
            <div class="article-content article-paddings"><p>#{lead}</p><p>Another substantial paragraph provides enough text for reader extraction without proving its ownership.</p></div>
          </div>
          <div class="print-branding-footer"><p>Source: https://example.test/reports/unstructured-energy</p></div>
        </div>
        <article class="related"><h2>Related report</h2><p>This separate article card keeps ordinary main ownership intentionally ambiguous.</p></article>
      </main></body></html>
    HTML

    with_url_page("https://example.test/reports/unstructured-energy", html) do |page|
      payload = extract_payload(page, reader_mode: true)

      expect(payload.fetch("excerpt")).to eq(lead)
      expect(payload.fetch("html")).not_to include("data-fetchutil-excerpt-")
    end
  end

  it "prefers an explicit article summary list over later body sections" do
    first = "Diabetes is a chronic condition that affects how the body turns food into energy."
    second = "There are three main types of diabetes, and each type requires appropriate care."
    html = <<~HTML
      <html><head><title>Diabetes basics</title></head><body><main><article>
        <h1>Diabetes basics</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <section data-section="diabetes_page_summary"><h2>Key points</h2><ul><li>#{first}</li><li>#{second}</li></ul></section>
        <section><h2>Overview</h2><p>The later overview explains insulin, blood sugar, prevention, treatment, and long-term care in detail.</p></section>
        <p>#{"Additional guidance explains prevention, diagnosis, treatment, and community services in detail. " * 5}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/diabetes-basics", html) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page, reader_mode: true)

      expect(payload.fetch("excerpt")).to eq("#{first} #{second}")
      expect(payload.fetch("html")).not_to include("data-fetchutil-excerpt-")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end

  it "does not promote metadata found only in related or caption content" do
    description = "Related material repeats this metadata summary."
    body = "The owned report explains prevention, diagnosis, treatment, and community support in one complete paragraph."
    html = <<~HTML
      <html><head><title>Owned health report</title><meta name="description" content="#{description}"></head>
      <body><main><article><h1>Owned health report</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <aside class="related"><p>#{description}</p></aside>
        <figure><figcaption><p>#{description}</p></figcaption></figure>
        <div id="related-promotion"><p>#{description}</p></div>
        <div data-component="recommendedContent"><p>#{description}</p></div>
        <p>Intro: #{description} Extra.</p>
        <p>#{body}</p>
        <p>#{"Additional evidence explains prevention, diagnosis, treatment, and community services in detail. " * 5}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/owned-report", html) do |page|
      expect(extract_payload(page, reader_mode: true).fetch("excerpt")).to eq(body)
    end
  end

  it "does not derive an excerpt from body prose without article ownership" do
    body = ("A generic widget explains unrelated account alerts, preferences, and promotional choices. " * 5).strip
    html = <<~HTML
      <html><head><title>Account information</title></head><body>
        <h1>Account information</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <div><p>#{body}</p></div>
      </body></html>
    HTML

    with_url_page("https://example.test/account/information", html) do |page|
      expect(extract_payload(page, reader_mode: true).fetch("excerpt")).to eq("Jan. 2, 2026, visit link for details.")
    end
  end

  it "does not derive an excerpt from an unowned widget inside an article" do
    widget = ("A generic widget explains unrelated account alerts, preferences, and promotional choices. " * 5).strip
    body = ("The owned report explains prevention, diagnosis, treatment, and community support. " * 5).strip
    html = <<~HTML
      <html><head><title>Owned report</title></head><body><main><article>
        <h1>Owned report</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <div><p>#{widget}</p></div>
        <p>#{body}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/reports/owned", html) do |page|
      expect(extract_payload(page, reader_mode: true).fetch("excerpt")).to start_with("The owned report explains")
    end
  end

  it "ignores explicit summary containers hidden by attributes or inline styles" do
    hidden = "Hidden summary text must not become the public article excerpt."
    body = "The visible report explains prevention, diagnosis, treatment, and community support in one complete paragraph."
    html = <<~HTML
      <html><head><title>Visible health report</title><style>.css-hidden-summary { display: none }</style></head><body><main><article>
        <h1>Visible health report</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <section data-section="summary" hidden><p>#{hidden}</p></section>
        <section data-section="summary" aria-hidden="true"><p>#{hidden}</p></section>
        <section data-section="summary" style="display: none"><p>#{hidden}</p></section>
        <section data-section="summary" class="css-hidden-summary"><p>#{hidden}</p></section>
        <nav data-section="summary"><p>#{hidden}</p></nav>
        <header data-section="summary"><p>#{hidden}</p></header>
        <footer data-section="summary"><p>#{hidden}</p></footer>
        <form data-section="summary"><p>#{hidden}</p></form>
        <section data-section="summary" role="complementary"><p>#{hidden}</p></section>
        <section data-section="summary" inert><p>#{hidden}</p></section>
        <section data-section="summary" style="visibility: hidden"><p>#{hidden}</p></section>
        <section data-section="summary" style="opacity: 0"><p>#{hidden}</p></section>
        <p>#{body}</p>
        <p>#{"Additional evidence explains prevention, diagnosis, treatment, and community services in detail. " * 5}</p>
        <section data-section="global_summary"><p>#{hidden} #{hidden}</p></section>
        <div class="related"><p data-fetchutil-excerpt-source="page-authored">#{hidden} #{hidden}</p></div>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/visible-report", html) do |page|
      expect(extract_payload(page, reader_mode: true).fetch("excerpt")).to eq(body)
    end
  end

  it "keeps grapheme clusters intact when bounding a long body excerpt" do
    sentence = "Families 👨‍👩‍👧‍👦 receive coordinated prevention, diagnosis, treatment, and community support. "
    html = <<~HTML
      <html><head><title>Family care report</title></head><body><main><article>
        <h1>Family care report</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <p>#{sentence * 5}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/family-care", html) do |page|
      excerpt = extract_payload(page, reader_mode: true).fetch("excerpt")

      expect(excerpt.scan(/\X/).length).to be <= 280
      expect(excerpt).to end_with("support.")
      expect(excerpt).not_to end_with("\u200D")
      expect(sentence * 5).to start_with(excerpt)
    end
  end

  it "retains the short reader excerpt when no bounded sentence or token exists" do
    html = <<~HTML
      <html><head><title>Identifier report</title></head><body><main><article>
        <h1>Identifier report</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <section data-section="summary"><p>#{"a" * 400}</p></section>
        <p>#{"a" * 400}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/identifier-report", html) do |page|
      expect(extract_payload(page, reader_mode: true).fetch("excerpt")).to eq("Jan. 2, 2026, visit link for details.")
    end
  end

  it "does not truncate long excerpts when grapheme segmentation is unavailable" do
    html = <<~HTML
      <html><head><title>Fallback report</title></head><body><main><article>
        <h1>Fallback report</h1>
        <p class="published-date">Jan. 2, 2026, visit link for details.</p>
        <p>#{"Family care 👨‍👩‍👧‍👦 remains coordinated across services. " * 10}</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/health/fallback-report", html) do |page|
      page.evaluate("Object.defineProperty(Intl, 'Segmenter', {value: undefined, configurable: true})")

      expect(extract_payload(page, reader_mode: true).fetch("excerpt")).to eq("Jan. 2, 2026, visit link for details.")
    end
  end

  it "converts tables into markdown instead of raw html" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <h1>Table Test</h1>
              <p>Reference data follows.</p>
              <table>
                <tr><th>Name</th><th>Value</th></tr>
                <tr><td>Alpha</td><td>One</td></tr>
              </table>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.pinterest.com/search/pins/?q=ruby+programming", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("| Name | Value |")
      expect(payload["markdown"]).to include("| Alpha | One |")
      expect(payload["markdown"]).not_to include("<table")
    end
  end

  it "excludes hidden article descendants while preserving restored visibility" do
    visible_prose = ("Visible reporting explains the complete public record. " * 10).strip
    restored_prose = ("Restored evidence remains available to readers. " * 4).strip
    html = <<~HTML
      <html>
        <head><title>Visibility report</title></head>
        <body>
          <main><article>
            <h1>Visibility report</h1>
            <p>#{visible_prose}</p>
            <p style="display: none">Display-hidden private draft</p>
            <section style="visibility: hidden" aria-label="Hidden summary" title="Hidden title">
              Visibility-hidden parent draft
              <p style="visibility: visible">#{restored_prose}</p>
            </section>
          </article></main>
        </body>
      </html>
    HTML

    extract_from_url("https://example.test/reports/visibility", html) do |payload|
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include(
        "Visible reporting explains the complete public record.",
        "Restored evidence remains available to readers."
      )
      expect(payload["html"]).to include("Visible reporting", "Restored evidence")
      expect([payload["markdown"], payload["html"], payload["description"]].join(" ")).not_to include(
        "Display-hidden private draft",
        "Visibility-hidden parent draft",
        "Hidden summary",
        "Hidden title"
      )
    end
  end

  it "removes undefined image placeholder text from markdown links" do
    html = <<~HTML
      <html>
        <head><title>Compound Record</title></head>
        <body>
          <main>
            <article>
              <h1>Compound Record</h1>
              <p>
                <a href="/compound.png" title="Download the structure image of undefined">
                  Download image
                </a>
              </p>
              <p><img src="/missing-alt.png" alt="undefined"></p>
              <p>The compound summary remains readable.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/compound", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("[Download image](https://example.test/compound.png)")
      expect(markdown).to include("The compound summary remains readable.")
      expect(markdown).not_to match(/undefined/i)
      expect(markdown).not_to include('"Download the structure image of')
    end
  end

  it "restricts materialized links, images, and canonical URLs to HTTP" do
    html = <<~HTML
      <html>
        <head>
          <title>Safe output links</title>
          <link rel="canonical" href="javascript:canonicalTarget()">
        </head>
        <body>
          <main><article>
            <h1>Safe output links</h1>
            <p>This article explains how public references remain useful while unsafe browser actions become plain visible text.</p>
            <p><a href="/safe-reference_(final)">Safe reference</a> and <a href="//cdn.example.test/reference" ping="javascript:trackClick()">CDN reference</a>.</p>
            <p><a href="javascript:openDialog()">Script action</a>, <a href="mailto:editor@example.test">Email action</a>, and <a href="ftp://files.example.test/report">FTP download</a>.</p>
            <p><img src="data:image/svg+xml,%3Csvg%3E%3C/svg%3E" alt="Unsafe diagram"></p>
            <p><img src="javascript:unsafeImage()" data-src="/safe-image_(final).png" srcset="data:image/png;base64,AAAA 1x, /safe-image@2x.png 2x" alt="Safe diagram"></p>
            <p style="background-image: url(javascript:unsafeStyle())">Styled text remains visible.</p>
            <object data="javascript:unsafeObject()">Object fallback remains visible.</object>
            <svg><a xlink:href="javascript:unsafeVector()"><text>Vector text remains visible.</text></a></svg>
            <video src="javascript:unsafeVideo()" poster="/safe-poster.png">
              <source src="ftp://files.example.test/video.mp4">
              <source src="/safe-video.mp4" srcset="data:image/png;base64,AAAA 1x, /images/sprite,a.png 480w, /images/zero-width.png 0w, /images/zero-density.png 0x, javascript:unsafeSource() 2x">
            </video>
          </article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/articles/safe-output", html) do |page|
      payload = extract(page)
      markdown = payload["markdown"]
      materialized_html = payload["html"]

      expect(payload["canonicalUrl"]).to eq("https://example.test/articles/safe-output")
      expect(markdown).to include(
        "[Safe reference](https://example.test/safe-reference_%28final%29)",
        "[CDN reference](https://cdn.example.test/reference)",
        "Script action",
        "Email action",
        "FTP download",
        "Unsafe diagram",
        "![Safe diagram](https://example.test/safe-image_%28final%29.png)",
        "Styled text remains visible"
      )
      expect(markdown).not_to include("javascript:", "mailto:", "ftp:", "data:image")
      expect(materialized_html).to include("Script action", "Email action", "FTP download", "Unsafe diagram")
      expect(materialized_html).to include(
        'href="https://example.test/safe-reference_%28final%29"',
        'src="https://example.test/safe-image_%28final%29.png"',
        'src="https://example.test/safe-video.mp4"',
        'srcset="https://example.test/images/sprite,a.png 480w"',
        'poster="https://example.test/safe-poster.png"'
      )
      expect(materialized_html).not_to include(
        "javascript:", "mailto:", "ftp:", "data:image", "zero-width", "zero-density", "data-lazy-src", "ping=", "xlink:href", "/articles/AAAA"
      )
    end
  end

  it "repairs a dropped leading character when card detail starts with a title word" do
    html = <<~HTML
      <html>
        <head><title>Research Reports</title></head>
        <body>
          <main>
            <section>
              <h2>Featured</h2>
              <article class="report-card">
                <h3><a href="/human-capital-report">Building Human Capital Where It Matters</a></h3>
                <p>uman capital -- people's health, skills, knowledge, and experience -- is the foundation of economic growth.</p>
                <p>This report brings new evidence on how human capital is formed.</p>
              </article>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/research", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("[Building Human Capital Where It Matters](https://example.test/human-capital-report)")
      expect(markdown).to include("Human capital -- people's health, skills, knowledge, and experience")
      expect(markdown).not_to match(/^uman capital -- people's/i)
    end
  end

  it "preserves legal citation link text with emphasized section letters" do
    html = <<~HTML
      <html>
        <head><title>Regulatory Authority</title></head>
        <body>
          <main>
            <article>
              <h1>Regulatory Authority</h1>
              <p>
                Authority: <a href="https://www.govinfo.gov/link/uscode/15/78l">78<em>l,</em></a>
                <a href="https://www.govinfo.gov/link/uscode/15/78o-4">78<em>o</em>-4</a>,
                <a href="https://www.govinfo.gov/link/uscode/15/78o-7">15 U.S.C. 78<em>o</em>-7 note</a>,
                <a href="https://www.govinfo.gov/link/uscode/15/78o78q">15 U.S.C. 78<em>o</em> 78q</a>,
                <a href="https://www.govinfo.gov/link/uscode/15/78">78</a><em>q</em>,
                and <a href="https://www.ecfr.gov/current/title-17/section-240.15">Section 240.15</a><em>l</em>-1.
              </p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.ecfr.gov/current/title-17/chapter-II/part-240", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload["markdown"]

      expect(markdown).to include("[78l,](https://www.govinfo.gov/link/uscode/15/78l)")
      expect(markdown).to include("[78o-4](https://www.govinfo.gov/link/uscode/15/78o-4)")
      expect(markdown).to include("[15 U.S.C. 78o-7 note](https://www.govinfo.gov/link/uscode/15/78o-7)")
      expect(markdown).to include("[15 U.S.C. 78o 78q](https://www.govinfo.gov/link/uscode/15/78o78q)")
      expect(markdown).to include("[78q](https://www.govinfo.gov/link/uscode/15/78)")
      expect(markdown).to include("[Section 240.15l-1](https://www.ecfr.gov/current/title-17/section-240.15)")
      expect(markdown).not_to include("78_l,_")
      expect(markdown).not_to include("78_o_")
      expect(markdown).not_to include("](https://www.govinfo.gov/link/uscode/15/78)_q_")
      expect(markdown).not_to include("_l_\\-1")
    end
  end

  it "preserves inline prose, entities, styled text, and punctuation" do
    html = <<~HTML
      <html><head><title>Inline guidance</title></head><body><main><article>
        <h1>Inline guidance</h1>
        <p>WHO says <span class="function-word">that</span> care <strong>must</strong> be available&nbsp;now, and CDC notes <em>why</em>.</p>
        <p>Use &amp; compare <span style="color:red">these results</span>: first, second, and third.</p>
        <ul><li>Keep <b>nested</b> wording.</li><li>Keep punctuation, too.</li></ul>
      </article></main></body></html>
    HTML

    %w[who.int cdc.gov].each do |host|
      with_url_page("https://#{host}/news/inline-guidance", html) do |page|
        markdown = FetchUtil::Extractor.new(reader_mode: false).extract(page)["markdown"]

        expect(markdown).to include("WHO says that care **must** be available\u00a0now, and CDC notes _why_.")
        expect(markdown).to include("Use & compare these results: first, second, and third.")
        expect(markdown).to include("Keep **nested** wording.")
      end
    end
  end

  it "rejects comment-only roots but keeps a short focal article beside longer comments" do
    comment_only = <<~HTML
      <html><head><title>Community update</title></head><body>
        <main><section class="comments"><h2>Comments</h2><p>Alice: This is the entire materialized page and a useful reply.</p>
        <p>Bob: Another reply with enough text to resemble an article.</p></section></main>
      </body></html>
    HTML
    with_url_page("https://dev.to/example/comment-only", comment_only) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload["contentType"]).not_to eq("article")
    end

    focal = <<~HTML
      <html><head><title>Community update</title></head><body><main><article>
        <h1>Community update</h1><p>The focal article body explains the release and its user impact for readers this week.</p>
        <section class="comments"><h2>Comments</h2>
          <p>Alice: This longer comment adds detailed context about how the release affects teams, migration plans, support requests, and the daily work of people who depend on this update.</p>
          <p>Bob: Another longer comment records a separate perspective on rollout timing, compatibility concerns, documentation gaps, and follow-up work that will happen after launch.</p>
          <p style="display: none">Hidden comment text must not become public extraction output even though its source text is long enough to qualify.</p>
          <div style="visibility: hidden">
            <p>Hidden parent text must not become public extraction output after clone cleanup.</p>
            <p style="visibility: visible">Restored visible comment remains available to readers and must survive extraction.</p>
          </div>
        </section>
      </article></main></body></html>
    HTML

    [false, true].each do |reader_mode|
      with_url_page("https://dev.to/example/community-update", focal) do |page|
        payload = FetchUtil::Extractor.new(reader_mode: reader_mode).extract(page)
        expect(payload["contentType"]).to eq("article")
        expect(payload["markdown"]).to include("The focal article body", "Alice: This longer comment", "Bob: Another longer comment", "Restored visible comment")
        expect(payload["markdown"]).not_to include("Hidden comment text", "Hidden parent text")
      end
    end
  end

  it "prepends the page title when generic article markdown starts mid-content" do
    html = <<~HTML
      <html>
        <head><title>Definition of STEWARDESS</title></head>
        <body>
          <main>
            <article>
              <a href="/simple/stewardess">Simplify</a>
              <p><strong>:</strong> a woman who performs the duties of a steward</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to start_with("# Definition of STEWARDESS")
      expect(payload["markdown"]).to include("a woman who performs the duties of a steward")
    end
  end

  it "extracts compact non-Latin AMP article bodies from generic mobile CMS containers" do
    html = <<~HTML
      <html lang="zh-CN">
        <head><title>城市更新项目进入新阶段</title></head>
        <body>
          <header><nav><a href="/">首页</a><a href="/news">新闻</a></nav></header>
          <main>
            <div class="amp-wp-article-content mobile-article-body">
              <h1>城市更新项目进入新阶段</h1>
              <p>多个社区将启动公共空间改造，居民代表参与方案讨论。</p>
              <p>项目团队表示，改造重点包括步行环境、绿化设施和夜间照明。</p>
              <p>相关部门将在下周公布施工安排，尽量减少对周边学校和商户的影响。</p>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.cn/amp/news/city-renewal-2026.html", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("城市更新项目进入新阶段")
      expect(payload["markdown"]).to include("公共空间改造")
      expect(payload["warnings"]).not_to include("short_extraction")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "extracts international visible bylines and published dates" do
    html = <<~HTML
      <html lang="es">
        <head><title>El barrio estrena biblioteca comunitaria</title></head>
        <body>
          <main>
            <article>
              <h1>El barrio estrena biblioteca comunitaria</h1>
              <p class="autor">Por María García</p>
              <p class="fecha-publicacion">8 julio 2026</p>
              <p>La nueva biblioteca comunitaria abrió sus puertas con talleres de lectura para familias y estudiantes.</p>
              <p>Vecinos y docentes colaboraron durante meses para reunir libros, preparar actividades y organizar horarios de atención.</p>
              <p>El municipio explicó que el espacio también funcionará como punto de encuentro para proyectos culturales del distrito.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.es/cultura/biblioteca-comunitaria", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["byline"]).to eq("María García")
      expect(payload["publishedTime"]).to eq("8 julio 2026")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
    end
  end

  it "uses an author-name field without sibling contact controls" do
    html = <<~HTML
      <html><head><title>Regional reporting update</title></head><body><main><article>
        <h1>Regional reporting update</h1>
        <div class="author-meta">
          <a class="author-name" href="/authors/regional-desk">Regional Desk</a>
          <a class="author-email-link" href="mailto:desk@example.test">
            <span class="screen-reader-text">Send an email</span>
          </a>
        </div>
        <p>The regional desk published a substantive report about public infrastructure and community services.</p>
        <p>The article contains enough independently owned prose to exercise normal article extraction behavior.</p>
        <p>Sibling contact controls remain interface actions rather than part of the author's displayed name.</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/news/regional-update", html) do |page|
      payload = extract(page)

      expect(payload["byline"]).to eq("Regional Desk")
      expect(payload["byline"]).not_to include("Send an email")
    end
  end

  it "does not collapse multiple named authors to the first field" do
    html = <<~HTML
      <html><head><title>Joint reporting update</title></head><body><main><article>
        <h1>Joint reporting update</h1>
        <div class="author-meta">
          <a class="author-name" href="/authors/alice-brown">Alice Brown</a>
          <a class="author-name" href="/authors/bob-jones">Bob Jones</a>
          <a class="author-email-link" href="mailto:desk@example.test">Send an email</a>
        </div>
        <p>The reporting team published a substantive analysis of regional infrastructure and public services.</p>
        <p>The article contains enough independently owned prose to exercise normal article extraction behavior.</p>
        <p>Multiple named contributors must not be reduced to only the first visible author field.</p>
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/news/joint-update", html) do |page|
      payload = extract(page)

      expect(payload["byline"]).to include("Alice Brown")
      expect(payload["byline"]).to include("Bob Jones")
    end
  end

  it "preserves a hostname when it is the explicit author-name field" do
    html = <<~HTML
      <html><head><title>Source-owned newsroom update</title></head><body><main><article>
        <h1>Source-owned newsroom update</h1>
        <div class="author-meta">
          <a class="author-name" href="/authors/newsroom">news.example.test</a>
          <a class="author-email-link" href="mailto:desk@example.test">Send an email</a>
        </div>
        <p>The newsroom published a substantive report about infrastructure and public community services.</p>
        <p>The article contains enough independently owned prose to exercise normal article extraction behavior.</p>
        <p>The hostname is explicitly presented as the author rather than inferred only from site metadata.</p>
      </article></main></body></html>
    HTML

    with_url_page("https://news.example.test/news/source-update", html) do |page|
      payload = extract(page)

      expect(payload["byline"]).to eq("news.example.test")
    end
  end

  it "does not combine a site identity with an adjacent localized publication date" do
    body = 4.times.map do |index|
      "<p>Retrospective paragraph #{index + 1} explains the historical event with enough substantive article context for reader extraction.</p>"
    end.join
    html = <<~HTML
      <html lang="et"><head>
        <title>Täna ajaloos meenutatakse Tartu sündmusi</title>
        <meta property="og:site_name" content="teadus.postimees.ee">
        <meta property="article:published_time" content="2017-07-08T08:00:26+03:00">
      </head><body><main><article>
        <h1>Täna ajaloos meenutatakse Tartu sündmusi</h1>
        <div class="authors">
          <div class="authors__row"><span itemprop="author"><span itemprop="name">teadus.postimees.ee</span></span></div>
          <div class="article__dates"><span itemprop="datePublished">8. juuli 2026, 06:00</span></div>
        </div>
        #{body}
      </article></main></body></html>
    HTML

    with_url_page("https://teadus.postimees.ee/4170789/history", html) do |page|
      payload = extract(page)

      expect(payload["byline"]).to be_nil
      expect(payload["publishedTime"]).to eq("8. juuli 2026, 06:00")
      expect(payload["markdown"]).not_to include("teadus.postimees.ee8. juuli")
    end
  end

  it "keeps a person byline separate from an adjacent localized publication date" do
    body = 4.times.map do |index|
      "<p>Community report paragraph #{index + 1} contains substantive article prose for reader extraction and ownership checks.</p>"
    end.join
    html = <<~HTML
      <html lang="et"><head>
        <title>Community report documents the regional program</title>
        <meta property="article:published_time" content="2019-07-08T06:00:00+03:00">
      </head><body><main><article>
        <h1>Community report documents the regional program</h1>
        <div class="authors">
          <div class="authors__row"><span itemprop="author"><span itemprop="name">Mari Reporter</span></span></div>
          <div class="article__dates"><span itemprop="datePublished">8. juuli 2026, 06:00</span></div>
        </div>
        #{body}
      </article></main></body></html>
    HTML

    with_url_page("https://example.ee/news/community-report", html) do |page|
      payload = extract(page)

      expect(payload["byline"]).to eq("Mari Reporter")
      expect(payload["publishedTime"]).to eq("2019-07-08T06:00:00+03:00")
    end
  end

  it "does not treat a year-like author suffix as a complete publication date" do
    body = 4.times.map do |index|
      "<p>Annual report paragraph #{index + 1} contains substantive prose about the organization and its regional public program.</p>"
    end.join
    html = <<~HTML
      <html><head><title>Annual organization report</title></head><body><main><article>
        <h1>Annual organization report</h1>
        <div class="authors">
          <span itemprop="author"><span itemprop="name">Community Studio 2026</span></span>
          <span itemprop="datePublished">2026</span>
        </div>
        #{body}
      </article></main></body></html>
    HTML

    with_url_page("https://example.test/reports/annual", html) do |page|
      payload = extract(page)

      expect(payload["byline"]).to eq("Community Studio 2026")
      expect(payload["publishedTime"]).to eq("2026")
    end
  end

  it "uses localized author-profile destinations as scoped bylines" do
    html = <<~HTML
      <html lang="de">
        <head><title>Stadt eröffnet neues Kulturzentrum</title></head>
        <body>
          <main>
            <article>
              <h1>Stadt eröffnet neues Kulturzentrum</h1>
              <a href="/autoren/blick-newsdesk">Blick Newsdesk</a>
              <p>Das neue Kulturzentrum bietet Räume für Konzerte, Ausstellungen und Workshops in mehreren Stadtteilen.</p>
              <p>Lokale Vereine haben das Programm gemeinsam mit Schulen und Kulturschaffenden entwickelt.</p>
              <p>Die ersten Veranstaltungen beginnen nach der offiziellen Eröffnung am kommenden Wochenende.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.ch/story/kulturzentrum", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["byline"]).to eq("Blick Newsdesk")
    end
  end

  it "uses localized author destinations inside nested credit metadata" do
    html = <<~HTML
      <html lang="fr"><head><title>La ville ouvre un nouveau centre culturel</title></head><body>
        <article>
          <h1>La ville ouvre un nouveau centre culturel</h1>
          <div class="article-credit"><span><a href="/auteur/marie-dupont">Marie Dupont</a></span></div>
          <p>Le nouveau centre propose des concerts, des expositions et des ateliers pour plusieurs quartiers de la ville.</p>
          <p>Les associations locales ont préparé le programme avec les écoles et les artistes de la région.</p>
          <p>Les premières manifestations commenceront après l'ouverture officielle prévue le week-end prochain.</p>
        </article>
      </body></html>
    HTML

    with_url_page("https://example.fr/culture/nouveau-centre", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["byline"]).to eq("Marie Dupont")
    end
  end

  it "does not use in-body, related, directory, or broad-main author links as bylines" do
    article_html = <<~HTML
      <html><head><title>Regional museum opens new archive</title></head><body><main>
        <article>
          <h1>Regional museum opens new archive</h1>
          <div class="article-credit"><a href="/authors/archive/index">Authors directory</a></div>
          <p>The regional museum has opened an archive with records from local cultural institutions and community groups.</p>
          <p>Read the <a href="/author/historian">historian profile</a> for background about the collection.</p>
          <section class="relatedStories"><div class="article-credit"><a href="/authors/related-reporter">Related Reporter</a></div></section>
          <section class="more-stories_related_stories"><article>
            <a href="/author/nested-related-reporter">Nested Related Reporter</a>
            <h2>Related analysis</h2>
            <p>#{"Related reporting must not supply page metadata. " * 12}</p>
            <p>#{"This nested article remains independent of the focal story. " * 12}</p>
            <p>#{"Its own author belongs only to the related story. " * 12}</p>
          </article></section>
          <a href="/author/editor%2Farchive">Encoded author archive</a>
          <a href="/author/%00control">Control author slug</a>
          <p>The archive will remain open to researchers and residents throughout the coming year.</p>
        </article>
      </main></body></html>
    HTML
    main_html = <<~HTML
      <html><head><title>Community reporting archive</title></head><body><main>
        <h1>Community reporting archive</h1>
        <a href="/author/editor-profile">Unowned author profile</a>
        <p>This archive presents substantial reporting about community projects, public records, and local history.</p>
        <p>Residents can browse the published reports and supporting material without creating an account.</p>
        <p>Each report includes background, sources, and updates from the responsible public institutions.</p>
      </main></body></html>
    HTML

    with_url_page("https://example.com/reports/archive", article_html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload["byline"]).to be_nil
    end
    with_url_page("https://example.com/archive", main_html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload["byline"]).to be_nil
    end
  end

  it "does not expose a localized publication date as the byline" do
    html = <<~HTML
      <html lang="pl">
        <head>
          <title>Regional rail plans move forward</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "NewsArticle",
              "headline": "Regional rail plans move forward",
              "datePublished": "2026-06-24T17:42:00+02:00"
            }
          </script>
        </head>
        <body>
          <main><article>
            <h1>Regional rail plans move forward</h1>
            <div class="article-author">24 czerwca 2026, 17:42</div>
            <p>Regional planners approved the next stage of work on the railway linking several growing communities.</p>
            <p>The proposal preserves existing local stops while adding direct services for longer journeys.</p>
            <p>Public consultation will continue before engineers finalize the construction schedule.</p>
          </article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.pl/transport/regional-rail", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["byline"]).to be_nil
      expect(payload["publishedTime"]).to eq("2026-06-24T17:42:00+02:00")
      expect(payload["markdown"]).to include("24 czerwca 2026, 17:42")
    end
  end

  it "uses structured authors when author metadata is a URL" do
    html = <<~HTML
      <html>
        <head>
          <title>Regional rail plans move forward</title>
          <meta property="article:author" content="https://example.test/authors/jordan-lee">
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "NewsArticle",
              "headline": "Regional rail plans move forward",
              "author": { "@type": "Person", "name": "Jordan Lee" }
            }
          </script>
        </head>
        <body>
          <main><article>
            <h1>Regional rail plans move forward</h1>
            <p>Regional planners approved the next stage of work on the railway linking several growing communities.</p>
            <p>The proposal preserves existing local stops while adding direct services for longer journeys.</p>
            <p>Public consultation will continue before engineers finalize the construction schedule.</p>
          </article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/transport/regional-rail", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["byline"]).to eq("Jordan Lee")
      expect(payload["byline"]).not_to include("https://")
    end
  end

  it "prefers a structured author over a reader-mode byline polluted by a publication time" do
    html = <<~HTML
      <html>
        <head>
          <title>Harbor safety rules take effect</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "NewsArticle",
              "headline": "Harbor safety rules take effect",
              "author": { "@type": "Person", "name": "Suresh Rao" }
            }
          </script>
        </head>
        <body>
          <main><article>
            <h1>Harbor safety rules take effect</h1>
            <div class="byline">07:34 AM Jul 08, 2026 IST<span aria-label="Book an island tour now">Book an island tour now</span></div>
            <p>Harbor authorities introduced updated navigation rules for every commercial vessel using the busy coastal route.</p>
            <p>The guidance explains how crews should report hazards, coordinate arrival times, and respond to emergency notices.</p>
            <p>Officials will review the measures with shipping companies after the first month and publish any necessary revisions.</p>
          </article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/news/harbor-safety", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["readerMode"]).to be(true)
      expect(payload["byline"]).to eq("Suresh Rao")
      expect(payload["markdown"]).to include("respond to emergency notices")
    end
  end

  it "skips a reader-mode author-section label for complete visible authors" do
    html = <<~HTML
      <html>
        <head>
          <title>Wetland restoration methods compared</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "ScholarlyArticle",
              "headline": "Wetland restoration methods compared",
              "author": { "@type": "Person", "name": "Lydia Teboul" }
            }
          </script>
        </head>
        <body>
          <main><article>
            <h1>Wetland restoration methods compared</h1>
            <div class="byline">Author information</div>
            <div class="article-author-list">Lydia Teboul, Yann Hérault, Sara Wells</div>
            <p>Researchers compared restoration methods across wetlands with different soils, climates, and land-use histories.</p>
            <p>The study measured vegetation recovery, water retention, and habitat quality throughout the observation period.</p>
            <p>Results identify practical methods that local conservation teams can adapt while preserving ecological context.</p>
          </article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/research/wetland-restoration", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["readerMode"]).to be(true)
      expect(payload["byline"]).to eq("Lydia Teboul, Yann Hérault, Sara Wells")
      expect(payload["byline"]).not_to eq("Author information")
    end
  end

  it "ignores hidden dates and bylines while preserving restored metadata" do
    html = <<~HTML
      <html>
        <head><title>Community archive update</title></head>
        <body>
          <main><article>
            <h1>Community archive update</h1>
            <time datetime="2010-01-01" style="display: none">January 1, 2010</time>
            <time datetime="2026-08-29">August 29, 2026</time>
            <span class="author" style="display: none">Hidden Author</span>
            <section style="visibility: hidden">
              <span class="author" style="visibility: visible">Visible Author</span>
            </section>
            <p>This current report explains how local archivists preserve records and publish dependable descriptions.</p>
            <p>Contributors review each collection, document its provenance, and retain useful context for future readers.</p>
            <p>The updated catalogue keeps every public record available while clearly separating historical notes from current guidance.</p>
          </article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/archive/current-update", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["byline"]).to eq("Visible Author")
      expect(payload["publishedTime"]).to eq("2026-08-29")
      expect(payload["warnings"]).not_to include("stale_content")
    end
  end

  it "does not report schema modification time as publication time" do
    html = <<~HTML
      <html>
        <head>
          <title>Community archive preservation guide</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Article",
              "headline": "Community archive preservation guide",
              "dateModified": "2026-08-28T09:30:00Z"
            }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>Community archive preservation guide</h1>
              <p>This guide explains how volunteers can organize, describe, and preserve local archive materials.</p>
              <p>Each record should retain its original context while receiving a stable identifier and careful description.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/guides/archive-preservation", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["publishedTime"]).to be_nil
    end
  end

  it "normalizes language from the html lang attribute" do
    html = <<~HTML
      <html lang="es-MX">
        <head><title>Biblioteca comunitaria</title></head>
        <body>
          <main><article><h1>Biblioteca comunitaria</h1><p>La biblioteca abre sus puertas para estudiantes y familias del barrio.</p></article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.es/cultura/biblioteca", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["language"]).to eq("es")
    end
  end

  it "normalizes language from Content-Language metadata" do
    html = <<~HTML
      <html>
        <head>
          <title>Nouvelle bibliothèque</title>
          <meta http-equiv="Content-Language" content="fr-CA, en">
        </head>
        <body>
          <main><article><h1>Nouvelle bibliothèque</h1><p>La bibliothèque accueille les familles avec des ateliers de lecture.</p></article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/fr/bibliotheque", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["language"]).to eq("fr")
    end
  end

  it "normalizes language from Open Graph locale metadata" do
    html = <<~HTML
      <html>
        <head>
          <title>Biblioteca comunitária</title>
          <meta property="og:locale" content="pt_BR">
        </head>
        <body>
          <main><article><h1>Biblioteca comunitária</h1><p>A biblioteca oferece atividades culturais para moradores e estudantes.</p></article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/br/biblioteca", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["language"]).to eq("pt")
    end
  end

  it "prefers content-level Open Graph locale over contradictory page-shell language" do
    html = <<~HTML
      <html lang="en-US">
        <head>
          <title>Biblioteka e lagjes</title>
          <meta property="og:locale" content="sq_AL">
        </head>
        <body>
          <nav>#{Array.new(40) { |index| "<a href='https://example.test/topic/#{index}'>Topic #{index}</a>" }.join}</nav>
          <main>
            <article>
              <h1>Biblioteka e lagjes</h1>
              <p>Biblioteka e lagjes hapi dyert për banorët dhe studentët.</p>
              <p>Vullnetarët mblodhën libra dhe përgatitën sallat për lexuesit.</p>
              <p>Programi përfshin takime javore me autorë dhe studiues.</p>
              <p>Fëmijët mund të marrin pjesë në aktivitete krijuese pas mësimit.</p>
              <p>Prindërit mirëpritën hapësirën e re kulturore në komunitet.</p>
              <p>Stafi njoftoi se shërbimi do të zgjerohet gjatë verës.</p>
              <p>Biblioteka do të qëndrojë e hapur çdo ditë deri në mbrëmje.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/kulture/biblioteka", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["language"]).to eq("sq")
      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Biblioteka e lagjes hapi dyert")
      expect(payload["markdown"]).not_to include("https://example.test/topic/")
      expect(payload["warnings"]).not_to include("truncated_content")
      expect(payload["suspect"]).to be(false)
    end
  end

  it "prefers page language when visible text confirms it over contradictory Open Graph locale" do
    thai_text = "ห้องสมุดชุมชนเปิดให้บริการทุกวันสำหรับนักเรียนและครอบครัวในพื้นที่"
    html = <<~HTML
      <html lang="th">
        <head>
          <title>ห้องสมุดชุมชน</title>
          <meta property="og:locale" content="en_US">
        </head>
        <body>
          <main><article><h1>ห้องสมุดชุมชน</h1><p>#{thai_text * 3}</p></article></main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/library", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["language"]).to eq("th")
    end
  end

  it "falls back to text language detection when metadata is absent" do
    html = <<~HTML
      <html>
        <head><title>El barrio estrena biblioteca comunitaria</title></head>
        <body>
          <main>
            <article>
              <h1>El barrio estrena biblioteca comunitaria</h1>
              <p>La nueva biblioteca comunitaria abrió sus puertas con talleres de lectura para familias y estudiantes.</p>
              <p>Vecinos y docentes colaboraron durante meses para reunir libros, preparar actividades y organizar horarios de atención.</p>
              <p>El municipio explicó que el espacio también funcionará como punto de encuentro para proyectos culturales del distrito.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/cultura/biblioteca", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["language"]).to eq("es")
    end
  end

  it "falls back to a safe clone when deep DOM cloning triggers custom-element errors" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <h1>Flight updates</h1>
              <p>Primary itinerary details remain readable.</p>
              <date-calendar-component>
                <div>June 12 departure</div>
              </date-calendar-component>
            </article>
          </main>
          <script>
            (() => {
              const originalCloneNode = Node.prototype.cloneNode;
              Node.prototype.cloneNode = function(deep) {
                if (deep && this.nodeType === Node.ELEMENT_NODE && this.tagName === 'DATE-CALENDAR-COMPONENT') {
                  throw new TypeError("Cannot read properties of undefined (reading 'slice')");
                }
                return originalCloneNode.call(this, deep);
              };
            })();
          </script>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Primary itinerary details remain readable.")
      expect(payload["warnings"]).not_to include("empty_extraction")
    end
  end

  it "falls back to shared article heuristics when Readability construction fails" do
    html = <<~HTML
      <html>
        <body>
          <main>
            <article>
              <h1>Forum updates</h1>
              <p>Main post text stays visible.</p>
              <section class="comments">
                <h2>Comments</h2>
                <p>Alice: First reply stays visible.</p>
                <p>Bob: Thanks for the update.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      page.evaluate <<~JS
        Object.defineProperty(window, 'Readability', {
          configurable: true,
          set(value) {
            const BrokenReadability = function() {
              throw new TypeError("Cannot read properties of undefined (reading 'slice')");
            };

            BrokenReadability.prototype = value.prototype;
            Object.defineProperty(window, 'Readability', {
              value: BrokenReadability,
              configurable: true,
              writable: true
            });
          },
          get() {
            return undefined;
          }
        });
      JS

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Main post text stays visible.")
      expect(payload["markdown"]).to include("Comments")
      expect(payload["markdown"]).to include("Alice: First reply stays visible.")
      expect(payload["markdown"]).to include("Bob: Thanks for the update.")
      expect(payload["warnings"]).not_to include("empty_extraction")
    end
  end

  it "preserves a focused news article body over donation and footer chrome" do
    paragraphs = (1..8).map do |index|
      "<p>Article body paragraph #{index} explains the switchback experiment design with enough standalone prose to identify the real content region.</p>"
    end.join

    html = <<~HTML
      <html>
        <head><title>Switchback Experiment Design</title></head>
        <body>
          <main id="site-main">
            <aside class="donation-cta">
              <h2>Support our charity</h2>
              <p>Donate to help people learn to code and support our nonprofit mission.</p>
              <a href="/donate">Donate now</a>
            </aside>
            <article>
              <h1>Switchback Experiment Design</h1>
              <section data-test-label="post-content" class="article-content prose">
                #{paragraphs}
                <h2>How Switchback Design Restores a Clean Comparison</h2>
                <p>The whole platform alternates between treatment and control slots, so shared model capacity no longer contaminates only one user group.</p>
              </section>
            </article>
            <footer>
              <h2>About freeCodeCamp</h2>
              <p>Our mission is to help people learn to code for free.</p>
              <a href="/news/about/">About</a>
              <a href="/donate/">Donate</a>
            </footer>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://www.freecodecamp.org/news/switchback-experiments-for-ai-platform-features-in-python/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("Article body paragraph 8")
      expect(payload["markdown"]).to include("How Switchback Design Restores a Clean Comparison")
      expect(payload["markdown"]).not_to include("Support our charity")
    end
  end

  it "prefers a full long document body over a short reader-mode fragment" do
    articles = (1..18).map do |index|
      <<~HTML
        <section class="cxl-section">
          <h2>Article #{index}</h2>
          <p>#{index}. This official instrument keeps operative clause #{index} in the consolidated body.</p>
          <p>The document paragraph for article #{index} remains part of the same legal text.</p>
        </section>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Consolidated Official Instrument</title></head>
        <body>
          <main id="MainContent">
            <article id="notice-fragment">
              <table>
                <tr><td>1.1.2030</td><td>EN</td><td>Official Journal</td><td>C 1/1</td></tr>
              </table>
              <h1>Consolidated Official Instrument</h1>
              <p>Article 1</p>
              <p>Opening clause from the first visible fragment.</p>
            </article>
            <section id="text" class="cxl-body">
              <h1>Consolidated Official Instrument</h1>
              #{articles}
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.test/legal-content/EN/TXT/?uri=CELEX:LONGDOC", html) do |page|
      page.evaluate <<~JS
        Object.defineProperty(window, 'Readability', {
          configurable: true,
          set(value) {
            const FragmentReadability = function() {};
            FragmentReadability.prototype.parse = function() {
              return {
                title: 'Consolidated Official Instrument',
                content: document.querySelector('#notice-fragment').outerHTML,
                textContent: document.querySelector('#notice-fragment').textContent
              };
            };

            Object.defineProperty(window, 'Readability', {
              value: FragmentReadability,
              configurable: true,
              writable: true
            });
          },
          get() {
            return undefined;
          }
        });
      JS

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Article 1")
      expect(payload["markdown"]).to include("Article 18")
      expect(payload["markdown"]).to include("operative clause 18")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "drops obvious related-entry utility sections before markdown conversion" do
    html = <<~HTML
      <html>
        <head><title>Rare Entry</title></head>
        <body>
          <main>
            <article>
              <h1>Rare Entry</h1>
              <p>The main definition should stay in markdown.</p>
              <section>
                <h2>Nearby entries</h2>
                <ul>
                  <li><a href="/entry/one">Entry One</a></li>
                  <li><a href="/entry/two">Entry Two</a></li>
                  <li><a href="/entry/three">Entry Three</a></li>
                </ul>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("The main definition should stay in markdown.")
      expect(payload["markdown"]).not_to include("Nearby entries")
      expect(payload["markdown"]).not_to include("Entry One")
    end
  end

  it "extracts glossary pages from definition-heavy roots instead of nearby-word chrome" do
    html = <<~HTML
      <html>
        <head><title>CONFEDERATIONIST Definition &amp; Meaning - Merriam-Webster</title></head>
        <body>
          <main>
            <article id="dictionary-entry-1" class="entry-body">
              <h1>confederationist</h1>
              <h2>noun</h2>
              <div class="dtText">: a supporter or adherent of a confederation or of a policy of confederating</div>
            </article>
            <section>
              <h2>Browse Nearby Words</h2>
              <ul>
                <li><a href="/dictionary/confederative">confederative</a></li>
                <li><a href="/dictionary/confederator">confederator</a></li>
                <li><a href="/dictionary/conferee">conferee</a></li>
              </ul>
            </section>
            <section>
              <h2>More from Merriam-Webster</h2>
              <p>Top Lookups</p>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.merriam-webster.com/dictionary/confederationist", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("a supporter or adherent of a confederation")
      expect(payload["markdown"]).not_to include("Browse Nearby Words")
      expect(payload["markdown"]).not_to include("Top Lookups")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end

  it "removes repeated HTML5 audio fallback text from pronunciation output" do
    html = <<~HTML
      <html>
        <head><title>non-Celtic | Pronunciation in English</title></head>
        <body>
          <main>
            <article class="dictionary">
              <h1>non-Celtic</h1>
              <p>Your browser doesn't support HTML5 audio</p>
              <p>UK /non-kel-tik/</p>
              <ul>
                <li>Your browser doesn't support HTML5 audio /n/ as in name</li>
                <li>Your browser doesn't support HTML5 audio /k/ as in cat</li>
              </ul>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_page(html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("UK /non-kel-tik/")
      expect(payload["markdown"]).to include("/n/ as in name")
      expect(payload["markdown"]).not_to include("Your browser doesn't support HTML5 audio")
    end
  end

  it "falls back to metadata summaries when glossary extraction is dominated by utility chrome" do
    html = <<~HTML
      <html>
        <head>
          <title>DEPOPULATOR Definition &amp; Meaning - Merriam-Webster</title>
          <meta name="description" content="The meaning of DEPOPULATOR is one that depopulates. See the full definition.">
        </head>
        <body>
          <main>
            <article>
              <h1>Definition of DEPOPULATOR</h1>
              <section>
                <h2>Word History</h2>
                <p>Middle English, devastator.</p>
              </section>
              <section>
                <h2>Browse Nearby Words</h2>
                <ul>
                  <li><a href="/dictionary/depopulate">depopulate</a></li>
                  <li><a href="/dictionary/depopulation">depopulation</a></li>
                </ul>
              </section>
              <section>
                <h2>Cite this Entry</h2>
                <p>"Depopulator." Merriam-Webster.com Dictionary.</p>
              </section>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.merriam-webster.com/dictionary/depopulator", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("one that depopulates")
      expect(payload["markdown"]).not_to include("Browse Nearby Words")
      expect(payload["markdown"]).not_to include("Cite this Entry")
    end
  end

  it "uses metadata fallback for query-driven translation dictionary pages" do
    html = <<~HTML
      <html>
        <head>
          <title>whores - Tlumaczenie po polsku - Slownik angielsko-polski Diki</title>
          <meta name="description" content="whore - tlumaczenie na polski oraz definicja. Co znaczy i jak powiedziec whore po polsku? - zdzira, dziwka, kurwa; prostytutka">
        </head>
        <body>
          <main>
            <div class="promo-links">
              <a href="/dictionary/about">O slowniku Diki</a>
              <a href="https://www.etutor.pl/">Kurs angielskiego</a>
            </div>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/lookup?q=whores", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("tlumaczenie na polski")
      expect(payload["markdown"]).to include("prostytutka")
      expect(payload["contentType"]).to eq("article")
    end
  end

  it "pairs term and description blocks on glossary pages that use p.term and p.desc" do
    html = <<~HTML
      <html>
        <head><title>Definitions for Whores</title></head>
        <body>
          <main>
            <h1>Definitions for Whores</h1>
            <section id="definitions-list">
              <div id="wikipedia">
                <p class="term">whore</p>
                <ol>
                  <li><p class="desc">A prostitute.</p></li>
                </ol>
              </div>
              <div id="wikidata">
                <p class="term">whore</p>
                <ol>
                  <li><p class="desc">An insulting term for a promiscuous person.</p></li>
                </ol>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.definitions.net/definition/Whores", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("A prostitute")
      expect(payload["markdown"]).to include("promiscuous person")
      expect(payload["markdown"]).not_to include("Wikidata")
    end
  end

  it "extracts recipe schema content when the visible DOM is only a teaser" do
    html = <<~HTML
      <html>
        <head>
          <title>오이냉국 황금레시피</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Recipe",
              "name": "오이냉국 황금레시피",
              "description": "새콤하고 시원한 오이냉국 레시피입니다.",
              "recipeYield": "2 servings",
              "recipeIngredient": ["오이 1개", "물 800ml", "식초 2큰술"],
              "recipeInstructions": [
                "오이를 얇게 썬다.",
                "양념을 물에 풀어 냉국물을 만든다.",
                "오이를 넣고 차갑게 식혀 낸다."
              ]
            }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>오이냉국 황금레시피</h1>
              <p>물 800ml, 식초 2큰술</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.10000recipe.com/recipe/7054210", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["markdown"]).to include("## Ingredients")
      expect(payload["markdown"]).to include("오이 1개")
      expect(payload["markdown"]).to include("## Instructions")
      expect(payload["markdown"]).to include("양념을 물에 풀어 냉국물을 만든다")
    end
  end

  it "extracts page-owned recipe structured data" do
    html = <<~HTML
      <html>
        <head>
          <title>Garden herb flatbread</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "WebPage",
              "@id": "https://example.com/recipes/garden-herb-flatbread#page",
              "name": "Garden herb flatbread",
              "mainEntity": {
                "@type": "Recipe",
                "name": "Garden herb flatbread",
                "description": "A simple flatbread made with fresh garden herbs.",
                "recipeIngredient": ["2 cups flour", "1 cup water", "2 tablespoons herbs"],
                "recipeInstructions": ["Mix the dough and herbs.", "Bake until golden."]
              }
            }
          </script>
        </head>
        <body>
          <main>
            <h1>Garden herb flatbread</h1>
            <p>See the complete recipe details for this seasonal flatbread.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/recipes/garden-herb-flatbread", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("recipe")
      expect(payload["ingredients"]).to eq(["2 cups flour", "1 cup water", "2 tablespoons herbs"])
      expect(payload["instructions"]).to eq(["Mix the dough and herbs.", "Bake until golden."])
    end
  end

  it "does not promote structured data owned by a foreign page" do
    html = <<~HTML
      <html>
        <head>
          <title>How recipe indexes organize seasonal dishes</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "WebPage",
              "@id": "https://foreign.example/recipes/garden-herb-flatbread",
              "mainEntity": {
                "@type": "Recipe",
                "name": "Garden herb flatbread",
                "recipeIngredient": ["2 cups flour", "1 cup water"],
                "recipeInstructions": ["Mix the dough.", "Bake until golden."]
              }
            }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>How recipe indexes organize seasonal dishes</h1>
              <p>Recipe indexes organize seasonal dishes by ingredient, preparation style, and serving occasion.</p>
              <p>This article explains how editors connect category pages without adopting a referenced recipe as the page subject.</p>
              <p>Each example remains illustrative while the surrounding prose describes general catalog structure and navigation.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/articles/seasonal-recipe-indexes", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["ingredients"]).to be_nil
      expect(payload["instructions"]).to be_nil
    end
  end

  it "accepts a page owner that matches the declared canonical" do
    html = <<~HTML
      <html>
        <head>
          <title>Canonical garden herb flatbread</title>
          <base href="https://publisher.example/recipes/">
          <link rel="canonical" href="garden-herb-flatbread">
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "WebPage",
              "@id": "garden-herb-flatbread#page",
              "mainEntity": {
                "@type": "Recipe",
                "name": "Canonical garden herb flatbread",
                "recipeIngredient": ["2 cups flour", "1 cup water", "2 tablespoons herbs"],
                "recipeInstructions": ["Mix the dough and herbs.", "Bake until golden."]
              }
            }
          </script>
        </head>
        <body>
          <main>
            <h1>Canonical garden herb flatbread</h1>
            <p>See the complete recipe details for this seasonal flatbread.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://redirector.example/outbound/flatbread", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["canonicalUrl"]).to eq("https://publisher.example/recipes/garden-herb-flatbread")
      expect(payload["contentType"]).to eq("recipe")
      expect(payload["ingredients"]).to eq(["2 cups flour", "1 cup water", "2 tablespoons herbs"])
      expect(payload["instructions"]).to eq(["Mix the dough and herbs.", "Bake until golden."])
    end
  end

  it "prefers complete graph entities over page-owned references" do
    html = <<~HTML
      <html>
        <head>
          <title>Roasted orchard fruit</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@graph": [
                {
                  "@type": "WebPage",
                  "name": "Roasted orchard fruit",
                  "mainEntity": {"@id": "#recipe", "@type": "Recipe"}
                },
                {
                  "@id": "#recipe",
                  "@type": "Recipe",
                  "name": "Roasted orchard fruit",
                  "recipeIngredient": ["2 apples", "2 pears", "1 tablespoon honey"],
                  "recipeInstructions": ["Slice the fruit.", "Roast with honey until tender."]
                }
              ]
            }
          </script>
        </head>
        <body>
          <main>
            <h1>Roasted orchard fruit</h1>
            <p>See the complete recipe for this seasonal dessert.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/recipes/roasted-orchard-fruit", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("recipe")
      expect(payload["ingredients"]).to eq(["2 apples", "2 pears", "1 tablespoon honey"])
      expect(payload["instructions"]).to eq(["Slice the fruit.", "Roast with honey until tender."])
    end
  end

  it "excludes unrelated structured records when a page owner resolves its main entity" do
    html = <<~HTML
      <html>
        <head>
          <title>Policy analysis</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@graph": [
                {
                  "@type": "WebPage",
                  "@id": "https://example.com/analysis/policy#page",
                  "mainEntity": {"@id": "#article"}
                },
                {
                  "@id": "#article",
                  "@type": "Article",
                  "headline": "Policy analysis",
                  "description": "A detailed analysis of current policy choices."
                },
                {
                  "@type": "Event",
                  "name": "Sidebar webinar",
                  "startDate": "2026-10-01",
                  "description": "An unrelated promotional event."
                }
              ]
            }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>Policy analysis</h1>
              <p>This analysis explains how the current policy choices affect public services and institutional planning.</p>
              <p>It compares the available approaches, their practical constraints, and the evidence supporting each option.</p>
              <p>The conclusion identifies implementation priorities without treating a sidebar promotion as the page subject.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/analysis/policy", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("current policy choices")
      expect(payload["markdown"]).not_to include("Sidebar webinar", "unrelated promotional event")
      expect(payload["startTime"]).to be_nil
    end
  end

  it "merges page-owned entities with graph descriptions" do
    html = <<~HTML
      <html>
        <head>
          <title>Summer tomato tart</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@graph": [
                {
                  "@id": "#recipe",
                  "@type": "Recipe",
                  "name": "Summer tomato tart",
                  "description": "A savory tart for the summer table.",
                  "image": "https://example.com/images/summer-tomato-tart.jpg",
                  "recipeIngredient": "1 pastry sheet",
                  "recipeInstructions": ["Layer the tomatoes on the pastry."]
                },
                {
                  "@id": "#recipe",
                  "@type": "Recipe",
                  "recipeIngredient": ["1 pastry sheet", "3 tomatoes"],
                  "recipeInstructions": "Bake until crisp."
                },
                {
                  "@type": "WebPage",
                  "name": "Summer tomato tart",
                  "mainEntity": {
                    "@id": "#recipe",
                    "@type": "Recipe",
                    "name": "Summer tomato tart",
                    "recipeIngredient": ["3 tomatoes", "1 tablespoon herbs"]
                  }
                }
              ]
            }
          </script>
        </head>
        <body>
          <main>
            <h1>Summer tomato tart</h1>
            <p>See the complete recipe for this savory tart.</p>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/recipes/summer-tomato-tart", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("recipe")
      expect(payload["ingredients"]).to eq(["1 pastry sheet", "3 tomatoes", "1 tablespoon herbs"])
      expect(payload["instructions"]).to eq(["Layer the tomatoes on the pastry.", "Bake until crisp."])
    end
  end

  it "does not promote non-page nested product structured data" do
    html = <<~HTML
      <html>
        <head>
          <title>How catalog systems represent inventory</title>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Article",
              "headline": "How catalog systems represent inventory",
              "mainEntity": {
                "@type": "Product",
                "name": "Example archive box",
                "description": "An illustrative nested catalog record.",
                "offers": {"@type": "Offer", "price": "24.00", "priceCurrency": "USD"}
              }
            }
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>How catalog systems represent inventory</h1>
              <p>Catalog systems often embed sample entities when explaining how records are connected and described.</p>
              <p>This article examines ownership boundaries so that nested examples are not mistaken for the page's primary subject.</p>
              <p>Editors use these examples to document field relationships, validation rules, and the limits of each catalog entry.</p>
              <p>A page can therefore discuss an inventory record without becoming the authoritative product page for that record.</p>
              <p>Keeping that distinction intact prevents explanatory prose from being replaced by unrelated commerce details.</p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/guides/catalog-inventory", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["price"]).to be_nil
    end
  end

  it "keeps long-form article pages in article mode even when related cards are present" do
    html = <<~HTML
      <html>
        <head><title>推しカラーの取り入れ方ガイド</title></head>
        <body>
          <main>
            <article class="article-body">
              <h1>推しカラーの取り入れ方ガイド</h1>
              <p>推しカラーを日常のメイクに取り入れるときは、色そのものの強さだけでなく、質感や配置のバランスを見ることが大切です。</p>
              <p>たとえば目もとに鮮やかな色を使う場合は、チークやリップを少し落ち着かせることで全体がまとまり、派手になりすぎずに楽しめます。</p>
              <p>また、ベースカラーを肌になじむ色に整えておくと、推しカラーがアクセントとして自然に見えやすくなります。</p>
              <p>イベント当日は写真写りも意識して、ラメ感やツヤ感を部分的に足すと、色の印象がよりきれいに伝わります。</p>
            </article>
            <aside class="related-grid">
              <h2>関連記事</h2>
              <ul>
                <li><a href="/related/1">推し活メイクの基本</a></li>
                <li><a href="/related/2">赤を使ったポイントメイク</a></li>
                <li><a href="/related/3">オレンジ系シャドウのなじませ方</a></li>
                <li><a href="/related/4">グリーンメイクの抜け感</a></li>
                <li><a href="/related/5">イベント向けの写真映えテク</a></li>
                <li><a href="/related/6">推し活ポーチの中身</a></li>
              </ul>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://example.com/column/favorite-color", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("article")
      expect(payload["markdown"]).to include("推しカラーを日常のメイクに取り入れるときは")
      expect(payload["markdown"]).not_to include("- [推し活メイクの基本]")
    end
  end

  it "prefers the prose article column over CTA and recent-posts sidebars" do
    article_paragraphs = 10.times.map do |index|
      "<p>Main article paragraph #{index + 1} explains how engineering teams diagnose user-impacting software issues before they become backlog clutter.</p>"
    end.join("\n")

    recent_cards = 4.times.map do |index|
      <<~HTML
        <article class="post-card">
          <a href="/recent-#{index + 1}"><h4>Recent product post #{index + 1}</h4></a>
          <p>Short sidebar summary #{index + 1} for another post.</p>
        </article>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>Self-improving software</title></head>
        <body>
          <main class="page-layout">
            <article class="article-content lr-content">
              <h1>Self-improving software</h1>
              #{article_paragraphs}
              <h2>How the system works</h2>
              <p>The article body continues with concrete implementation details and customer examples.</p>
            </article>
            <aside class="sidebar-container">
              <section class="footer-cta-container">
                <h2>Stop guessing about your digital experience</h2>
                <a href="/signup">Get started for free</a>
              </section>
              <section id="recent-posts">
                <h4>Recent posts:</h4>
                #{recent_cards}
              </section>
            </aside>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://blog.example.com/self-improving-software/", html) do |page|
      page.evaluate <<~JS
        Object.defineProperty(window, 'Readability', {
          configurable: true,
          set(value) {
            const SidebarReadability = function() {};
            SidebarReadability.prototype.parse = function() {
              const sidebar = document.querySelector('.sidebar-container');
              return {
                title: 'Self-improving software',
                content: sidebar.outerHTML,
                textContent: sidebar.textContent
              };
            };

            Object.defineProperty(window, 'Readability', {
              value: SidebarReadability,
              configurable: true,
              writable: true
            });
          },
          get() {
            return undefined;
          }
        });
      JS

      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("# Self-improving software")
      expect(payload["markdown"]).to include("Main article paragraph 10 explains")
      expect(payload["markdown"]).to include("The article body continues with concrete implementation details")
      expect(payload["markdown"]).not_to include("Recent posts")
      expect(payload["markdown"]).not_to include("Get started for free")
    end
  end

  it "preserves complete long glossary definitions from repeated source blocks" do
    html = <<~HTML
      <html>
        <head><title>What does Whores mean?</title></head>
        <body>
          <main>
            <h1>Definitions for Whores</h1>
            <section id="definitions-list">
              <div id="wikipedia" class="rc5">
                <h3>Wikipedia Rate this definition: 0.0 / 0 votes</h3>
                <ol>
                  <li class="wselect-cnt">
                    <p class="term">whores</p>
                    <p class="desc">Prostitution is the business or practice of engaging in sexual activity in exchange for payment. The definition of sexual activity varies, and is often defined as an activity requiring physical contact with the customer. The requirement of physical contact also creates the risk of transferring diseases. It occurs in a variety of forms and its legal status varies from country to country.</p>
                  </li>
                </ol>
              </div>
            </section>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.definitions.net/definition/Whores", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["markdown"]).to include("Prostitution is the business or practice")
      expect(payload["markdown"]).to include("risk of transferring diseases")
      expect(payload["markdown"]).to include("legal status varies from country to country")
      expect(payload["warnings"]).not_to include("truncated_content")
    end
  end
end
