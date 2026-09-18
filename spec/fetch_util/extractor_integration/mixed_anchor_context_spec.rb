require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe FetchUtil::Extractor, "mixed sibling anchor context" do
  include_context "extractor integration helpers"

  def mixed_anchor_page(rich_content, second_content = nil)
    main_cards = (1..4).map do |number|
      "<article><h2><a href='/main/#{number}'>Main editorial story number #{number}</a></h2>" \
        "<p>Independent reporting and local context for main story #{number}.</p></article>"
    end.join
    peers = (2..8).map do |number|
      content = number == 2 && second_content ? second_content : "Independent sibling headline number #{number}"
      "<a href='/peer/#{number}'>#{content}</a>"
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
    second = "<h3>Independent sibling headline number 2</h3><p>Context unique to the peer record.</p>" \
      "<span class='author'>Peer reporter</span><time datetime='2026-09-13'>September 13</time>"
    with_url_page("https://bulletin.example/", mixed_anchor_page(rich, second)) do |page|
      before = page.evaluate("document.body.innerHTML")
      payload = extract_payload(page)
      markdown = payload.fetch("markdown")
      lead = markdown.lines.find { |line| line.include?("https://bulletin.example/peer/1)") }
      peer = markdown.lines.find { |line| line.include?("https://bulletin.example/peer/2)") }
      expect(lead).to include("Reporting unique to the lead record.", "Lead reporter", "2026-09-14")
      expect(lead).not_to include("Context unique to the peer record.", "Peer reporter", "2026-09-13")
      expect(peer).to include("Context unique to the peer record.", "Peer reporter", "2026-09-13")
      expect(peer).not_to include("Reporting unique to the lead record.", "Lead reporter", "2026-09-14")
      ["Reporting unique to the lead record.", "Lead reporter", "2026-09-14",
       "Context unique to the peer record.", "Peer reporter", "2026-09-13"].each do |value|
        expect(markdown.scan(value).length).to eq(1)
      end
      (3..8).each do |number|
        line = markdown.lines.find { |entry| entry.include?("https://bulletin.example/peer/#{number})") }
        expect(line.to_s.strip).to eq("- [Independent sibling headline number #{number}](https://bulletin.example/peer/#{number})")
      end
      expect(JSON.generate(payload)).not_to match(/"(?:card|sourceNode|listSourceItems|listSourceNode)"\s*:/)
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
    end
  end
end
