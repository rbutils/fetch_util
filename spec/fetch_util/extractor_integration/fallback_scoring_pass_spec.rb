# frozen_string_literal: true

RSpec.describe "FetchUtil fallback scoring pass" do
  include_context "extractor integration helpers"

  def fallback_scoring_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.checkFallbackScoring = function() {
        var best = null;
        genericArticleSelectors().forEach(function(selector) {
          document.querySelectorAll(selector).forEach(function(node) {
            var clone = cleanClone(visibilityPrunedClone(node, document));
            cleanupGenericArticleRoot(clone);
            var score = scoreNode(clone);
            if (!best || score > best.score) best = { node: node, score: score };
          });
        });
        var node = best && best.score > -Infinity ? best.node : document.body;
        var clone = cleanClone(visibilityPrunedClone(node, document));
        var comments = fallbackFocalArticleRoot(clone) ? visibleCommentMarkup(document) : "";
        prepareFallbackInlineProse(clone);
        cleanupGenericArticleRoot(clone);
        prepareFallbackInlineProse(clone);
        cleanupFallbackArticleChrome(clone);
        if (comments) clone.insertAdjacentHTML("beforeend", comments);
        var original = visibilityPrunedClone;
        var calls = 0;
        visibilityPrunedClone = function() { calls += 1; return original.apply(this, arguments); };
        var result;
        try { result = fallbackContent(); } finally { visibilityPrunedClone = original; }
        return { equal: result.html === clone.innerHTML, calls: calls, html: result.html };
      };
      })(window);
    JAVASCRIPT
  end

  it "scores uncapped overlapping roots from one pruned body without changing the winner" do
    records = (0...125).map do |index|
      "<div class='entry-content article-content'><h2>Record #{index}</h2>" \
        "<p>#{"Observed measurements and reproducible results provide substantive local context. " * 4}</p></div>"
    end.join
    html = <<~HTML
      <html><body><main id="main" class="main-content"><h1>Research observations</h1>#{records}
      <div hidden><p>Hidden ancestor material must not appear.</p></div>
      <div style="visibility:hidden"><p>Inherited hidden material.</p>
      <p style="visibility:visible">Explicitly visible descendant remains material.</p></div>
      <div style="opacity:0"><p>Inactive material must not appear.</p></div></main></body></html>
    HTML
    with_url_page("https://research.example/article", html) do |page|
      page.add_script_tag(content: fallback_scoring_source)
      result = page.evaluate("checkFallbackScoring()")
      expect(result).to include("equal" => true, "calls" => 2)
      expect(result.fetch("html").scan(%r{<h2>Record \d+</h2>})).to eq((0...125).map { |index| "<h2>Record #{index}</h2>" })
      expect(result.fetch("html")).to include("Explicitly visible descendant remains material.")
      expect(result.fetch("html")).not_to include("Hidden ancestor material", "Inherited hidden material", "Inactive material")
    end
  end

  it "retains eligible roots outside the body" do
    with_url_page("https://research.example/article", "<html><body><p>Short body.</p></body></html>") do |page|
      page.add_script_tag(content: fallback_scoring_source)
      page.evaluate(<<~JAVASCRIPT)
        (() => {
          const article = document.createElement('article');
          article.innerHTML = '<h1>Outside body observations</h1>' +
            '<p>Detailed reproducible observations and independently checked scientific measurements.</p>'.repeat(8);
          document.documentElement.appendChild(article);
        })()
      JAVASCRIPT
      result = page.evaluate("checkFallbackScoring()")
      expect(result.fetch("equal")).to be(true)
      expect(result.fetch("html")).to include("Outside body observations")
    end
  end

  it "rebuilds visibility and content after the source DOM changes" do
    html = "<html><body><main><h1>Observations</h1><p>#{"Original detailed measurements. " * 20}</p></main></body></html>"
    with_url_page("https://research.example/article", html) do |page|
      page.add_script_tag(content: fallback_scoring_source)
      expect(page.evaluate("checkFallbackScoring()").fetch("equal")).to be(true)
      page.evaluate("document.querySelector('p').textContent = 'Updated independently verified measurements. '.repeat(20)")
      result = page.evaluate("checkFallbackScoring()")
      expect(result.fetch("equal")).to be(true)
      expect(result.fetch("html")).to include("Updated independently verified measurements.")
      expect(result.fetch("html")).not_to include("Original detailed measurements.")
    end
  end
end
