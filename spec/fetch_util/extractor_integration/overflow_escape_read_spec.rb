require "support/extractor_integration_helpers"

RSpec.describe "FetchUtil overflow escape read scope" do
  include_context "extractor integration helpers"

  def overflow_escape_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.probeEscapeRead = function(scoped) {
        var original = window.getComputedStyle, reads = 0, previous = sourceVisibilityReadContext;
        window.getComputedStyle = function(node) {
          if (node.id === 'leaf') reads++;
          return original.apply(this, arguments);
        };
        var before = document.body.outerHTML;
        function inspect() {
          return Array.from(document.querySelectorAll('.boundary'), function(node) {
            return overflowEscapingDescendant(node);
          });
        }
        try {
          var values = scoped ? withSourceVisibilityRead(inspect) : inspect();
          return {values: values, reads: reads, unchanged: document.body.outerHTML === before,
            restored: sourceVisibilityReadContext === previous};
        } finally {
          window.getComputedStyle = original;
        }
      };
      })(window);
    JAVASCRIPT
  end

  it "reuses all shared physical descendant results while preserving the default reference values" do
    html = "<main>#{"<div class='boundary'>" * 125}<span id='leaf'>Complete authored leaf</span>#{"</div>" * 125}</main>"
    with_url_page("https://publication.example/reference", html) do |page|
      page.add_script_tag(content: overflow_escape_source)
      reference = page.evaluate("probeEscapeRead(false)")
      scoped = page.evaluate("probeEscapeRead(true)")
      expect(reference.values_at("values", "reads", "unchanged", "restored")).to eq([Array.new(125, false), 125, true, true])
      expect(scoped.values_at("values", "reads", "unchanged", "restored")).to eq([reference.fetch("values"), 1, true, true])
    end
  end

  it "observes absolute, fixed and ordinary flow again in each new read" do
    html = "<main><section class='boundary'><div class='boundary'><span id='leaf'>Published escape evidence</span></div></section></main>"
    with_url_page("https://publication.example/reference", html) do |page|
      page.add_script_tag(content: overflow_escape_source)
      expect(page.evaluate("probeEscapeRead(true).values")).to eq([false, false])
      %w[absolute fixed static].each do |position|
        page.evaluate("document.getElementById('leaf').style.position = #{position.to_json}")
        reference = page.evaluate("probeEscapeRead(false)")
        scoped = page.evaluate("probeEscapeRead(true)")
        expect(scoped.values_at("values", "unchanged", "restored")).to eq([reference.fetch("values"), true, true])
        expect(scoped.fetch("values")).to eq(Array.new(2, position != "static"))
      end
    end
  end
end
