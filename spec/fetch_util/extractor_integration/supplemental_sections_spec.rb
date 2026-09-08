require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def supplemental_sections_html(count: 5, shared: false, prose: false)
    sections = 2.times.map do |region|
      cards = 4.times.map do |index|
        <<~HTML
          <article><a href="/section/#{region}/#{index}"><h3>Regional bulletin #{region}-#{index}</h3></a>
          <p>Independent summary for regional bulletin #{region}-#{index}.</p><time>2026-09-01</time></article>
        HTML
      end.join
      cards += '<article><a href="/cinema"><h3>Cinema</h3></a></article>' if region.zero?
      "<section><h2>Region #{region}</h2>#{cards}</section>"
    end.join
    other = count.times.map do |index|
      link = "<a href=\"/other/#{index}\">Additional independent headline #{index}</a>"
      shared ? link : "<div class=\"item\">#{link}<time>2026-09-02</time></div>"
    end.join
    inline = if prose
               <<~HTML
                 <div class="prose-collection"><h2>Streaming guide</h2>
                 <p>Shared introduction that must appear only once.</p>
                 <p><a href="/inline/one">First inline programme</a>: The first programme has a local description.</p>
                 <p><a href="/inline/two">Second inline programme</a>: The second programme has its own description.</p>
                 <p>Unlinked closing terms remain available in their original position.</p></div>
               HTML
             end
    <<~HTML
      <html><head><title>Regional reporting index</title></head><body><main>
      <p>Opening context before all of the independent records.</p>
      #{sections}<div>#{other}</div>#{inline}
      <p>Closing context after all of the independent records.</p>
      </main></body></html>
    HTML
  end

  def supplemental_sections_result(html)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    outro = File.read("#{root}/websieve/99_outro.js")
    hook = <<~JS
      global.__supplementalSections = function() {
        var root = visibleListClone(document.querySelector('main'));
        cleanupListRoot(root);
        var sectioned = sectionedListExtraction(root);
        var result = supplementalSameRootSectionCoverage(sectioned, extractListItems(root),
          extractFallbackHeadlineItems(root), root, [document.title]);
        return JSON.stringify(result && {markdown:result.markdown, urls:result.items.map(function(item) {return item.url;})});
      };
    JS
    raise "Missing extractor closure" unless source.end_with?(outro)

    with_url_page("https://publisher.example/", html) do |page|
      page.add_script_tag(content: source.delete_suffix(outro) + hook + outro)
      JSON.parse(page.evaluate("window.__supplementalSections()"))
    end
  end

  it "preserves partial sections, missing records and surrounding prose in DOM order" do
    result = supplemental_sections_result(supplemental_sections_html)
    expect(result.fetch("urls").length).to eq(14)
    expect(result.fetch("urls")).to include("https://publisher.example/cinema")
    markdown = result.fetch("markdown")
    expect(markdown.index("Opening context")).to be < markdown.index("Regional bulletin 0-0")
    expect(markdown.index("Additional independent headline 4")).to be < markdown.index("Closing context")
    expect(markdown).to include("Independent summary for regional bulletin 0-0.", "Region 1", "2026-09-02")
  end

  it "retains even one independently owned missing record" do
    result = supplemental_sections_result(supplemental_sections_html(count: 1))
    expect(result.fetch("urls")).to include("https://publisher.example/other/0")
  end

  it "does not substitute a dominant shared owner for independently owned records" do
    html = supplemental_sections_html(shared: true).sub(
      '<div><a href="/other/0">',
      '<div><p>Shared collection prose is not an individual record description.</p><a href="/other/0">'
    )
    expect(supplemental_sections_result(html)).to be_nil
  end

  it "retains qualified plain-link groups without inventing descriptions from sibling labels" do
    result = supplemental_sections_result(supplemental_sections_html(shared: true))
    lines = result.fetch("markdown").lines.map(&:strip)
    5.times do |index|
      expect(lines).to include("- [Additional independent headline #{index}](https://publisher.example/other/#{index})")
    end
    expect(result.fetch("urls").select { |url| url.include?("/other/") }).to eq(
      5.times.map { |index| "https://publisher.example/other/#{index}" }
    )
  end

  it "keeps inline descriptions local and unrepresented prose once" do
    result = supplemental_sections_result(supplemental_sections_html(prose: true))
    markdown = result.fetch("markdown")
    expect(markdown.scan("Shared introduction").length).to eq(1)
    expect(markdown.scan("The first programme has a local description.").length).to eq(1)
    expect(markdown.scan("The second programme has its own description.").length).to eq(1)
    first_line = markdown.lines.find { |line| line.include?("https://publisher.example/inline/one") }
    expect(first_line).not_to include("Shared introduction", "second programme")
    expect(markdown).to include("Unlinked closing terms remain available")
  end

  it "retains all 125 additional records in DOM order" do
    result = supplemental_sections_result(supplemental_sections_html(count: 125))
    urls = result.fetch("urls").select { |url| url.include?("/other/") }
    expect(urls).to eq(125.times.map { |index| "https://publisher.example/other/#{index}" })
  end
end
