require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor, "mixed sibling anchor context" do
  include_context "extractor integration helpers"

  def mixed_anchor_page(rich_content)
    main_cards = (1..4).map do |number|
      "<article><h2><a href='/main/#{number}'>Main editorial story number #{number}</a></h2>" \
        "<p>Independent reporting and local context for main story #{number}.</p></article>"
    end.join
    peers = (2..8).map do |number|
      "<a href='/peer/#{number}'>Independent sibling headline number #{number}</a>"
    end.join
    "<main><h1>Community news</h1>#{main_cards}<section><h2>Regional headlines</h2>" \
      "<p>These stories cover the latest regional developments.</p><div class='links-box'>" \
      "<a href='/peer/1'>#{rich_content}</a>#{peers}<div class='empty-layout-spacer'></div></div></section></main>"
  end

  it "does not borrow neighboring headlines from a mixed image and plain-link collection" do
    html = mixed_anchor_page("<img src='/lead.jpg' alt=''><span>Independent sibling headline number 1</span>")
    with_url_page("https://bulletin.example/", html) do |page|
      payload = extract_payload(page)
      markdown = payload.fetch("markdown")

      (1..8).each do |number|
        line = markdown.lines.find { |entry| entry.include?("https://bulletin.example/peer/#{number})") }
        expect(line.to_s.strip).to eq("- [Independent sibling headline number #{number}](https://bulletin.example/peer/#{number})")
      end
      expect(markdown).to include("These stories cover the latest regional developments.")
    end
  end

  it "keeps the rich member's author and description out of its plain siblings" do
    rich = "<h3>Independent sibling headline number 1</h3><p>Reporting unique to the lead record.</p>" \
      "<span class='author'>Lead reporter</span><time datetime='2026-09-14'>September 14</time>"
    with_url_page("https://bulletin.example/", mixed_anchor_page(rich)) do |page|
      markdown = extract_payload(page).fetch("markdown")
      lead = markdown.lines.find { |line| line.include?("https://bulletin.example/peer/1)") }
      expect(lead).to include("Reporting unique to the lead record.", "Lead reporter", "2026-09-14")
      (2..8).each do |number|
        line = markdown.lines.find { |entry| entry.include?("https://bulletin.example/peer/#{number})") }
        expect(line.to_s.strip).to eq("- [Independent sibling headline number #{number}](https://bulletin.example/peer/#{number})")
      end
    end
  end
end
