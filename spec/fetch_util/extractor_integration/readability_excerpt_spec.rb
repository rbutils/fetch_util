# frozen_string_literal: true

RSpec.describe 'Readability article excerpts' do
  include_context 'extractor integration helpers'

  def readability_excerpt_source
    root = File.expand_path('../../..', __dir__)
    File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).filter_map do |path|
      next if path.empty? || path.start_with?('#')

      content = File.read(File.join(root, 'websieve', path))
      next content unless path == '99_outro.js'

      <<~JS + content
        global.__readabilityArticleExcerpt = readabilityArticleExcerpt;
        global.__readabilityContent = readabilityContent;
        global.__markReadabilityExcerptSources = markReadabilityExcerptSources;
        global.__sourceOwnedReaderAdjacentHeaderExcerpt = sourceOwnedReaderAdjacentHeaderExcerpt;
      JS
    end.join("\n")
  end

  it 'expands only short excerpts backed by substantial parsed article text' do
    short = 'AI-generated, editorially reviewed'
    long_body = short + " #{"Substantive verified reporting continues here. " * 20}"
    html = "<main><h1>Daily dispatch</h1><article><p>#{short}</p><p>#{long_body}</p></article></main>"

    with_url_page('https://publisher.example/article', html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var short = "AI-generated, editorially reviewed";
          var longBody = short + " " + "Substantive verified reporting continues here. ".repeat(20);
          var original = window.Readability;
          window.Readability = function(documentClone) { this.document = documentClone; };
          window.Readability.prototype.parse = function() {
            var article = this.document.querySelector("article");
            return {
              title: "Daily dispatch",
              byline: "Reporter",
              excerpt: short,
              content: article.outerHTML,
              textContent: longBody
            };
          };
          var production = window.__readabilityContent();
          window.Readability = original;

          return {
            production: production.excerpt,
            substantive: window.__readabilityArticleExcerpt({
              excerpt: "A complete summary that already contains enough useful context for the article reader.",
              textContent: longBody
            }),
            shortArticle: window.__readabilityArticleExcerpt({
              excerpt: short,
              textContent: short + " " + "Brief dispatch. ".repeat(12)
            }),
            blank: window.__readabilityArticleExcerpt({ excerpt: "", textContent: longBody })
          };
        })())
      JS

      expect(values['production']).to start_with('AI-generated, editorially reviewed Substantive verified reporting')
      expect(values['production'].length).to be_between(80, 280)
      expect(values['production']).to end_with('.')
      expect(values['substantive']).to eq(
        'A complete summary that already contains enough useful context for the article reader.'
      )
      expect(values['shortArticle']).to eq('AI-generated, editorially reviewed')
      expect(values['blank']).to be_nil
    end
  end

  it 'keeps exact thresholds, unrelated summaries, and Unicode characters intact' do
    with_page('<main><h1>Boundary report</h1></main>') do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var marker = "fixture-marker";
          var excerpt79 = "x".repeat(79);
          var excerpt80 = "x".repeat(80);
          var body399 = excerpt79 + ". " + "b".repeat(318);
          var body400 = excerpt79 + ". " + "b".repeat(319);
          var unicode = "🛰".repeat(400);
          function markedArticle(excerpt, body) {
            return {
              excerpt: excerpt,
              content: "<p data-fetchutil-excerpt-body='" + marker + "'>" + excerpt + "</p>" +
                "<p data-fetchutil-excerpt-body='" + marker + "'>" + body + "</p>",
              textContent: body
            };
          }
          return {
            excerpt79: window.__readabilityArticleExcerpt(
              markedArticle(excerpt79, excerpt79 + ". " + "Verified reporting. ".repeat(20)), null, marker
            ),
            excerpt80: window.__readabilityArticleExcerpt({
              excerpt: excerpt80,
              content: "<p>" + excerpt80 + "</p>",
              textContent: excerpt80 + "b".repeat(400)
            }),
            body399: window.__readabilityArticleExcerpt({
              excerpt: excerpt79, content: "<p>" + excerpt79 + "</p>", textContent: body399
            }, null, marker),
            body400: window.__readabilityArticleExcerpt(markedArticle(excerpt79, body400), null, marker),
            unrelated: window.__readabilityArticleExcerpt({
              excerpt: "Concise editorial summary",
              content: "<p>Different article body.</p>",
              textContent: "Different article body. ".repeat(30)
            }, null, marker),
            late: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<p>" + "Opening context. ".repeat(10) + "</p><p>Visible disclaimer</p>" +
                "<p data-fetchutil-excerpt-body='" + marker + "'>" + "Reporting. ".repeat(30) + "</p>",
              textContent: "Opening context. ".repeat(10) + "Visible disclaimer " + "Reporting. ".repeat(30)
            }, null, marker),
            repeatedAfterSentence: window.__readabilityArticleExcerpt({
              excerpt: "Concise editorial summary",
              content: "<p>Opening sentence.</p><p>Concise editorial summary</p>" +
                "<p data-fetchutil-excerpt-body='" + marker + "'>" + "Reporting. ".repeat(30) + "</p>",
              textContent: "Opening sentence. Concise editorial summary " + "Reporting. ".repeat(30)
            }, null, marker),
            prefix39: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<div>" + "p".repeat(39) + "</div><p>Visible disclaimer</p>" +
                "<p data-fetchutil-excerpt-body='" + marker + "'>" + "Reporting. ".repeat(40) + "</p>",
              textContent: "p".repeat(39) + "Visible disclaimer " + "Reporting. ".repeat(40)
            }, null, marker),
            prefix40: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<div>" + "p".repeat(40) + "</div><p>Visible disclaimer</p>" +
                "<p data-fetchutil-excerpt-body='" + marker + "'>" + "Reporting. ".repeat(40) + "</p>",
              textContent: "p".repeat(40) + "Visible disclaimer " + "Reporting. ".repeat(40)
            }, null, marker),
            unicodeSentence: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<div>先行文。</div><p>Visible disclaimer</p>" +
                "<p data-fetchutil-excerpt-body='" + marker + "'>" + "Reporting. ".repeat(40) + "</p>",
              textContent: "先行文。Visible disclaimer " + "Reporting. ".repeat(40)
            }, null, marker),
            unicode: window.__readabilityArticleExcerpt(
              markedArticle("🛰".repeat(20), unicode), null, marker
            )
          };
        })())
      JS

      expect(values['excerpt79'].length).to be_between(80, 280)
      expect(values['excerpt80']).to eq('x' * 80)
      expect(values['body399']).to eq('x' * 79)
      expect(values['body400'].length).to be_between(80, 280)
      expect(values['unrelated']).to eq('Concise editorial summary')
      expect(values['late']).to eq('Visible disclaimer')
      expect(values['repeatedAfterSentence']).to eq('Concise editorial summary')
      expect(values['prefix39'].length).to be_between(80, 280)
      expect(values['prefix39']).to end_with('.')
      expect(values['prefix40']).to eq('Visible disclaimer')
      expect(values['unicodeSentence']).to eq('Visible disclaimer')
      expect(values['unicode'].each_char.count).to eq(20)
      expect(values['unicode']).to eq('🛰' * 20)
    end
  end

  it 'rejects widget and dialog paragraphs from structured body provenance' do
    body = 'Verified body reporting remains eligible for the article excerpt. ' * 4
    widget = 'Promotional widget prose must not become the article excerpt. ' * 4
    dialog = 'Dialog prose must not become the article excerpt. ' * 4
    html = <<~HTML
      <script type="application/ld+json">
        {"@context":"https://schema.org","@type":"NewsArticle",
         "url":"https://publisher.example/report","headline":"Verified report"}
      </script>
      <div class="article">
        <h1>Verified report</h1>
        <div class="article-content">
          <p id="body">#{body}</p>
          <p>#{body}</p>
        </div>
        <div class="widget article-content"><p id="widget">#{widget}</p></div>
        <dialog open><div class="article-content"><p id="dialog">#{dialog}</p></div></dialog>
        <div role="alertdialog"><div class="article-content"><p id="alertdialog">#{dialog}</p></div></div>
      </div>
    HTML

    with_url_page('https://publisher.example/report', html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var marker = window.__markReadabilityExcerptSources(document);
          function bodyMarker(id) {
            return document.getElementById(id).getAttribute("data-fetchutil-excerpt-body");
          }
          return {
            marker: marker,
            body: bodyMarker("body"),
            widget: bodyMarker("widget"),
            dialog: bodyMarker("dialog"),
            alertdialog: bodyMarker("alertdialog")
          };
        })())
      JS

      expect(values['body']).to eq(values['marker'])
      expect(values.values_at('widget', 'dialog', 'alertdialog')).to eq([nil, nil, nil])
    end
  end

  it 'prefers a proved camel-case article summary over generic body prose' do
    body = 'Later article reporting must not displace the explicit source summary. ' * 8
    html = <<~HTML
      <main>
        <article>
          <div class="ArticleSummary__Container">
            <h2>Key points</h2>
            <p>Editorially reviewed</p>
            <ul>
              <li><p>The first verified point explains the central development.</p></li>
              <li><p>The second verified point supplies material context for readers.</p></li>
            </ul>
          </div>
          <p>#{body}</p>
        </article>
      </main>
    HTML

    with_url_page('https://publisher.example/explicit-summary', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        (function() {
          var clone = document.cloneNode(true);
          var marker = window.__markReadabilityExcerptSources(clone);
          var article = clone.querySelector("article");
          var excerpt = window.__readabilityArticleExcerpt({
            excerpt: "Editorially reviewed",
            content: article.outerHTML,
            textContent: article.textContent
          }, null, marker);
          var ambiguous = document.cloneNode(true);
          var summary = ambiguous.querySelector(".ArticleSummary__Container");
          summary.parentElement.insertBefore(summary.cloneNode(true), summary.nextSibling);
          window.__markReadabilityExcerptSources(ambiguous);
          return JSON.stringify({
            excerpt: excerpt,
            roots: clone.querySelectorAll("[data-fetchutil-excerpt-summary-root]").length,
            paragraphs: clone.querySelectorAll("p[data-fetchutil-excerpt-summary]").length,
            listItems: clone.querySelectorAll("li[data-fetchutil-excerpt-summary]").length,
            ambiguousRoots: ambiguous.querySelectorAll("[data-fetchutil-excerpt-summary-root]").length
          });
        })()
      JS

      expect(values['excerpt']).to start_with(
        'Key points Editorially reviewed The first verified point explains the central development.'
      )
      summary_points = [
        'Editorially reviewed',
        'The first verified point explains the central development.',
        'The second verified point supplies material context for readers.'
      ]
      summary_positions = summary_points.map { |point| values['excerpt'].index(point) }
      expect(summary_positions).to all(be_a(Integer))
      expect(summary_positions).to eq(summary_positions.sort)
      expect(values['excerpt'].each_grapheme_cluster.count).to be_between(80, 280)
      expect(values).to include('roots' => 1, 'paragraphs' => 3, 'listItems' => 0, 'ambiguousRoots' => 0)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'rejects blocked and empty explicit summary regions' do
    html = <<~HTML
      <main>
        <aside class="widget article-summary"><p>Editorially reviewed</p><p>Widget-owned detail is not article summary material.</p></aside>
        <dialog class="article-summary"><p>Editorially reviewed</p><p>Dialog-owned detail is not article summary material.</p></dialog>
        <section class="category article-summary"><p>Editorially reviewed</p><p>Category-owned detail is not article summary material.</p></section>
        <nav class="article-summary"><p>Editorially reviewed</p><p>Navigation-owned detail is not article summary material.</p></nav>
      </main>
    HTML

    with_page(html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: readability_excerpt_source)
      values = page.evaluate(<<~JS)
        (() => {
          const blocked = document.cloneNode(true);
          window.__markReadabilityExcerptSources(blocked);
          const empty = document.cloneNode(true);
          const emptyMarker = window.__markReadabilityExcerptSources(empty);
          const emptyMain = empty.querySelector('main');
          const emptyExcerpt = window.__readabilityArticleExcerpt({
            excerpt: '',
            content: emptyMain.outerHTML,
            textContent: emptyMain.textContent
          }, null, emptyMarker);
          return [
            blocked.querySelectorAll('[data-fetchutil-excerpt-summary-root]').length,
            emptyExcerpt === null
          ];
        })()
      JS

      expect(values).to eq([0, true])
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'selects a substantive lead inside detail-body wrappers after a category and editorial note' do
    lead = 'The wildfire response continues across several regions as crews protect communities and contain the affected area.'
    later = 'Officials described the response and the continuing work at the scene in detail.' * 6
    html = <<~HTML
      <article>
        <div class="detail-content">
          <div class="detail-body">
            <p>National</p><p>News</p>
            <p>Based on facts observed and verified directly by our journalists.</p>
            <p>08 Jul 2026</p>
            <p>#{lead}</p><p>#{later}</p>
            <section class="related"><p>Unrelated recommendation must not become the excerpt.</p></section>
          </div>
        </div>
      </article>
    HTML

    with_url_page('https://publisher.example/report', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: readability_excerpt_source)
      values = page.evaluate(<<~JS)
        (() => {
          const clone = document.cloneNode(true);
          const marker = window.__markReadabilityExcerptSources(clone);
          const article = clone.querySelector('article');
          return {
            excerpt: window.__readabilityArticleExcerpt({
              excerpt: 'National', content: article.outerHTML,
              textContent: article.textContent
            }, null, marker),
            marked: Array.from(article.querySelectorAll('p[data-fetchutil-excerpt-body]'))
              .map(node => node.textContent.trim())
          };
        })()
      JS

      expect(values.fetch('excerpt')).to eq(lead)
      expect(values.fetch('marked')).to include(lead, later)
      expect(values.fetch('marked')).not_to include('Unrelated recommendation must not become the excerpt.')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'uses a complete visible adjacent header summary only for the fully owned Reader article' do
    title = 'NewsIT report'
    excerpt = 'Γέλια και χειραψίες ανάμεσα στους δύο ηγέτες - Υποδοχή με ισχυρό συμβολισμό'
    body = [
      'The two leaders met at the official welcome ceremony, exchanging greetings and handshakes before the scheduled talks began.',
      'Officials described the meeting as an important public signal and said the delegations would continue their discussions later that day.',
      'The reception included a formal ceremony, remarks from both sides, and several meetings attended by senior members of each delegation.'
    ]
    html = <<~HTML
      <html><head><title>#{title}</title><meta name="description" content="Metadata says a different phrase."></head>
      <body class="single-post">
        <header><h1 class="entry-title">#{title}</h1><div class="article-excerpt">#{excerpt}</div></header>
        <main class="main-content column gap-md">
          <article id="post-4722536" class="post type-post status-publish category-kosmos">
            <div class="share-inside-the-content">Share Tweet WhatsApp</div>
            <div class="inside-article column start-center gap-md">
              <a href="https://www.google.com/preferences/source?q=newsit.gr">Προσθήκη του newsit.gr ως προτεινόμενη πηγή στην Google</a>
              <div class="entry-content"><section>#{body.map { |text| "<p>#{text}</p>" }.join}</section></div>
            </div>
          </article>
          <article class="round-box"><h2>Άλλη είδηση με διαφορετικό θέμα</h2></article>
        </main>
      </body>
      </html>
    HTML

    with_url_page('https://www.newsit.gr/politiki/report/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      vendor = File.read(File.join(File.expand_path('../../..', __dir__), 'lib/fetch_util/assets/vendor/readability.js'))
      page.add_script_tag(content: vendor)
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var metadata = {title: "NewsIT report", excerpt: "metadata is not visible prose"};
          var content = window.__readabilityContent(metadata);
          var paragraphs = content.sourceOwnedReaderBodyParagraphSources || [];
          var evidence = {
            sourceParagraphs: paragraphs,
            unmappedHeaderParagraphs: content.sourceOwnedReaderUnmappedHeaderParagraphs || [],
            unmappedTrailingParagraphs: content.sourceOwnedReaderUnmappedTrailingParagraphs || []
          };
          var choose = window.__sourceOwnedReaderAdjacentHeaderExcerpt;
          var selectedSummary = choose(content, evidence, metadata);
          var conflictingTitle = choose(content, evidence, Object.assign({}, metadata, {title: "Different title"}));
          var reordered = choose(content, Object.assign({}, evidence, {sourceParagraphs: paragraphs.slice().reverse()}), metadata);
          var foreign = document.createElement("p");
          foreign.textContent = "Short foreign note.";
          var otherArticle = document.querySelector(".round-box");
          otherArticle.appendChild(foreign);
          var competingRecord = choose(content, evidence, metadata);
          var mixedRecord = choose(content, Object.assign({}, evidence, {sourceParagraphs: paragraphs.concat([foreign])}), metadata);
          foreign.remove();
          var header = document.querySelector("header");
          var priorStyle = header.getAttribute("style");
          header.setAttribute("style", "display: none");
          var hiddenHeader = choose(content, evidence, metadata);
          if (priorStyle === null) header.removeAttribute("style");
          else header.setAttribute("style", priorStyle);
          var summary = header.querySelector(".article-excerpt");
          var priorSummary = summary.textContent;
          var longSummary = Array.from({length: 12}, function(_unused, index) {
            return "Distinct source detail " + (index + 1) + " records a verified point for this report.";
          }).join(" ");
          summary.textContent = longSummary;
          var unbounded = choose(content, evidence, metadata);
          summary.textContent = priorSummary;
          var aside = document.createElement("aside");
          header.insertBefore(aside, summary);
          aside.appendChild(summary);
          var asideSummary = choose(content, evidence, metadata);
          header.insertBefore(summary, aside);
          aside.remove();
          var foreignArticle = document.createElement("article");
          header.insertBefore(foreignArticle, summary);
          foreignArticle.appendChild(summary);
          var nestedArticleSummary = choose(content, evidence, metadata);
          header.insertBefore(summary, foreignArticle);
          foreignArticle.remove();
          var controlBranch = document.createElement("div");
          controlBranch.setAttribute("role", "button");
          header.insertBefore(controlBranch, summary);
          controlBranch.appendChild(summary);
          var controlBranchSummary = choose(content, evidence, metadata);
          header.insertBefore(summary, controlBranch);
          controlBranch.remove();
          summary.innerHTML = "<button>Continue reading</button>";
          var controlOnlySummary = choose(content, evidence, metadata);
          summary.textContent = priorSummary;
          var priorClass = summary.className;
          summary.className = "unmarked-copy";
          var labelAlone = choose(content, evidence);
          summary.className = priorClass;
          return {
            excerpt: content.excerpt,
            heading: document.querySelector("header h1").textContent.trim(),
            readerMode: content.readerMode,
            bodyParagraphCount: paragraphs.length,
            mappedBody: paragraphs.map(function(paragraph) { return paragraph.textContent.trim(); }),
            selectedSummary: selectedSummary,
            conflictingTitle: conflictingTitle,
            reordered: reordered,
            competingRecord: competingRecord,
            mixedRecord: mixedRecord,
            hiddenHeader: hiddenHeader,
            unbounded: unbounded,
            asideSummary: asideSummary,
            nestedArticleSummary: nestedArticleSummary,
            controlBranchSummary: controlBranchSummary,
            controlOnlySummary: controlOnlySummary,
            labelAlone: labelAlone
          };
        })())
      JS
      expect(values['heading']).to eq(title)
      expect(values['excerpt']).to eq(excerpt)
      expect(values['readerMode']).to be(true)
      expect(values['bodyParagraphCount']).to be >= 2
      expect(values['mappedBody']).to eq(body)
      expect(values['selectedSummary']).to eq(excerpt)
      expect(values['conflictingTitle']).to be_nil
      expect(values['reordered']).to be_nil
      expect(values['competingRecord']).to be_nil
      expect(values['mixedRecord']).to be_nil
      expect(values['hiddenHeader']).to be_nil
      expect(values['unbounded']).to eq((1..12).map { |number| "Distinct source detail #{number} records a verified point for this report." }.join(' '))
      expect(values['unbounded'].length).to be > 280
      expect(values.values_at('asideSummary', 'nestedArticleSummary', 'controlBranchSummary', 'controlOnlySummary')).to eq([nil, nil, nil, nil])
      expect(values['labelAlone']).to be_nil
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end
end
