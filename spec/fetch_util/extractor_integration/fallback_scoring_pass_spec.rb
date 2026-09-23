# frozen_string_literal: true

RSpec.describe "FetchUtil fallback scoring pass" do
  include_context "extractor integration helpers"

  def fallback_scoring_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.checkArticleMaterialLoss = listCandidateLosesArticleMaterial;
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
      expect(result).to include("equal" => true, "calls" => 1)
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

  it "retains source-owned content components while removing actual short widgets" do
    sections = (1..12).map do |index|
      <<~HTML
        <section class="elementor-widget elementor-widget-text-editor">
          <div class="elementor-widget-container">
            <h2>Hosting feature #{index}</h2>
            <p>Source-owned feature details #{index} remain visible here.</p>
            <a href="/features/#{index}">Feature details #{index}</a>
          </div>
        </section>
      HTML
    end.join
    html = <<~HTML
      <html><body><main><h1>Hosting features</h1>
        <p>Hosting plans include visible product information and detailed support terms for every customer.</p>
        #{sections}
        <figure><figcaption class="widget-image-caption">Visible photograph credit</figcaption></figure>
        <aside class="widget">Account menu</aside>
        <div class="widget-quicklinks"><a href="/sign-in">Sign in</a></div>
        <div class="comment-thread">Unrelated short comment widget</div>
      </main></body></html>
    HTML

    with_url_page("https://hosting.example/plans", html) do |page|
      page.add_script_tag(content: fallback_scoring_source)
      result = page.evaluate("checkFallbackScoring()")
      expect(result.fetch("equal")).to be(true)
      (1..12).each do |index|
        expect(result.fetch("html")).to include("Hosting feature #{index}", "Source-owned feature details #{index}", "/features/#{index}")
      end
      expect(result.fetch("html")).to include("Visible photograph credit")
      expect(result.fetch("html")).not_to include("Account menu", "Sign in", "Unrelated short comment widget")
    end
  end

  it "rejects inferred lists missing a quarter of short sections from a complete fallback" do
    sections = (1..12).map do |index|
      <<~HTML
        <section><h2>Substantive section #{index}</h2>
          <p>Section #{index} explains implementation, maintenance, security and customer support with independently
          verifiable details for each aspect of the service, without relying on a linked catalog.</p></section>
      HTML
    end.join

    with_url_page("https://hosting.example/plans", "<main><h1>Service plans</h1>#{sections}</main>") do |page|
      page.add_script_tag(content: fallback_scoring_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = document.querySelector('main');
          const paragraphs = Array.from(root.querySelectorAll('p')).map(node => node.textContent);
          const article = {contentType: 'article', readerMode: false, html: root.innerHTML, textContent: root.textContent};
          const list = {contentType: 'list', markdown: paragraphs.slice(0, 8).join(String.fromCharCode(10))};
          return {
            missing: checkArticleMaterialLoss(article, list),
            reader: checkArticleMaterialLoss({...article, readerMode: true}, list),
            complete: checkArticleMaterialLoss(article,
              {contentType: 'list', markdown: paragraphs.join(String.fromCharCode(10))})
          };
        })()
      JAVASCRIPT
      expect(result).to eq("missing" => true, "reader" => false, "complete" => false)
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
