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
end
