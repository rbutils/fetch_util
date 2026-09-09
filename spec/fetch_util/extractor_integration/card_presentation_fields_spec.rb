# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - card presentation fields" do
  include_context "extractor integration helpers"

  it "keeps every linkless layout field with its own record without merging independent records" do
    cards = (1..125).map do |i|
      "<article><h3><a class='card-link' href='/event/#{i}'>Conference event #{i}</a></h3>" \
        "<div class='card-text'><div class='card-event-data'><span>Session slot #{i}.</span></div>" \
        "<p>Venue number #{i}.</p></div></article>"
    end.join
    actions = (1..125).map do |i|
      "<article><h3>Action conference #{i}.</h3><div class='card-text'><div class='card-event-data'>" \
        "<span>Action slot #{i}.</span></div><p>Action venue #{i}.</p></div>" \
        "<a class='card-cta card-link' href='/action/#{i}'>View Event<img src='/arrow.svg' alt=''></a></article>"
    end.join
    html = "<main>#{cards}#{actions}</main><div id='separate'><article>Independent biography.</article>" \
           "<div class='product'>Independent product.</div><div class='card'><a href='/other'>Other story</a><p>Other summary.</p></div></div>"
    with_url_page("https://events.example/", html) do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n").sub("})(window);", "global.fieldProbe = {clone: visibleListClone, items: extractListItems, render: listMarkdown, boundary: genericListCardBoundary}; })(window);")
      page.add_script_tag(content: source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('main'), before = root.innerHTML;
          const items = fieldProbe.items(fieldProbe.clone(root));
          return {markdown: fieldProbe.render(items), unchanged: root.innerHTML === before,
            boundaries: Array.from(document.querySelector('#separate').children).map(fieldProbe.boundary)};
        })()
      JS
      lines = result.fetch("markdown").lines.map(&:strip).reject(&:empty?)
      expect(lines.first(125)).to eq((1..125).map do |i|
        "- [Conference event #{i}](https://events.example/event/#{i}) - Venue number #{i}. - Session slot #{i}."
      end)
      expect(lines.length).to eq(250)
      lines.drop(125).each_with_index do |line, index|
        number = index + 1
        expect(line).to include("https://events.example/action/#{number})")
        ["Action conference #{number}.", "Action slot #{number}.", "Action venue #{number}."].each do |field|
          expect(line.scan(field).length).to eq(1)
        end
      end
      expect(result.fetch("boundaries")).to eq([true, true, true])
      expect(result.fetch("unchanged")).to be(true)
    end
  end
end
