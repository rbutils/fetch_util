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
        global.__sourceOwnedReaderSelectedParagraphs = sourceOwnedReaderSelectedParagraphs;
        global.__readabilityOwnedArticleLeadExcerpt = readabilityOwnedArticleLeadExcerpt;
        global.__genericSourceOwnedPageContent = genericSourceOwnedPageContent;
        global.__readabilityOwnedSelectedPublication = readabilityOwnedSelectedPublication;
        global.__sourceOwnedFallbackPublication = sourceOwnedFallbackPublication;
        global.__sourceOwnedPrimaryArticleMaterial = sourceOwnedPrimaryArticleMaterial;
        global.__sourceOwnedPrimaryMarkdown = markdownFor;
        global.__readabilityMetadata = collectMetadata;
        global.__sourceOwnedReaderAnswerPublicationTime = sourceOwnedReaderAnswerPublicationTime;
        global.__sourceOwnedLeadingQuestionAnswerPublicationTime = sourceOwnedLeadingQuestionAnswerPublicationTime;
        global.__collectMetadata = collectMetadata;
        global.__sourceOwnedPublicationDatesEquivalent = sourceOwnedPublicationDatesEquivalent;
        global.__finalizeExtractResult = finalizeExtractResult;
        global.__collectionPublishedTime = collectionPublishedTime;
      JS
    end.join("\n")
  end

  it 'uses the proved service parent to retain ordered visible context and declines unowned material' do
    lead = 'A brief service lead retains its inline citation and exact source position.'
    verified_terms = "Verified service terms remain available in the public record. "
    primary_detail = "Service offer details document every current limit and option for readers. #{verified_terms * 5}" \
      '<a href="/documents/service.pdf">Complete service terms</a>.'
    features = (1..3).map do |index|
      %(<div><h3>Service feature #{index}</h3><p>Feature #{index} explains a distinct option in the service.</p></div>)
    end.join
    html = <<~HTML
      <!doctype html><html><head><title>Service offer</title></head><body>
        <div class="service-surface">
          <main id="primary"><div class="primary-copy">
            <h1>Service offer</h1><p>#{lead.gsub("citation", '<a href="/sources/brief">citation</a>')}</p>
            <p>#{primary_detail}</p>
            <img src="/media/promo-service.png" alt="Service illustration">
            <table><tbody><tr><th>Limit</th><td>Source table term</td></tr></tbody></table>
          </div></main>
          <section class="feature-group">#{features}</section>
          <section class="calculator"><h1>Payment calculator</h1>
            <label>Amount<input type="number" value="30"></label>
            <select aria-label="Payment rate"><option>Monthly</option></select>
            <button type="button">Calculate</button>
            <select aria-label="Payment term"><option>Six months</option></select>
          </section>
          <section class="service-faq"><h2>Service questions</h2><p>Common question context remains before its controls.</p>
            <div><a href="javascript:void(0)" class="accordion-header">Question one trigger</a></div>
            <div><a href="javascript:void(0)" class="accordion-header">Question two trigger</a></div>
            <div id="answer-one" hidden><p>Collapsed answer body must remain hidden.</p></div>
            <figure><img src="/media/service-guide.png" alt="Service guide"></figure>
          </section>
          <div class="service-diagram"><img src="/media/service-comparison.png" alt=""></div>
        </div>
        <section class="public-review"><p>Public reviewer reply outside the service parent is already selected.</p></section>
        <div class="foreign-sibling"><h2>Unrelated sibling</h2><p>Unrelated material remains outside the service parent.</p></div>
      </body></html>
    HTML

    with_url_page('https://unknown.example/service', html) do |page|
      page.add_script_tag(path: File.expand_path('../../../lib/fetch_util/assets/vendor/turndown.js', __dir__))
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var primary = document.querySelector('#primary');
          var source = window.__sourceOwnedPrimaryArticleMaterial;
          var candidate = {
            contentType: 'article', readerMode: true, title: 'Payment calculator',
            html: primary.outerHTML,
            markdown: window.__sourceOwnedPrimaryMarkdown(primary.outerHTML),
            textContent: primary.textContent
          };
          var retained = source(candidate, {title: document.title, siteName: 'unknown.example'});
          var selectedReview = Object.assign({}, candidate, {
            html: candidate.html + document.querySelector('.public-review').outerHTML,
            markdown: window.__sourceOwnedPrimaryMarkdown(candidate.html + document.querySelector('.public-review').outerHTML)
          });
          var reviewResult = source(selectedReview, {title: document.title, siteName: 'unknown.example'});
          var selectedUnknown = ['Visible unowned bare text', '<div>Brief unowned note</div>',
            '<p>Short unknown note</p>', '<a href="/foreign.pdf">Foreign PDF</a>',
            '<img src="/foreign.png" alt="Foreign media">', '<input aria-label="Unowned input">'];
          var unknownDeclined = selectedUnknown.map(function(material) {
            var selected = Object.assign({}, candidate, {
              html: candidate.html + material,
              markdown: window.__sourceOwnedPrimaryMarkdown(candidate.html + material),
              textContent: primary.textContent + ' ' + material.replace(/<[^>]*>/g, '')
            });
            return source(selected, {title: document.title, siteName: 'unknown.example'}) === selected;
          });
          var hidden = document.createElement('p');
          hidden.hidden = true;
          hidden.textContent = 'Visible selected duplicate must not match hidden source';
          document.querySelector('.service-surface').appendChild(hidden);
          var selectedHidden = Object.assign({}, candidate, {
            html: candidate.html + '<p>Visible selected duplicate must not match hidden source</p>',
            markdown: window.__sourceOwnedPrimaryMarkdown(candidate.html + '<p>Visible selected duplicate must not match hidden source</p>')
          });
          var hiddenDeclined = source(selectedHidden, {title: document.title, siteName: 'unknown.example'}) === selectedHidden;
          hidden.remove();
          var foreignMedia = document.createElement('div');
          foreignMedia.innerHTML = '<img src="https://foreign.example/service-comparison.png" alt="">';
          document.querySelector('.service-surface').appendChild(foreignMedia);
          var foreignMediaDeclined = source(candidate, {title: document.title, siteName: 'unknown.example'}) === candidate;
          foreignMedia.remove();
          var finalized = window.__finalizeExtractResult(retained, window.__readabilityMetadata(), document.body.textContent, {}, null);
          return {
            source_owned: !!retained.sourceOwnedPrimaryPage,
            title: retained.title,
            html: retained.html,
            markdown: retained.markdown,
            excerpt: retained.excerpt,
            finalized_html: finalized.html,
            finalized_markdown: finalized.markdown,
            review_declined: reviewResult === selectedReview,
            unknown_declined: unknownDeclined,
            hidden_declined: hiddenDeclined,
            foreign_media_declined: foreignMediaDeclined,
            original_dom_unchanged: document.querySelector('#answer-one').hidden &&
              document.querySelector('.service-faq').querySelector('a.accordion-header') !== null
          };
        })())
      JS

      expect(values['source_owned']).to be(true)
      expect(values['title']).to eq('Service offer')
      expect(values['excerpt']).to eq('A brief service lead retains its inline citation and exact source position.')
      expect(values['html']).to include('Complete service terms', 'Source table term', 'Service feature 3', 'Question one trigger', 'Service guide')
      expect(values['html']).not_to include('Collapsed answer body', 'Public reviewer reply', 'Unrelated sibling')
      expect(values['html']).to include('Question one trigger', 'Question two trigger')
      expect(values['html']).not_to include('javascript:void(0)')
      expect(values['markdown']).to include('Service offer details document every current limit')
      expect(values['markdown']).to include('Complete service terms', 'Service illustration', 'Source table term')
      expect(values['markdown']).to include('## Service questions', 'Question one trigger')
      expect(values['markdown']).to include('![Image](https://unknown.example/media/service-comparison.png)')
      expect(values['finalized_html']).to include('Question one trigger')
      expect(values['finalized_html']).not_to include('javascript:void(0)', 'Collapsed answer body')
      expect(values['finalized_markdown']).to include('Question one trigger')
      expect(values['markdown'].index('Service feature 3')).to be < values['markdown'].index('Payment calculator')
      expect(values['markdown'].index('Payment calculator')).to be < values['markdown'].index('Service questions')
      expect(values['review_declined']).to be(true)
      expect(values['unknown_declined']).to all(be(true))
      expect(values['hidden_declined']).to be(true)
      expect(values['foreign_media_declined']).to be(true)
      expect(values['original_dom_unchanged']).to be(true)
    end
  end

  it 'declines a foreign editorial section inside an otherwise plausible service component' do
    text = 'Service offer verifies complete public terms and source references. ' * 10
    html = <<~HTML
      <html><head><title>Service offer</title></head><body><div class="service-surface">
        <main id="primary"><h1>Service offer</h1><p>#{text}</p><p>#{text}</p>
          <a href="/terms">Full terms</a><a href="/policy">Policy</a></main>
        <section><h2>Distinct features</h2><h3>First feature</h3>
          <p>First feature description.</p><p>Second feature description.</p></section>
        <section><h1>Payment calculator</h1><form><input type="number"><button>Calculate</button></form></section>
        <section class="unrelated"><h2>Editorial dispatch</h2><p>Independent article material.</p></section>
      </div></body></html>
    HTML
    with_url_page('https://unknown.example/service', html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      declined = page.evaluate(<<~JS)
        (function() {
          var main = document.querySelector('#primary');
          var selected = {contentType: 'article', readerMode: true, title: document.title,
            html: main.outerHTML, markdown: window.__sourceOwnedPrimaryMarkdown(main.outerHTML),
            textContent: main.textContent};
          return window.__sourceOwnedPrimaryArticleMaterial(selected, {title: document.title,
            siteName: 'unknown.example'}) === selected;
        })()
      JS
      expect(declined).to be(true)
    end
  end

  it 'declines a title-matching main beside an unrelated long section without a unique calculator owner' do
    unrelated_detail = "Each section remains part of the unrelated container, not the service owner. "
    detail = "Service offer includes a full public account with source links and verified terms. #{unrelated_detail * 8}"
    detail += '<a href="/documents/one.pdf">First document</a> <a href="/documents/two.pdf">Second document</a>.'
    html = <<~HTML
      <!doctype html><html><head><title>Service offer</title></head><body><div class="outer">
        <main id="primary"><div><h1>Service offer</h1><p>#{detail}</p></div></main>
        <section class="foreign"><h2>Unrelated section</h2><p>#{"Foreign material has no calculator relationship. " * 5}</p></section>
      </div></body></html>
    HTML

    with_url_page('https://unknown.example/service', html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var primary = document.querySelector('#primary');
          var candidate = {contentType: 'article', readerMode: true, title: document.title,
            html: primary.outerHTML, markdown: window.__sourceOwnedPrimaryMarkdown(primary.outerHTML),
            textContent: primary.textContent};
          var result = window.__sourceOwnedPrimaryArticleMaterial(candidate, {title: document.title, siteName: 'unknown.example'});
          return {same_candidate: result === candidate, source_owned: !!result.sourceOwnedPrimaryPage};
        })())
      JS

      expect(values['same_candidate']).to be(true)
      expect(values['source_owned']).to be(false)
    end
  end

  def source_publication_article_html(
    headline:, canonical_url:, structured_data:, header_date: nil, schedule_date: nil, aside_date: nil
  )
    header_date_markup = header_date ? %(<time datetime="#{header_date}">#{header_date}</time>) : ""
    schedule_markup = schedule_date ? %(<div class="event-schedule"><time datetime="#{schedule_date}">#{schedule_date}</time></div>) : ""
    aside_markup = aside_date ? %(<aside class="related-card"><time datetime="#{aside_date}">#{aside_date}</time></aside>) : ""

    <<~HTML
      <!doctype html>
      <html><head><title>#{headline}</title><link rel="canonical" href="#{canonical_url}">
      <script type="application/ld+json">#{structured_data}</script></head>
      <body><main><article><header><h1>#{headline}</h1>#{header_date_markup}#{schedule_markup}</header>
      <div class="article-body" itemprop="articleBody">
        <p>The source-owned article states its primary findings and explains the verified reporting context in a complete paragraph for readers.</p>
        <p>A second source-owned paragraph supplies additional reporting detail and confirms that the visible body is complete and ordered.</p>
      </div>#{aside_markup}</article></main></body></html>
    HTML
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

  it 'uses short Reader leads only when the complete selected paragraphs share a proved article body' do
    short_lead = 'Officials confirmed the shipment cleared inspection.'
    long_body = 'The report describes the verified findings and their consequences for local residents. ' * 12
    title = 'Source-owned report'
    html = <<~HTML
      <main><article>
        <header><h1>#{title}</h1></header>
        <div class="article-body"><p>#{short_lead}</p><p>#{long_body}</p></div>
      </article></main>
    HTML
    byline_html = <<~HTML
      <main><article>
        <header><h1>#{title}</h1><p class="byline">By Reporter Name</p></header>
        <div class="article-body"><p>#{long_body}</p></div>
      </article></main>
    HTML
    credit_html = <<~HTML
      <main><article>
        <header><h1>#{title}</h1></header>
        <figure><figcaption><p class="photo-credit">Photo credit: Staff</p></figcaption></figure>
        <div class="article-body"><p>#{long_body}</p></div>
      </article></main>
    HTML
    narrative_html = <<~HTML
      <main><article>
        <header><h1>#{title}</h1></header>
        <div class="article-body">
          <div class="related-story"><p>Background material from a separate story is not this report's body lead.</p></div>
          <p>#{long_body}</p>
        </div>
      </article></main>
    HTML

    with_url_page('https://publisher.example/source-owned-lead', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: readability_excerpt_source)
      positive = JSON.parse(page.evaluate(<<~JS))
        (function() {
          var marker = 'short-source-lead';
          var title = #{title.to_json};
          var sourceParagraphs = Array.from(document.querySelectorAll('article p'));
          var selected = document.createElement('div');
          var sourceClones = new Map();
          var sourceIdentities = new Map();
          sourceParagraphs.forEach(function(source, index) {
            var clone = source.cloneNode(true);
            clone.setAttribute('data-fetchutil-reader-source-paragraph', marker + ':' + index);
            clone.setAttribute('data-fetchutil-excerpt-body', marker);
            selected.appendChild(clone);
            sourceClones.set(source, clone);
            sourceIdentities.set(source, {
              id: marker + ':' + index,
              unique: true,
              visibleText: (source.textContent || '').replace(/\s+/g, ' ').trim(),
              breakSegments: null
            });
          });
          var evidence = window.__sourceOwnedReaderSelectedParagraphs(
            selected, sourceClones, sourceIdentities, marker, true
          );
          var article = {
            title: title,
            excerpt: 'More material from the latest coverage.',
            content: selected.innerHTML,
            textContent: selected.textContent
          };
          var metadata = {title: title};
          return JSON.stringify({
            evidenceCount: evidence && evidence.sourceParagraphs.length,
            excerpt: window.__readabilityArticleExcerpt(article, metadata, marker, evidence),
            ownedLead: window.__readabilityOwnedArticleLeadExcerpt(article, metadata, marker, evidence)
          });
        })()
      JS

      expect(positive).to include(
        'evidenceCount' => 2,
        'excerpt' => short_lead,
        'ownedLead' => short_lead
      )
      expect(page.evaluate('document.body.outerHTML')).to eq(before)

      negatives = JSON.parse(page.evaluate(<<~JS))
        (function() {
          var marker = 'short-source-lead-negative';
          var title = #{title.to_json};
          var cases = #{[byline_html, credit_html, narrative_html].to_json};
          return JSON.stringify(cases.map(function(markup) {
            document.body.innerHTML = markup;
            var sourceParagraphs = Array.from(document.querySelectorAll('article p'));
            var selected = document.createElement('div');
            var sourceClones = new Map();
            var sourceIdentities = new Map();
            sourceParagraphs.forEach(function(source, index) {
              var clone = source.cloneNode(true);
              clone.setAttribute('data-fetchutil-reader-source-paragraph', marker + ':' + index);
              clone.setAttribute('data-fetchutil-excerpt-body', marker);
              selected.appendChild(clone);
              sourceClones.set(source, clone);
              sourceIdentities.set(source, {
                id: marker + ':' + index,
                unique: true,
                visibleText: (source.textContent || '').replace(/\s+/g, ' ').trim(),
                breakSegments: null
              });
            });
            var evidence = window.__sourceOwnedReaderSelectedParagraphs(
              selected, sourceClones, sourceIdentities, marker, true
            );
            return window.__readabilityOwnedArticleLeadExcerpt({
              title: title,
              excerpt: 'More material from the latest coverage.',
              content: selected.innerHTML,
              textContent: selected.textContent
            }, {title: title}, marker, evidence);
          }));
        })()
      JS

      expect(negatives).to eq([nil, nil, nil])
    end
  end

  it 'uses the complete first source-owned fallback body paragraph without truncating it' do
    title = 'Complete source article'
    url = 'https://publisher.example/complete-body-lead'
    lead = ('The verified report explains the full source-owned development and its consequences for affected communities. ' * 8).strip
    continuation = ('Officials said the review will continue with additional public findings. ' * 4).strip
    schema = {
      '@context' => 'https://schema.org',
      '@type' => 'NewsArticle',
      'url' => url,
      'headline' => title,
      'articleBody' => "#{lead} #{continuation}"
    }.to_json
    html = <<~HTML
      <html><head>
        <link rel="canonical" href="#{url}">
        <script type="application/ld+json">#{schema}</script>
      </head><body><main><article>
        <header><h1>#{title}</h1></header>
        <div class="article-body" itemprop="articleBody">
          <figure><figcaption><p>Photo credit: Staff image archive.</p></figcaption></figure>
          <p>#{lead}</p><p>#{continuation}</p>
        </div>
      </article></main></body></html>
    HTML

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.outerHTML')
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        (function() {
          var content = window.__genericSourceOwnedPageContent({
            title: #{title.to_json},
            siteName: 'publisher.example'
          });
          return JSON.stringify({
            excerpt: content && content.excerpt,
            unchanged: document.body.outerHTML === #{before.to_json}
          });
        })()
      JS

      expect(values['excerpt']).to eq(lead)
      expect(values['excerpt'].length).to be > 280
      expect(values['unchanged']).to be(true)
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

  it 'preserves a matching source Article publication date without requiring a record URL' do
    headline = 'Coin research report'
    published = '2026-04-14T00:00:00Z'
    structured_data = JSON.generate('@type' => 'NewsArticle', 'headline' => headline, 'datePublished' => published)
    canonical_url = 'https://publisher.example/articles/coin-research'
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var headline = "Coin research report";
          var metadata = {title: headline, canonicalUrl: location.href, siteName: "publisher.example"};
          var article = document.querySelector("article");
          var paragraphs = Array.from(article.querySelectorAll("[itemprop='articleBody'] p"));
          var reader = window.__readabilityOwnedSelectedPublication(
            {title: headline}, metadata, {sourceParagraphs: paragraphs, unmappedTrailingParagraphs: []}
          );
          var fallback = window.__genericSourceOwnedPageContent(metadata);
          return {
            reader: reader && reader.publishedTime,
            fallback: fallback && fallback.publishedTime,
            fallbackResolved: fallback && fallback.sourceOwnedArticlePublicationResolved
          };
        })())
      JS
      expect(values).to eq('reader' => published, 'fallback' => published, 'fallbackResolved' => true)
    end
  end

  it 'preserves the declared head timestamp when its owned Article record adds a timezone' do
    headline = 'Wall-clock publication report'
    published = '2026-01-30 10:09:00'
    structured_data = JSON.generate(
      '@type' => 'NewsArticle',
      'url' => 'https://publisher.example/articles/wall-clock',
      'headline' => headline,
      'datePublished' => '2026-01-30T10:09:00+00:00'
    )
    canonical_url = 'https://publisher.example/articles/wall-clock'
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data
    ).sub(
      "<link rel=\"canonical\" href=\"#{canonical_url}\">",
      "<link rel=\"canonical\" href=\"#{canonical_url}\"><meta property=\"article:published_time\" content=\"#{published}\">"
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          var headline = "Wall-clock publication report";
          var article = document.querySelector("article");
          var metadata = {title: headline, canonicalUrl: location.href};
          var publication = window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          });
          return publication && publication.publishedTime;
        })()
      JS
      expect(value).to eq(published)
    end
  end

  it 'does not equate zoned natural-language dates with unzoned dates without recognized wall clocks' do
    canonical_url = 'https://publisher.example/articles/date-equivalence'
    html = source_publication_article_html(
      headline: 'Date equivalence report', canonical_url: canonical_url, structured_data: '{}'
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = page.evaluate(<<~JS)
        ({
          naturalLanguageDifferentDays: window.__sourceOwnedPublicationDatesEquivalent(
            'Tue, 22 Sep 2026 15:20:42 GMT', '23 Sep 2026 15:20:42'
          ),
          matchingIsoWallClock: window.__sourceOwnedPublicationDatesEquivalent(
            '2026-09-22T15:20:42Z', '2026-09-22 15:20:42'
          )
        })
      JS
      expect(values).to eq(
        'naturalLanguageDifferentDays' => false,
        'matchingIsoWallClock' => true
      )
    end
  end

  it 'repairs malformed publication JSON only when its headline exactly matches the visible source H1' do
    headline = 'LiveTV says "Exact source headline"'
    malformed_json = %({"@type":"NewsArticle","headline":"LiveTV says "Exact source headline"","datePublished":"2026-09-22 23:35:38"})
    canonical_url = 'https://publisher.example/articles/livetv-report'
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: malformed_json
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var headline = 'LiveTV says "Exact source headline"';
          var metadata = {title: headline, canonicalUrl: location.href};
          var article = document.querySelector("article");
          var paragraphs = Array.from(article.querySelectorAll("[itemprop='articleBody'] p"));
          var evidence = {sourceParagraphs: paragraphs, unmappedTrailingParagraphs: []};
          var matching = window.__readabilityOwnedSelectedPublication({title: headline}, metadata, evidence);
          document.querySelector("h1").textContent = 'LiveTV says "Different headline"';
          metadata.title = document.querySelector("h1").textContent;
          var changedH1 = window.__readabilityOwnedSelectedPublication({title: metadata.title}, metadata, evidence);
          return {
            matching: matching && matching.publishedTime,
            changedH1: changedH1 && changedH1.publishedTime,
            changedH1Resolved: !!changedH1
          };
        })())
      JS
      expect(values).to eq(
        'matching' => '2026-09-22 23:35:38',
        'changedH1' => nil,
        'changedH1Resolved' => true
      )
    end
  end

  it 'keeps an owned visible header date when optional publication JSON is invalid' do
    headline = 'Visible date with invalid optional data'
    visible_date = '2026-09-23T02:35:38+03:00'
    invalid_data = %({"@type":"NewsArticle","headline":"A different record",)
    canonical_url = 'https://publisher.example/articles/invalid-optional-data'
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: invalid_data,
      header_date: visible_date
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var headline = "Visible date with invalid optional data";
          var article = document.querySelector("article");
          var paragraphs = Array.from(article.querySelectorAll("[itemprop='articleBody'] p"));
          var metadata = {title: headline, canonicalUrl: location.href};
          var evidence = {sourceParagraphs: paragraphs};
          var reader = window.__readabilityOwnedSelectedPublication({title: headline}, metadata, evidence);
          var fallback = window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          });
          return {reader: reader && reader.publishedTime, fallback: fallback && fallback.publishedTime};
        })())
      JS
      expect(values).to eq('reader' => visible_date, 'fallback' => visible_date)
    end
  end

  it 'keeps a matching Article date despite unrelated and malformed JSON-LD records' do
    headline = 'Article with an unrelated malformed record'
    published = '2026-07-07T12:47:18+02:00'
    canonical_url = 'https://publisher.example/articles/matching-record'
    structured_data = JSON.generate(
      '@type' => 'NewsArticle',
      'mainEntityOfPage' => { '@id' => canonical_url },
      'headline' => headline,
      'datePublished' => published
    )
    unrelated_record = JSON.generate(
      '@type' => 'NewsArticle',
      'url' => 'https://publisher.example/articles/unrelated',
      'headline' => 'Unrelated child article',
      'datePublished' => '2026-07-01'
    )
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data
    ).sub(
      '</head>',
      "<script type=\"application/ld+json\">#{unrelated_record}</script>" \
      '<script type="application/ld+json">{"@type":"Thing",</script></head>'
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          var headline = "Article with an unrelated malformed record";
          var article = document.querySelector("article");
          var metadata = {title: headline, canonicalUrl: location.href};
          return window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          }).publishedTime;
        })()
      JS
      expect(value).to eq(published)
    end
  end

  it 'keeps the exact owned header time and ignores a foreign card date' do
    headline = 'Visible publication report'
    visible_date = '2026-09-23T02:35:38+03:00'
    structured_data = JSON.generate(
      '@type' => 'NewsArticle',
      'headline' => headline,
      'datePublished' => '2026-09-22T23:35:38Z'
    )
    canonical_url = 'https://publisher.example/articles/visible-publication'
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data,
      header_date: visible_date,
      aside_date: '2026-08-26T00:00:00Z'
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var headline = "Visible publication report";
          var metadata = {title: headline, canonicalUrl: location.href};
          var article = document.querySelector("article");
          var paragraphs = Array.from(article.querySelectorAll("[itemprop='articleBody'] p"));
          var reader = window.__readabilityOwnedSelectedPublication(
            {title: headline}, metadata, {sourceParagraphs: paragraphs}
          );
          var fallback = window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          });
          return {reader: reader && reader.publishedTime, fallback: fallback && fallback.publishedTime};
        })())
      JS
      expect(values).to eq('reader' => visible_date, 'fallback' => visible_date)
    end
  end

  it 'prefers the owned header date when an exact Article URL has a conflicting secondary URL and date' do
    headline = 'Article with one authoritative page URL'
    visible_date = '2026-09-23T02:35:38+03:00'
    canonical_url = 'https://publisher.example/articles/authoritative-url'
    structured_data = JSON.generate(
      '@type' => 'NewsArticle',
      'url' => canonical_url,
      'mainEntityOfPage' => { 'url' => 'https://publisher.example/articles/another-story' },
      'headline' => headline,
      'datePublished' => '2026-09-21T18:10:00Z'
    )
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data,
      header_date: visible_date
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          var headline = "Article with one authoritative page URL";
          var article = document.querySelector("article");
          var metadata = {title: headline, canonicalUrl: location.href};
          return window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          }).publishedTime;
        })()
      JS
      expect(value).to eq(visible_date)
    end
  end

  it 'accepts an exact main-entity URL when the Article omits its direct URL' do
    headline = 'Article with a main-entity page URL'
    published = '2026-07-07T12:47:18+02:00'
    canonical_url = 'https://publisher.example/articles/main-entity-url'
    structured_data = JSON.generate(
      '@type' => 'NewsArticle',
      'mainEntityOfPage' => { '@id' => canonical_url },
      'headline' => headline,
      'datePublished' => published
    )
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          var headline = "Article with a main-entity page URL";
          var article = document.querySelector("article");
          var metadata = {title: headline, canonicalUrl: location.href};
          return window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          }).publishedTime;
        })()
      JS
      expect(value).to eq(published)
    end
  end

  it 'declines conflicting or nested Article publication records' do
    headline = 'Conflicting article record'
    canonical_url = 'https://publisher.example/articles/conflicting-record'
    foreign_record = JSON.generate(
      '@type' => 'NewsArticle',
      'url' => 'https://other.example/articles/foreign-record',
      'headline' => headline,
      'datePublished' => '2026-06-12'
    )
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: foreign_record
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var headline = "Conflicting article record";
          var metadata = {title: headline, canonicalUrl: location.href};
          var article = document.querySelector("article");
          var paragraphs = Array.from(article.querySelectorAll("[itemprop='articleBody'] p"));
          var evidence = {sourceParagraphs: paragraphs};
          var foreignUrl = window.__readabilityOwnedSelectedPublication({title: headline}, metadata, evidence);
          var script = document.querySelector("script[type='application/ld+json']");
          script.textContent = JSON.stringify({"@graph": [
            {"@type": "NewsArticle", "headline": headline, "datePublished": "2026-06-12"},
            {"@type": "Article", "headline": headline, "datePublished": "2026-06-12"}
          ]});
          var nestedRecords = window.__readabilityOwnedSelectedPublication({title: headline}, metadata, evidence);
          return {foreignUrl: foreignUrl, nestedRecords: nestedRecords};
        })())
      JS
      expect(values).to eq(
        'foreignUrl' => { 'publishedTime' => nil },
        'nestedRecords' => { 'publishedTime' => nil }
      )
    end
  end

  it 'does not replace a proven null article date with an event schedule or foreign card date' do
    headline = 'Article without publication date'
    structured_data = JSON.generate('@type' => 'NewsArticle', 'headline' => headline)
    canonical_url = 'https://publisher.example/articles/no-publication-date'
    html = source_publication_article_html(
      headline: headline,
      canonical_url: canonical_url,
      structured_data: structured_data,
      schedule_date: '2026-07-01T00:00:00Z',
      aside_date: '2026-08-26T00:00:00Z'
    )

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var headline = "Article without publication date";
          var metadata = {
            title: headline, canonicalUrl: location.href, siteName: "publisher.example",
            publishedTime: "August 26, 2026", byline: null
          };
          var article = document.querySelector("article");
          var publication = window.__sourceOwnedFallbackPublication(metadata, article, {
            node: article, visibleNode: article.cloneNode(true)
          });
          var content = {
            title: headline, byline: null, excerpt: "The article has a complete source-owned body.",
            siteName: "publisher.example", publishedTime: publication && publication.publishedTime,
            html: article.outerHTML, textContent: article.textContent,
            markdown: "# " + headline + "\\n\\n" + article.textContent,
            readerMode: false, contentType: "article", sourceOwnedFocalArticle: true,
            sourceOwnedArticlePublicationResolved: !!publication
          };
          var result = window.__finalizeExtractResult(content, metadata, document.body.textContent, {}, false);
          return {
            resolved: content.sourceOwnedArticlePublicationResolved,
            helperDate: publication && publication.publishedTime,
            finalDate: result.publishedTime
          };
        })())
      JS
      expect(values).to eq('resolved' => true, 'helperDate' => nil, 'finalDate' => nil)
    end
  end

  it 'preserves a visible publication date in a source-owned reader header without a semantic body selector' do
    headline = 'Reader-owned header date'
    canonical_url = 'https://publisher.example/reader-owned-date'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head>
      <body><main><header><h1>#{headline}</h1><p class="c-heading-date">September 10, 2026</p></header>
      <div><p>The first complete source paragraph identifies the selected article and its reporting context.</p>
      <p>The second complete source paragraph continues the same article body in source order.</p></div></main></body></html>
    HTML

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          var paragraphs = Array.from(document.querySelectorAll("main > div p"));
          return window.__readabilityOwnedSelectedPublication(
            {title: "Reader-owned header date"},
            {title: "Reader-owned header date", canonicalUrl: location.href},
            {sourceParagraphs: paragraphs}
          );
        })()
      JS
      expect(value).to eq('publishedTime' => 'September 10, 2026')
    end
  end

  it 'binds a relative answer timestamp to the exact reader-selected answer body' do
    headline = 'Which language is this?'
    canonical_url = 'https://publisher.example/questions/language'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
      <main><h1>#{headline}</h1>
      <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/selected">8y</a>
      <p>The selected answer explains the question in its first complete source paragraph.</p>
      <p>The same answer continues in this second complete paragraph in source order.</p></div>
      <div class="answer-record"><a class="answer_timestamp" href="https://publisher.example/questions/biology/answer/foreign">Sep 17</a>
      <p>A different question has a foreign answer with its own publication timestamp.</p></div></main></body></html>
    HTML

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          var paragraphs = Array.from(document.querySelector(".answer-record").querySelectorAll("p"));
          return window.__readabilityOwnedSelectedPublication(
            {title: "Which language is this?"},
            {title: "Which language is this?", canonicalUrl: location.href},
            {sourceParagraphs: paragraphs}
          );
        })()
      JS
      expect(value).to eq('publishedTime' => '8y')
    end
  end

  it 'does not assign a leading answer date to an empty reader body' do
    headline = 'Which language is this?'
    canonical_url = 'https://publisher.example/questions/language'
    html = <<~HTML
      <!doctype html><html><head><link rel="canonical" href="#{canonical_url}"></head><body>
      <main><h1>#{headline}</h1>
      <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/leading">8y</a>
      <p>The first complete answer paragraph establishes the answer's topic and selected owner.</p>
      <p>The second complete answer paragraph continues its explanation with substantial source prose.</p></div>
      <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/later">4y</a>
      <p>A later answer to the same question has a separate date and distinct prose.</p>
      <p>Its body is not the leading source answer represented by this page result.</p></div>
      <div class="answer-record"><a class="answer_timestamp" href="https://publisher.example/questions/biology/answer/foreign">Sep 17</a>
      <p>A different question has a foreign answer with its own publication timestamp.</p></div>
      </main></body></html>
    HTML

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      value = page.evaluate(<<~JS)
        (function() {
          return {
            selected: window.__readabilityOwnedSelectedPublication(
              {title: "Which language is this?"},
              {title: "Which language is this?", canonicalUrl: location.href},
              {sourceParagraphs: []}
            ),
            conflictingTitle: window.__readabilityOwnedSelectedPublication(
              {title: "Another question"},
              {title: "Which language is this?", canonicalUrl: location.href},
              {sourceParagraphs: []}
            )
          };
        })()
      JS
      expect(value['selected']).to be_nil
      expect(value['conflictingTitle']).to be_nil
    end
  end

  it 'binds a selected answer date to every source paragraph and lets a selected later answer win' do
    headline = 'Which language is this?'
    canonical_url = 'https://publisher.example/questions/language'
    html = <<~HTML
      <!doctype html><html><head><title>#{headline}</title>
      <link rel="canonical" href="#{canonical_url}"></head><body><main><section class="question-region">
      <h1>#{headline}</h1>
      <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/leading">8y</a>
        <p>The leading answer explains the language's design and history in its first source-owned paragraph.</p>
        <p>It continues with another substantial paragraph belonging to that same selected answer record.</p></div>
      <div class="answer-record"><a class="answer_timestamp" href="#{canonical_url}/answer/later">4y</a>
        <p>The second answer has a different date and a separate first paragraph in its own record.</p>
        <p>This paragraph remains part of the later selected answer rather than the leading answer.</p></div>
      <div class="answer-record"><a class="answer_timestamp" href="https://publisher.example/questions/biology/answer/foreign">Sep 17</a>
        <p>A foreign question answer has its own first paragraph and date.</p>
        <p>Its second paragraph belongs to that other question and must not be selected.</p></div>
      <aside><a class="answer_timestamp" href="#{canonical_url}/answer/aside">2y</a>
        <p>Aside timestamp context paragraph one.</p><p>Aside timestamp context paragraph two.</p></aside>
      <blockquote><a class="answer_timestamp" href="#{canonical_url}/answer/quoted">3y</a>
        <p>Quoted example paragraph one.</p><p>Quoted example paragraph two.</p></blockquote>
      <div hidden><a class="answer_timestamp" href="#{canonical_url}/answer/hidden">1y</a>
        <p>Hidden paragraph one.</p><p>Hidden paragraph two.</p></div>
      </section></main></body></html>
    HTML

    with_url_page(canonical_url, html) do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = page.evaluate(<<~JS)
        (function() {
          var canonical = location.href;
          var region = document.querySelector('.question-region');
          var answers = Array.from(region.querySelectorAll('.answer-record'));
          var first = Array.from(answers[0].querySelectorAll('p'));
          var second = Array.from(answers[1].querySelectorAll('p'));
          var foreign = Array.from(answers[2].querySelectorAll('p'));
          var metadata = __collectMetadata();
          var selected = __readabilityOwnedSelectedPublication(
            {title: "Which language is this?"}, metadata, {sourceParagraphs: second}
          );
          var content = {
            title: "Which language is this?", byline: null, excerpt: "Selected answer prose.",
            siteName: "publisher.example", publishedTime: selected.publishedTime,
            html: answers[1].outerHTML, textContent: answers[1].textContent,
            markdown: "Selected answer prose.", readerMode: true, contentType: "article",
            sourceOwnedArticlePublicationResolved: true
          };
          Object.defineProperty(content, "sourceOwnedReaderBodyParagraphSources", {value: second});
          var finalResult = __finalizeExtractResult(content, metadata, document.body.textContent, {}, false);
          return {
            metadataDate: metadata.publishedTime,
            metadataOwnerDate: metadata.sourceOwnedQuestionAnswerPublicationTime,
            first: __sourceOwnedReaderAnswerPublicationTime(first, canonical),
            second: __sourceOwnedReaderAnswerPublicationTime(second, canonical),
            mixed: __sourceOwnedReaderAnswerPublicationTime([first[0], second[0]], canonical),
            foreign: __sourceOwnedReaderAnswerPublicationTime([first[0], foreign[0]], canonical),
            hidden: __sourceOwnedReaderAnswerPublicationTime(
              first.concat(Array.from(region.querySelector('[hidden]').querySelectorAll('p'))), canonical
            ),
            nonParagraph: __sourceOwnedReaderAnswerPublicationTime([first[0], answers[0].querySelector('a'), first[1]], canonical),
            aside: __sourceOwnedReaderAnswerPublicationTime(
              Array.from(region.querySelector('aside').querySelectorAll('p')), canonical
            ),
            quoted: __sourceOwnedReaderAnswerPublicationTime(
              Array.from(region.querySelector('blockquote').querySelectorAll('p')), canonical
            ),
            emptyBody: __readabilityOwnedSelectedPublication(
              {title: "Which language is this?"}, metadata, {sourceParagraphs: []}
            ),
            selectedLater: selected && selected.publishedTime,
            finalLater: finalResult.publishedTime
          };
        })()
      JS
      expect(values).to eq(
        'metadataDate' => '8y', 'metadataOwnerDate' => '8y', 'first' => '8y', 'second' => '4y',
        'mixed' => '', 'foreign' => '', 'hidden' => '', 'nonParagraph' => '', 'aside' => '', 'quoted' => '',
        'emptyBody' => nil, 'selectedLater' => '4y', 'finalLater' => '4y'
      )
    end
  end
end
