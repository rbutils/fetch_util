require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def read_supporting_card_scope(tag: "div", mutate: false)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source = source.sub("})(window);", <<~JS)
      global.__readSupporting = genericListSupportingCard;
      var originalBoundary = genericListCardBoundary;
      global.__ownerBoundaryReads = 0;
      genericListCardBoundary = function(node) {
        if (node.id === 'source-owner') global.__ownerBoundaryReads++;
        return originalBoundary(node);
      };
      })(window);
    JS
    references = 603.times.map { |index| "<li><a data-reference href='/references/#{index}'>Source reference #{index}</a></li>" }.join
    html = <<~HTML
      <#{tag} id="source-owner" class="#{tag == "div" ? "post" : "region"}">
        <h2><a href="/primary">Complete primary publication and its source material</a></h2>
        <p>Visible supporting context remains in this physical record.</p><ul>#{references}</ul>
      </#{tag}>
    HTML
    with_url_page("https://records.example/article", html) do |page|
      page.add_script_tag(content: source)
      page.evaluate(<<~JS)
        (() => {
          const owner = document.getElementById('source-owner'), before = owner.outerHTML;
          const links = Array.from(owner.querySelectorAll('a[data-reference]')), cache = new WeakMap();
          const accepted = links.filter(link => __readSupporting(link, owner, cache) === owner).length;
          const reads = __ownerBoundaryReads, unchanged = owner.outerHTML === before;
          let fresh = null, uncached = null;
          if (#{mutate}) {
            owner.querySelector('h2').remove();
            fresh = __readSupporting(links[0], owner, new WeakMap()) === null;
            uncached = __readSupporting(links[0], owner) === null;
          }
          return {accepted, reads, unchanged, fresh, uncached,
            references: links.map(link => [link.textContent, link.href])};
        })()
      JS
    end
  end

  it "reads a shared positive boundary once per scope while retaining all603supporting destinations" do
    result = read_supporting_card_scope
    expect(result.fetch("accepted")).to eq(603)
    expect(result.fetch("reads")).to eq(2)
    expect(result.fetch("unchanged")).to be(true)
    expect(result.fetch("references")).to eq(603.times.map do |index|
      ["Source reference #{index}", "https://records.example/references/#{index}"]
    end)
  end

  it "reuses a disproved boundary without discarding its detached structured owner" do
    result = read_supporting_card_scope(tag: "section")
    expect(result.fetch("accepted")).to eq(603)
    expect(result.fetch("reads")).to eq(1)
    expect(result.fetch("unchanged")).to be(true)
    expect(result.fetch("references").length).to eq(603)
  end

  it "keeps fresh scopes and default calls sensitive to a changed source owner" do
    result = read_supporting_card_scope(mutate: true)
    expect(result.fetch("accepted")).to eq(603)
    expect(result.fetch("unchanged")).to be(true)
    expect(result.values_at("fresh", "uncached")).to eq([true, true])
  end
end
