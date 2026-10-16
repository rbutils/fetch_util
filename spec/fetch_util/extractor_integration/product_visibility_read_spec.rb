require "support/extractor_integration_helpers"

RSpec.describe "FetchUtil product visibility read scope" do
  include_context "extractor integration helpers"

  def product_visibility_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.probeProductRead = function() {
        var checks = 0, original = computeElementOwnSubtreeHidden, previous = sourceVisibilityReadContext;
        computeElementOwnSubtreeHidden = function(node, style, known) {
          if (node.isConnected && node.ownerDocument === document && node.id === 'clipped') checks++;
          return original(node, style, known);
        };
        try {
          var before = document.body.outerHTML;
          var result = genericProductListContent({title: document.title});
          return {checks: checks, items: result && result.productListItems,
            unchanged: document.body.outerHTML === before, restored: sourceVisibilityReadContext === previous,
            links: Array.from(document.querySelectorAll('#clipped a[href]'), node => [node.textContent, node.href])};
        } finally {
          computeElementOwnSubtreeHidden = original;
        }
      };
      global.probeRepeatedRead = function(scoped) {
        var checks = 0, original = computeElementOwnSubtreeHidden, previous = sourceVisibilityReadContext;
        computeElementOwnSubtreeHidden = function(node, style, known) {
          if (node.isConnected && node.ownerDocument === document && node.id === 'clipped') checks++;
          return original(node, style, known);
        };
        try {
          var before = document.body.outerHTML, content = {contentType: 'list'};
          var result = scoped ? repeatedRecordAssessmentForContent(content, null) : repeatedRecordCollectionPage(null, content);
          return {checks: checks, records: result && result.records.map(record => [record.title, record.destination]),
            unchanged: document.body.outerHTML === before, restored: sourceVisibilityReadContext === previous};
        } finally {
          computeElementOwnSubtreeHidden = original;
        }
      };
      global.probeSourceFacts = function(kind, scoped) {
        var checks = 0, original = computeElementOwnSubtreeHidden, previous = sourceVisibilityReadContext;
        computeElementOwnSubtreeHidden = function(node, style, known) {
          if (node.isConnected && node.ownerDocument === document && node.id === 'clipped') checks++;
          return original(node, style, known);
        };
        try {
          var before = document.body.outerHTML, result;
          if (kind === 'metadata') {
            var metadata = scoped ? collectMetadata() : computeMetadata();
            result = {title: metadata.title, byline: metadata.byline, publishedTime: metadata.publishedTime, language: metadata.language};
          } else if (kind === 'social') {
            result = scoped ? socialSourceFeedEvidence() : computeSocialSourceFeedEvidence();
          } else if (kind === 'history') {
            result = scoped ? sourceOwnedSearchHistoryContent({}, null) : computeSourceOwnedSearchHistoryContent({}, null);
          } else {
            throw new Error('Unknown source-facts probe');
          }
          return {checks: checks, value: result, unchanged: document.body.outerHTML === before,
            restored: sourceVisibilityReadContext === previous};
        } finally {
          computeElementOwnSubtreeHidden = original;
        }
      };
      })(window);
    JAVASCRIPT
  end

  it "checks a shared collapsed clipping boundary once for603unrelated resource links" do
    links = 603.times.map { |index| "<p><a href='/references/#{index}'>Complete source reference #{index}</a></p>" }.join
    html = "<title>Complete public resource index</title><main id='clipped' style='height:0;overflow:hidden'>#{links}</main>"
    with_url_page("https://catalogue.example/references", html) do |page|
      page.add_script_tag(content: product_visibility_source)
      result = page.evaluate("probeProductRead()")
      expect(result.values_at("checks", "items", "unchanged", "restored")).to eq([1, nil, true, true])
      expect(result.fetch("links")).to eq(603.times.map do |index|
        ["Complete source reference #{index}", "https://catalogue.example/references/#{index}"]
      end)
    end
  end

  it "preserves escaping products and recomputes clipping after each source mutation" do
    records = 6.times.map do |index|
      "<article class='product'><h2><a href='/product/#{index}'>Complete instrument model #{index}</a></h2>" \
        "<span class='price'>$#{index + 1}.00</span></article>"
    end.join
    html = "<title>Instrument catalogue</title><main id='clipped' style='height:0;overflow:hidden'>" \
      "<span id='escape' style='position:absolute'>Out-of-flow authored notice</span>#{records}</main>"
    with_url_page("https://catalogue.example/catalogue", html) do |page|
      page.add_script_tag(content: product_visibility_source)
      initial = page.evaluate("probeProductRead()")
      expect(initial.values_at("checks", "unchanged", "restored")).to eq([1, true, true])
      expect(initial.fetch("items").map { |item| item.fetch("text") }).to eq(6.times.map { |index| "Complete instrument model #{index}" })
      expect(initial.fetch("items").map { |item| item.fetch("url") }).to eq(6.times.map { |index| "https://catalogue.example/product/#{index}" })
      initial.fetch("items").each_with_index { |item, index| expect(item.fetch("detail")).to include("$#{index + 1}.00") }
      page.evaluate("document.getElementById('escape').remove()")
      expect(page.evaluate("probeProductRead()").values_at("checks", "items", "unchanged", "restored")).to eq([1, nil, true, true])
      page.evaluate("document.getElementById('clipped').style.height = 'auto'")
      expect(page.evaluate("probeProductRead()").fetch("items").length).to eq(6)
    end
  end

  it "preserves all125repeated records while sharing clipping facts only within that assessment" do
    records = 125.times.map do |index|
      escape = index.zero? ? "<span style='position:absolute'>Published out-of-flow notice</span>" : ""
      "<li><h2><a href='/records/#{index}'>Complete independent record #{index}</a></h2>#{escape}</li>"
    end.join
    html = "<title>Complete record directory</title><main><h1>Complete record directory</h1>" \
      "<ul id='clipped' style='height:0;overflow:hidden'>#{records}</ul></main>"
    with_url_page("https://catalogue.example/records", html) do |page|
      page.add_script_tag(content: product_visibility_source)
      reference = page.evaluate("probeRepeatedRead(false)")
      scoped = page.evaluate("probeRepeatedRead(true)")
      expect(reference.fetch("records")).to eq(125.times.map do |index|
        ["Complete independent record #{index}", "https://catalogue.example/records/#{index}"]
      end)
      expect(reference.fetch("checks")).to be > 125
      expect(scoped.values_at("checks", "records", "unchanged", "restored")).to eq([1, reference.fetch("records"), true, true])
    end
  end

  it "shares physical visibility only within each metadata, social and history read" do
    records = 125.times.map do |index|
      "<article><h2><a href='/references/#{index}'>Complete reference material #{index}</a></h2></article>"
    end.join
    html = "<html lang='en'><head><title>Public reference catalogue</title></head><body><main id='clipped' style='height:0;overflow:hidden'>" \
      "<span style='position:absolute'>An authored out-of-flow notice</span><h1>Public reference catalogue</h1>#{records}</main></body></html>"
    with_url_page("https://catalogue.example/references", html) do |page|
      page.add_script_tag(content: product_visibility_source)
      values = { "metadata" => { "title" => "Public reference catalogue", "byline" => nil, "publishedTime" => nil, "language" => "en" },
                 "social" => false, "history" => nil }
      values.each do |kind, expected|
        reference = page.evaluate("probeSourceFacts(#{kind.to_json}, false)")
        scoped = page.evaluate("probeSourceFacts(#{kind.to_json}, true)")
        expect(reference.fetch("value")).to eq(expected)
        expect(reference.fetch("checks")).to be > 1
        expect(scoped.values_at("checks", "value", "unchanged", "restored")).to eq([1, expected, true, true])
      end
    end
  end
end
