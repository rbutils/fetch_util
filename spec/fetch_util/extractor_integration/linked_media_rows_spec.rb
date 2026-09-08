# frozen_string_literal: true

RSpec.describe "FetchUtil linked media row ownership" do
  include_context "extractor integration helpers"

  def row_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true)
                 .reject { |line| line.empty? || line.start_with?("#") }
                 .map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
    source.sub("})(window);", <<~JAVASCRIPT)
      global.rowBoundary = genericListCardBoundary;
      global.rowItems = function() {
        return extractListItems(cleanupListRoot(visibleListClone(document.body))).map(function(item) {
          return { title: item.text, owner: item.card.id, markdown: listMarkdown([item]),
            references: Array.from(item.card.querySelectorAll('p a[href]')).map(function(link) { return link.href; }) };
        });
      };
      })(window);
    JAVASCRIPT
  end

  def linked_row(index)
    "<div class='row' id='record-#{index}'><div class='col-3'><a href='/feature/#{index}'>" \
      "<img src='https://research.example/image-#{index}.png' alt=''></a></div>" \
      "<div class='col-9'><h4><a href='/feature/#{index}'>Independent feature headline #{index}</a></h4>" \
      "<p>Owned explanation for feature #{index}. <a href='https://papers.example/reference-#{index}.pdf'>PDF reference</a></p></div></div>"
  end

  it "keeps all paired image and headline rows local inside a shared card" do
    rows = (0...125).map { |index| linked_row(index) }.join
    html = "<html><body><main><div class='card card-navy'><div class='card-body'>#{rows}</div></div></main></body></html>"
    with_url_page("https://research.example/", html) do |page|
      page.add_script_tag(content: row_source)
      result = page.evaluate("rowItems()")
      expect(result.map { |item| item.fetch("title") }).to eq((0...125).map { |index| "Independent feature headline #{index}" })
      result.each_with_index do |item, index|
        expect(item.fetch("owner")).to eq("record-#{index}")
        expect(item.fetch("markdown")).to include("Owned explanation for feature #{index}.")
        expect(item.fetch("references")).to eq(["https://papers.example/reference-#{index}.pdf"])
        expect(item.fetch("markdown").scan("Owned explanation").length).to eq(1)
      end
    end
  end

  it "rejects multi-record grids, mismatched destinations, hidden rows and navigation" do
    with_url_page("https://research.example/", "<html><body><main id='root'></main></body></html>") do |page|
      page.add_script_tag(content: row_source)
      result = page.evaluate(<<~JAVASCRIPT)
        (() => {
          const root = document.querySelector('#root');
          const first = #{JSON.generate(linked_row(0))}, second = #{JSON.generate(linked_row(1))};
          const cases = [
            first + second,
            first.replaceAll("href='/feature/0'", "href='https://user:secret@research.example/feature/0'") + second,
            first.replace("href='/feature/0'", "href='/different'") + second,
            first.replace("src='https://research.example/image-0.png'", "src='javascript:alert(1)'") + second,
            first.replace("id='record-0'", "id='record-0' hidden") + second,
            '<nav>' + first + second + '</nav>',
            '<div class="row" id="grid"><div class="col-6">' + first + '</div><div class="col-6">' + second + '</div></div>'
          ];
          return cases.map((html, index) => {
            root.innerHTML = html;
            return rowBoundary(root.querySelector(index === 6 ? '#grid' : '#record-0'));
          });
        })()
      JAVASCRIPT
      expect(result).to eq([true, false, false, false, false, false, false])
    end
  end
end
