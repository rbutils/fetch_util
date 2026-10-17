# frozen_string_literal: true

require "spec_helper"
require "support/extractor_integration_helpers"

RSpec.describe "Independent physical metadata references" do
  include_context "extractor integration helpers"

  def publication_cards(shared:, independent:)
    cards = (1..6).map do |number|
      category = shared ? "shared" : number.to_s
      label = shared ? "Shared classification" : "Literary category #{number}"
      <<~HTML
        <article class="each-story">
          <a href="/reports/#{number}"><img src="https://images.example.test/story-#{number}.png" alt=""></a>
          <div class="text">
            <h1><a href="/reports/#{number}">Independent publication report number #{number}</a></h1>
            <div class="who-when"><span class="byline">By <a href="/authors/#{number}">Documented author #{number}</a></span></div>
            <div class="dek">Complete authored evidence for report #{number} includes all of its original words and final conclusions.</div>
            <div class="taxonomies"><span class="formats"><a href="/genres/#{category}" rel="tag">#{label}</a></span></div>
          </div>
        </article>
      HTML
    end.join
    prose = if independent
              '<p>Our independent bibliography also uses <a href="/genres/shared" rel="tag">Shared classification</a> for its separately authored research.</p>'
            else
              ""
            end
    <<~HTML
      <html><head><title>Publication reports</title></head><body><main>
        <h1>Publication reports</h1><div class="stories-latest">#{cards}</div>#{prose}
      </main></body></html>
    HTML
  end

  def publication_markdown(shared:, independent:)
    with_url_page("https://publication.example.test/", publication_cards(shared: shared, independent: independent)) do |page|
      before = page.evaluate("document.body.innerHTML")
      markdown = extract(page).fetch("markdown")
      expect(page.evaluate("document.body.innerHTML")).to eq(before)
      (1..6).each do |number|
        expect(markdown).to include("Independent publication report number #{number}", "Documented author #{number}")
        expect(markdown).to include("Complete authored evidence for report #{number} includes all of its original words and final conclusions.")
      end
      yield markdown
    end
  end

  it "keeps each card's shared reference and its independent authored prose occurrence" do
    publication_markdown(shared: true, independent: true) do |markdown|
      expect(markdown.scan("[Shared classification](https://publication.example.test/genres/shared)").size).to eq(7)
      expect(markdown).to include("Our independent bibliography also uses", "for its separately authored research.")
    end
  end

  it "keeps the six independently owned shared references without a separate prose record" do
    publication_markdown(shared: true, independent: false) do |markdown|
      expect(markdown.scan("[Shared classification](https://publication.example.test/genres/shared)").size).to eq(6)
    end
  end

  it "keeps independently owned distinct category references once each" do
    publication_markdown(shared: false, independent: false) do |markdown|
      (1..6).each do |number|
        expect(markdown.scan("[Literary category #{number}](https://publication.example.test/genres/#{number})").size).to eq(1)
      end
    end
  end
end
