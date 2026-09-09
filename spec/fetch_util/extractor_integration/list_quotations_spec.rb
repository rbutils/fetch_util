# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - list quotations" do
  include_context "extractor integration helpers"

  it "preserves all visible quotation paragraphs and safe references once in order" do
    quotes = (1..125).map { |i| "<blockquote><p>Quote #{i}.</p><p>From <a href='/source/#{i}'>source #{i}</a>.</p></blockquote>" }.join
    long_quote = "Long quotation. " * 150
    html = "<main>#{quotes}<blockquote>#{long_quote}</blockquote>" \
           "<blockquote hidden>Hidden quote.</blockquote><div class='swiper-slide' aria-hidden='true'><blockquote>Inactive quote.</blockquote></div>" \
           "<blockquote><p>Safe prose <a href='https://fixture:secret@example.org'>unsafe label</a>.</p>" \
           "<p style='display:none'>Hidden child.</p></blockquote></main>"
    with_url_page("https://quotes.example/", html) do |page|
      root = File.expand_path("../../..", __dir__)
      page.add_script_tag(content: File.read(File.join(root, "lib/fetch_util/assets/vendor/turndown.js")))
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n").sub("})(window);", "global.quoteProbe = listDescriptionParts; })(window);")
      page.add_script_tag(content: source)
      result = page.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('main'), before = root.innerHTML;
          const parts = quoteProbe(root, [], {preserveUnrepresentedText: true});
          return {parts: parts.map(part => part.markdown), unchanged: root.innerHTML === before};
        })()
      JS
      parts = result.fetch("parts")
      expect(parts.first(125)).to eq((1..125).map { |i| "> Quote #{i}.\n> \n> From [source #{i}](https://quotes.example/source/#{i})." })
      expect(parts.length).to eq(127)
      expect(parts[125]).to eq("> #{long_quote.strip}")
      expect(parts[126]).to eq("> Safe prose unsafe label.")
      expect(parts.join).not_to match(/Hidden quote|Inactive quote|Hidden child|fixture:secret/)
      expect(result.fetch("unchanged")).to be(true)
    end
  end
end
