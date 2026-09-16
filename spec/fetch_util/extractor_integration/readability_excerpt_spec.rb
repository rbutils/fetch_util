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
      JS
    end.join("\n")
  end

  it 'expands only short excerpts backed by substantial parsed article text' do
    with_url_page('https://publisher.example/article', '<main><h1>Daily dispatch</h1></main>') do |page|
      page.add_script_tag(content: readability_excerpt_source)
      values = JSON.parse(page.evaluate(<<~JS))
        JSON.stringify((function() {
          var short = "AI-generated, editorially reviewed";
          var longBody = short + " " + "Substantive verified reporting continues here. ".repeat(20);
          var original = window.Readability;
          window.Readability = function() {};
          window.Readability.prototype.parse = function() {
            return {
              title: "Daily dispatch",
              byline: "Reporter",
              excerpt: short,
              content: "<article><p>" + short + "</p><p>" + longBody + "</p></article>",
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
      expect(values['production'].length).to eq(280)
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
          var excerpt79 = "x".repeat(79);
          var excerpt80 = "x".repeat(80);
          var body399 = excerpt79 + "b".repeat(320);
          var body400 = excerpt79 + "b".repeat(321);
          var unicode = "🛰".repeat(400);
          return {
            excerpt79: window.__readabilityArticleExcerpt({
              excerpt: excerpt79,
              content: "<p>" + excerpt79 + "</p>",
              textContent: excerpt79 + "b".repeat(400)
            }),
            excerpt80: window.__readabilityArticleExcerpt({
              excerpt: excerpt80,
              content: "<p>" + excerpt80 + "</p>",
              textContent: excerpt80 + "b".repeat(400)
            }),
            body399: window.__readabilityArticleExcerpt({
              excerpt: excerpt79, content: "<p>" + excerpt79 + "</p>", textContent: body399
            }),
            body400: window.__readabilityArticleExcerpt({
              excerpt: excerpt79, content: "<p>" + excerpt79 + "</p>", textContent: body400
            }),
            unrelated: window.__readabilityArticleExcerpt({
              excerpt: "Concise editorial summary",
              content: "<p>Different article body.</p>",
              textContent: "Different article body. ".repeat(30)
            }),
            late: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<p>" + "Opening context. ".repeat(10) + "</p><p>Visible disclaimer</p>",
              textContent: "Opening context. ".repeat(10) + "Visible disclaimer " + "Reporting. ".repeat(30)
            }),
            repeatedAfterSentence: window.__readabilityArticleExcerpt({
              excerpt: "Concise editorial summary",
              content: "<p>Opening sentence.</p><p>Concise editorial summary</p>",
              textContent: "Opening sentence. Concise editorial summary " + "Reporting. ".repeat(30)
            }),
            prefix39: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<div>" + "p".repeat(39) + "</div><p>Visible disclaimer</p>",
              textContent: "p".repeat(39) + "Visible disclaimer " + "Reporting. ".repeat(40)
            }),
            prefix40: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<div>" + "p".repeat(40) + "</div><p>Visible disclaimer</p>",
              textContent: "p".repeat(40) + "Visible disclaimer " + "Reporting. ".repeat(40)
            }),
            unicodeSentence: window.__readabilityArticleExcerpt({
              excerpt: "Visible disclaimer",
              content: "<div>先行文。</div><p>Visible disclaimer</p>",
              textContent: "先行文。Visible disclaimer " + "Reporting. ".repeat(40)
            }),
            unicode: window.__readabilityArticleExcerpt({
              excerpt: "🛰".repeat(20), content: "<p>" + "🛰".repeat(20) + "</p>", textContent: unicode
            })
          };
        })())
      JS

      expect(values['excerpt79'].length).to eq(280)
      expect(values['excerpt80']).to eq('x' * 80)
      expect(values['body399']).to eq('x' * 79)
      expect(values['body400'].length).to eq(280)
      expect(values['unrelated']).to eq('Concise editorial summary')
      expect(values['late']).to eq('Visible disclaimer')
      expect(values['repeatedAfterSentence']).to eq('Concise editorial summary')
      expect(values['prefix39'].length).to eq(280)
      expect(values['prefix40']).to eq('Visible disclaimer')
      expect(values['unicodeSentence']).to eq('Visible disclaimer')
      expect(values['unicode'].each_char.count).to eq(280)
      expect(values['unicode']).to eq('🛰' * 280)
    end
  end
end
