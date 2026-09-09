# frozen_string_literal: true

RSpec.describe "Wrapped record evidence" do
  include_context "extractor integration helpers"

  def with_wrapped_records(html)
    with_url_page("https://records.example/", "<main>#{html}</main>") do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject do |line|
        line.empty? || line.start_with?("#")
      end.map { |path| File.read(File.join(root, "websieve", path)) }.join("\n")
      source = source.sub("})(window);", <<~JS)
        global.wrappedRecords = function() {
          return extractListItems(visibleListClone(document.querySelector('main'))).map(function(item) {
            return {text: item.text, url: item.url, detail: item.detail, card: item.card.tagName};
          });
        };
        global.wrappedEvidence = function() {
          return Array.from(document.querySelectorAll('[data-probe]')).map(function(link) {
            return genericListDirectAnchorCard(link, link.parentElement);
          });
        };
        global.wrappedMarkdown = function() {
          return listMarkdown(extractListItems(visibleListClone(document.querySelector('main'))));
        };
        })(window);
      JS
      page.add_script_tag(content: source)
      yield page
    end
  end

  it "keeps all wrapped semantic headlines and media records local without class-name hints" do
    headlines = (1..125).map { |i| "<div><a href='/news/#{i}'><article>Independent news record #{i}.</article></a></div>" }.join
    products = (1..125).map do |i|
      "<div><a href='/products/#{i}'><img src='/images/#{i}.jpg' alt=''><span>Independent product #{i}.</span> #{i} EUR</a></div>"
    end.join
    with_wrapped_records("<div>#{headlines}</div><div>#{products}</div>") do |page|
      records = page.evaluate("wrappedRecords()")
      expect(records.map { |item| item.fetch("url") }).to eq(
        (1..125).map { |i| "https://records.example/news/#{i}" } +
        (1..125).map { |i| "https://records.example/products/#{i}" }
      )
      records.each_with_index do |item, index|
        expect(item.fetch("card")).to eq("A")
        expect(item.fetch("text")).to include("#{index % 125 + 1}.")
        expect(item.fetch("detail", "")).not_to match(/Independent (?:news|product)/)
      end
      markdown = page.evaluate("wrappedMarkdown()")
      (1..125).each do |index|
        expect(markdown.scan("Independent news record #{index}.").length).to eq(1)
        expect(markdown.scan("Independent product #{index}.").length).to eq(1)
      end
    end
  end

  it "does not infer independent wrappers from hidden, unsafe, empty or navigation peers" do
    valid = "<a data-probe href='/news/one'><article>Independent news record one.</article></a>"
    cases = [
      "<div>#{valid}</div><div><a hidden href='/hidden'><article>Hidden record.</article></a></div>",
      "<div>#{valid}</div><div><a href='https://fixture:secret@records.example/private'><article>Unsafe record.</article></a></div>",
      "<div>#{valid}</div><div><a href='/empty'>Ordinary action<article></article></a></div>",
      "<div>#{valid}</div><div><a href='/hidden-media'>Ordinary action<img hidden src='/image.jpg' alt='Hidden evidence'></a></div>"
    ].map { |group| "<section>#{group}</section>" }.join
    with_wrapped_records("#{cases}<nav><div>#{valid}</div><div><a href='/other'><article>Other record.</article></a></div></nav>") do |page|
      expect(page.evaluate("wrappedEvidence()")).to eq([false, false, false, false, false])
    end
  end
end
