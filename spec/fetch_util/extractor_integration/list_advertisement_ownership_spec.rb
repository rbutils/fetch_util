# frozen_string_literal: true

RSpec.describe "FetchUtil list advertisement ownership" do
  include_context "extractor integration helpers"

  def story_card(number, class_name: "story-card", id: nil)
    id_attribute = id ? " id=\"#{id}\"" : ""
    <<~HTML
      <article#{id_attribute} class="#{class_name}">
        <a href="/stories/#{number}"><h3>Independent newsroom story #{number}</h3></a>
      </article>
    HTML
  end

  it "excludes exact advertisement owners without matching ordinary substrings" do
    stories = (1..8).map { |number| story_card(number) }.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main class="ad">
        <h1>Independent newsroom</h1>
        #{stories}
        #{story_card(9, class_name: "adventure-card")}
        #{story_card(10, class_name: "advisory-card")}
        #{story_card(11, class_name: "address-card")}
        #{story_card(12, class_name: "sponsored-card")}
        #{story_card(13, class_name: "story-card ad")}
        #{story_card(14, class_name: "story-card ad-slot")}
        #{story_card(15, class_name: "story-card advert-unit")}
        #{story_card(16, id: "advertisement-wrapper")}
        <div class="ad-container">#{story_card(17)}</div>
      </main></body></html>
    HTML

    extract_from_url("https://newsroom.example/", html, reader_mode: false) do |payload|
      expect(payload["contentType"]).to eq("list")
      (1..12).each do |number|
        expect(payload["markdown"]).to include("https://newsroom.example/stories/#{number}")
      end
      (13..17).each do |number|
        expect(payload["markdown"]).not_to include("https://newsroom.example/stories/#{number}")
      end
    end
  end
end
