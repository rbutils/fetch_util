# frozen_string_literal: true

RSpec.describe "FetchUtil section proof scope" do
  include_context "extractor integration helpers"

  def section_proof_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.probeSections = function(mode, cold, options) {
        var count = 0;
        var documentScans = 0;
        var originalProof = genericListFigureCollection;
        var originalAncestor = genericListFigureCollectionAncestor;
        var originalQuery = document.querySelectorAll;
        document.querySelectorAll = function(selector) {
          if (selector === 'a[href]') documentScans += 1;
          return originalQuery.call(this, selector);
        };
        genericListFigureCollection = function(node) { count += 1; return originalProof(node); };
        if (cold) genericListFigureCollectionAncestor = function(node) { return originalAncestor(node); };
        try {
          var value = mode === 'headlines' ? listMarkdown(extractFallbackHeadlineItems(document.body)) :
            sectionedListExtraction(document.body, options);
          return {count: count, documentScans: documentScans, markdown: value && (value.markdown || value)};
        } finally {
          genericListFigureCollection = originalProof;
          genericListFigureCollectionAncestor = originalAncestor;
          document.querySelectorAll = originalQuery;
        }
      };
      })(window);
    JAVASCRIPT
  end

  it "shares positive and negative figure proofs without changing any of 125 records" do
    sections = (0...2).map do |section|
      records = (0...125).select { |index| index % 2 == section }.map do |index|
        "<article class='card'><h3><a href='/record/#{index}'>Independent scientific record #{index}</a></h3>" \
          "<p>Local research details and original observations for record #{index}.</p></article>"
      end.join
      "<section><h2>Research collection #{section}</h2>#{records}</section>"
    end.join
    with_url_page("https://research.example/", "<html><body>#{sections}</body></html>") do |page|
      page.add_script_tag(content: section_proof_source)
      %w[sections headlines].each do |mode|
        cold = page.evaluate("probeSections(#{mode.to_json}, true)")
        warm = page.evaluate("probeSections(#{mode.to_json}, false)")
        expect(warm.fetch("markdown")).to eq(cold.fetch("markdown"))
        expect(warm.fetch("markdown").scan("https://research.example/record/").length).to eq(125)
        expect(warm.fetch("count")).to be <= 127
        expect(cold.fetch("count")).to be >= 250
        expect(warm.fetch("documentScans")).to eq(1)
      end
    end
  end

  it "starts fresh proofs after a figure collection changes without mutating caller options" do
    sections = (0...2).map do |section|
      figures = (0...2).map do |index|
        "<figure><a href='/figure/#{section}/#{index}'><h3>Linked scientific figure #{section} #{index}</h3></a>" \
          "<figcaption>Own explanation of these scientific observations.</figcaption></figure>"
      end.join
      "<section><h2>Scientific figures #{section}</h2><div>#{figures}</div></section>"
    end.join
    with_url_page("https://research.example/", "<html><body>#{sections}</body></html>") do |page|
      page.add_script_tag(content: section_proof_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          var options = {};
          var before = probeSections('sections', false, options);
          var beforeCold = probeSections('sections', true, options);
          document.querySelector('figure').remove();
          var after = probeSections('sections', false, options);
          var afterCold = probeSections('sections', true, options);
          return {before: before.markdown === beforeCold.markdown, after: after.markdown === afterCold.markdown,
            changed: before.markdown !== after.markdown, options: Object.keys(options)};
        })()
      JAVASCRIPT
      expect(result).to eq("before" => true, "after" => true, "changed" => true, "options" => [])
    end
  end
end
