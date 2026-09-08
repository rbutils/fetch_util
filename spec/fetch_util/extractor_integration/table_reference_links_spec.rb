require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor do
  include_context "extractor integration helpers"

  def table_reference_render(rows, headers = "<th>Record</th><th>Description</th><th>Status</th>", section_cards: false)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines("#{root}/websieve/manifest.txt").map(&:strip)
                 .reject { |path| path.empty? || path.start_with?("#") }
                 .map { |path| File.read("#{root}/websieve/#{path}") }.join("\n")
    source = source.sub("})(window);", "global.__tableReferenceClone = visibleListClone; " \
                                         "global.__tableReferenceItems = extractListItems; " \
                                         "global.__tableReferenceSections = sectionCards; " \
                                         "global.__tableReferenceMarkdown = listMarkdown; })(window);")
    html = "<html><body><main><h1>Records</h1><table><thead><tr>#{headers}</tr></thead><tbody>#{rows}</tbody></table></main></body></html>"
    with_url_page("https://research.example/records", html) do |page|
      page.add_script_tag(content: source)
      page.evaluate(<<~JS)
        (() => {
          const table = document.querySelector('table');
          const original = table.outerHTML;
          const items = #{section_cards ? '__tableReferenceSections' : '__tableReferenceItems'}(__tableReferenceClone(table));
          return {
            markdown: __tableReferenceMarkdown(items), details: items.map(item => item.detail),
            logicalCells: items.map(item => !!item.tableCells),
            unchanged: table.outerHTML === original
          };
        })()
      JS
    end
  end

  it "preserves all mixed-cell references without changing admission text or reference identifiers" do
    rows = 125.times.map do |index|
      "<tr><td><a href='/records/VAR_#{index}'>VAR_#{index}</a></td>" \
        "<td>Database reference: <a href='/references/VAR_#{index}?id=VAR_#{index}'>VAR_#{index}</a>.</td><td>confirmed</td></tr>"
    end.join
    result = table_reference_render(rows)
    expect(result["markdown"]).to eq(125.times.map do |index|
      "- [VAR_#{index}](https://research.example/records/VAR_#{index}) - " \
        "Description: Database reference: [VAR_#{index}](https://research.example/references/VAR_#{index}?id=VAR_#{index}). | Status: confirmed"
    end.join("\n"))
    expect(result["details"].join).not_to include("https://")
    expect(result["unchanged"]).to be(true)
  end

  it "keeps pure-link fields unchanged and excludes hidden and unsafe reference destinations" do
    rows = 6.times.map do |index|
      <<~HTML
        <tr><td><a href='/records/#{index}'>Record #{index}</a></td>
        <td>See <a href='/references/#{index}'>reference #{index}</a>,
        <a href='https://fixture-user:fixture-secret@example.net/secret'>credential label</a> and
        <a href='javascript:void(0)'>local action</a>.<a href='/empty'></a><span hidden><a href='https://hidden.example/ref'>hidden ref</a></span></td>
        <td><a href='/logs/#{index}'>view logs</a></td></tr>
      HTML
    end.join
    result = table_reference_render(rows, "<th>Record</th><th>Description</th><th>Action</th>")
    expect(result["markdown"]).to eq(6.times.map do |index|
      "- [Record #{index}](https://research.example/records/#{index}) - " \
        "Description: See [reference #{index}](https://research.example/references/#{index}), credential label and local action. | Action: view logs"
    end.join("\n"))
    expect(result["markdown"]).not_to include("fixture-secret", "javascript:", "hidden.example", "hidden ref", "research.example/empty")
  end

  it "retains logical spanning-cell references on each row that owns them" do
    rows = 6.times.map do |index|
      <<~HTML
        <tr><td><a href='/records/#{index}-a'>Record #{index}a</a></td>
        <td rowspan='2'>Shared evidence: <a href='/references/#{index}'>reference #{index}</a>.</td><td>confirmed</td></tr>
        <tr><td><a href='/records/#{index}-b'>Record #{index}b</a></td><td>confirmed</td></tr>
      HTML
    end.join
    result = table_reference_render(rows)
    expect(result["markdown"]).to eq(6.times.flat_map do |index|
      %w[a b].map do |suffix|
        "- [Record #{index}#{suffix}](https://research.example/records/#{index}-#{suffix}) - " \
          "Description: Shared evidence: [reference #{index}](https://research.example/references/#{index}). | Status: confirmed"
      end
    end.join("\n"))
  end

  it "preserves references in full row details produced by section cards" do
    rows = 6.times.map do |index|
      "<tr><td><h4><a href='/records/#{index}'>Detailed variant record #{index}</a></h4></td>" \
        "<td>Evidence: <a href='/references/#{index}'>reference #{index}</a>.</td><td>confirmed</td></tr>"
    end.join
    result = table_reference_render(rows, section_cards: true)
    expect(result["logicalCells"]).to eq([false] * 6)
    expect(result["markdown"]).to eq(6.times.map do |index|
      "- [Detailed variant record #{index}](https://research.example/records/#{index}) - " \
        "Description: Evidence: [reference #{index}](https://research.example/references/#{index}). | Status: confirmed"
    end.join("\n"))
    expect(result["details"].join).not_to include("https://")
    expect(result["unchanged"]).to be(true)
  end
end
