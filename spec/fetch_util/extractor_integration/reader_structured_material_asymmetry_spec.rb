require "nokogiri"
require "uri"

RSpec.describe "Reader structured material under prose-score asymmetry" do
  include_context 'extractor integration helpers'

  def asymmetric_source
    paragraphs = Array.new(160) do |index|
      ordinal = format("%03d", index + 1)
      "ASYMMETRIC-PARAGRAPH-#{ordinal} records a distinct field observation at station #{ordinal}, " \
        "including measured conditions, instrument calibration, and the review interval. The field " \
        "team compared the result with the preceding survey, checked the record independently, and " \
        "documented its implication for the next longitudinal assessment. Each observation remains " \
        "separate in the source because its location, comparison, and conclusion differ from the others."
    end
    code_lines = Array.new(32) do |index|
      ordinal = format("%03d", index + 1)
      "const observation_#{ordinal} = Object.freeze({marker: \"ASYMMETRIC-CODE-#{ordinal}\", ordinal: #{index + 1}});"
    end
    rows = [["Ordinal", "Field A", "Field B"]] + Array.new(40) do |index|
      ordinal = format("%03d", index + 1)
      ["ASYMMETRIC-ROW-#{ordinal}", "ASYMMETRIC-A-#{ordinal}", "ASYMMETRIC-B-#{ordinal}"]
    end
    links = Array.new(25) do |index|
      ordinal = format("%03d", index + 1)
      ["ASYMMETRIC-LINK-#{ordinal}", "/evidence/#{ordinal}"]
    end
    reference_paragraphs = links.map do |label, _href|
      "Supporting documentation for this field observation is available at #{label}, " \
        "with the associated record retained for independent review."
    end
    html = <<~HTML
      <!doctype html><html><head><title>Asymmetric Field Study</title>
      <meta name="author" content="Field Research Office">
      <meta name="description" content="An asymmetric field study with separately grouped source material.">
      </head><body><main><article itemprop="articleBody">
      <div class="field-observations"><h1>Asymmetric Field Study</h1><h2>Field observations</h2>
      #{paragraphs.map { |paragraph| "<p>#{paragraph}</p>" }.join}
      </div>
      <div class="technical-appendix"><h2>Executable measurements</h2>
      <pre><code>#{code_lines.join("\n")}</code></pre></div>
      <div class="measurement-appendix"><h2>Cross-reference measurements</h2>
      <table><thead><tr>#{rows.first.map { |cell| "<th>#{cell}</th>" }.join}</tr></thead><tbody>
      #{rows.drop(1).map { |row| "<tr>#{row.map { |cell| "<td>#{cell}</td>" }.join}</tr>" }.join}
      </tbody></table></div>
      #{reference_paragraphs.zip(links).map { |paragraph, (label, href)| "<p>#{paragraph.sub(label, "<a href=\"#{href}\">#{label}</a>")}</p>" }.join}
      </article></main></body></html>
    HTML
    {
      html: html,
      paragraphs: paragraphs,
      reference_paragraphs: reference_paragraphs,
      code: code_lines.join("\n"),
      rows: rows,
      links: links
    }
  end

  def normalized_text(value)
    value.to_s.gsub(/\s+/, " ").strip
  end

  def ordered_table_rows(table)
    table.css("tr").map { |row| row.css("th, td").map { |cell| normalized_text(cell.text) } }
  end

  def expect_ordered_values(values, content)
    cursor = 0
    values.each do |value|
      position = content.index(value, cursor)
      expect(position).not_to be_nil, "missing or out-of-order content: #{value.inspect}"
      cursor = position + value.length
    end
  end

  it "recovers sibling code, table, and links after prose wins Reader scoring" do
    source = asymmetric_source
    page_url = "https://asymmetric.test/reviews/field-study"
    expected_links = source.fetch(:links).map do |label, href|
      [label, URI.join(page_url, href).to_s]
    end

    with_url_page(page_url, source.fetch(:html)) do |page|
      payload = extract_payload(page, reader_mode: true)
      html = Nokogiri::HTML.fragment(payload.fetch("html"))
      markdown = payload.fetch("markdown")
      expected_code = source.fetch(:code)
      expected_rows = source.fetch(:rows)

      expect(payload).to include("readerMode" => true, "contentType" => "article")
      expect(payload.fetch("title")).to eq("Asymmetric Field Study")
      expect(payload.fetch("byline")).to include("Field Research Office")
      expect(payload.fetch("excerpt")).to eq(source.fetch(:paragraphs).first)
      expected_paragraphs = source.fetch(:paragraphs) + source.fetch(:reference_paragraphs)
      expect(html.css("p").map { |paragraph| normalized_text(paragraph.text) }).to eq(expected_paragraphs)
      expect(html.css("pre").map(&:text)).to eq([expected_code])
      expect(ordered_table_rows(html.at_css("table"))).to eq(expected_rows)
      expect(html.css("a[href]").map { |link| [normalized_text(link.text), link["href"]] }).to eq(expected_links)

      markdown_code = markdown.scan(/^```[^\n]*\n(.*?)^```[ \t]*$/m).flatten.map { |block| block.sub(/\n\z/, "") }
      expect(markdown_code).to eq([expected_code])
      markdown_rows = markdown.lines.filter_map do |line|
        next unless line.match?(/^\|.*\|\s*$/)

        cells = line.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip)
        next if cells.all? { |cell| cell.match?(/\A:?-+:?\z/) }

        cells
      end
      expect(markdown_rows).to eq(expected_rows)
      expect(markdown.scan(/\[([^\]]+)\]\(([^)]+)\)/)).to eq(expected_links)

      ordered_material = source.fetch(:paragraphs) + expected_code.lines.map(&:chomp) +
                         expected_rows.flatten + source.fetch(:reference_paragraphs)
      expect_ordered_values(ordered_material, html.text.gsub(/\s+/, " ").strip)
      markdown_order = source.fetch(:paragraphs) + expected_code.lines.map(&:chomp) +
                       expected_rows.map { |row| "| #{row.join(" | ")} |" } +
                       source.fetch(:reference_paragraphs).map do |paragraph|
                         paragraph.sub(/ASYMMETRIC-LINK-\d{3}/) do |label|
                           href = expected_links.find { |expected_label, _| expected_label == label }.last
                           "[#{label}](#{href})"
                         end
                       end
      expect_ordered_values(markdown_order, markdown)
    end
  end
end
