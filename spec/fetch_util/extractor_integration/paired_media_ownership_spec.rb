# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - paired media ownership" do
  include_context "extractor integration helpers"

  def probe_pairs(page)
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    probe = "global.pairedProbe = genericListPairedMediaCard; global.pairedItems = extractListItems; " \
            "global.pairedRender = listMarkdown; })(window);"
    source = source.sub("})(window);", probe)
    page.add_script_tag(content: source)
  end

  it "keeps separate image and name links with their own fields in every record" do
    cards = (1..125).map do |i|
      "<div class='local-pair'><div><a href='/vehicle/#{i}'><img src='https://images.example/#{i}.jpg' alt=''></a></div>" \
        "<div><a href='/vehicle/#{i}'>Independent spotlight vehicle #{i}</a><p>Price #{i} EUR; year 2025.</p></div></div>"
    end.join
    with_url_page("https://vehicles.example/", "<main><h1>Vehicles</h1>#{cards}</main>") do |page|
      probe_pairs(page)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('main'), original = root.innerHTML, items = pairedItems(root);
          return {cards: items.map(item => item.card.className), urls: items.map(item => item.url),
            markdown: pairedRender(items), unchanged: root.innerHTML === original};
        })()
      JS
      expect(result.fetch("urls")).to eq((1..125).map { |i| "https://vehicles.example/vehicle/#{i}" })
      expect(result.fetch("cards")).to eq(Array.new(125, "local-pair"))
      (1..125).each do |i|
        line = result.fetch("markdown").lines.find { |value| value.include?("https://vehicles.example/vehicle/#{i})") }
        expect(line).to include("Price #{i} EUR; year 2025.")
        expect(line.scan(/Independent spotlight vehicle \d+/)).to eq(["Independent spotlight vehicle #{i}"])
      end
      expect(result.fetch("unchanged")).to be(true)
    end
  end

  it "rejects mismatched, hidden, unsafe, navigation and whole-page pairs" do
    pair = "<div><a href='/item'><img src='https://images.example/a.jpg' alt=''></a></div>" \
           "<div><a class='name' href='/item'>Independent named item</a><p>Local description.</p></div>"
    html = "<main><div>#{pair.sub("href='/item'", "href='/other'")}</div>" \
           "<div>#{pair.sub("<img ", "<img hidden ")}</div>" \
           "<div>#{pair.gsub("href='/item'", "href='https://fixture:secret@vehicles.example/item'")}</div>" \
           "<nav>#{pair}</nav><div>#{pair}<p>Unrelated page-wide prose.</p></div><article>#{pair}</article></main>"
    with_url_page("https://vehicles.example/", html) do |page|
      probe_pairs(page)
      expect(page.evaluate("Array.from(document.querySelectorAll('a.name')).map(link => !!pairedProbe(link))")).to eq(Array.new(6, false))
    end
  end
end
