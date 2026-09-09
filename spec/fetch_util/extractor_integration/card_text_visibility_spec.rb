# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - card text visibility" do
  include_context "extractor integration helpers"

  it "keeps all visible card prose without borrowing hidden slide or panel text" do
    paragraphs = (1..125).map { |i| "<p>Visible statement #{i}.</p>" }.join
    html = "<article>#{paragraphs}<div hidden><p>Hidden panel.</p></div>" \
           "<div class='slick-slide' aria-hidden='true'><p>Cloned slide.</p></div>" \
           "<p aria-hidden='true'>Visually present.</p><p style='opacity:0'>Transparent quote.</p></article>"
    with_url_page("https://cards.example/article", html) do |page|
      root = File.expand_path("../../..", __dir__)
      source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
        File.read(File.join(root, "websieve", entry))
      end.join("\n").sub("})(window);", "global.cardTextProbe = genericListCardText; global.cardRenderProbe = listMarkdown; })(window);")
      page.add_script_tag(content: source)
      values = page.evaluate(<<~JS)
        (() => {
          const card = document.querySelector('article'), original = card.innerHTML;
          const initial = cardTextProbe(card), unchanged = card.innerHTML === original;
          const rendered = cardRenderProbe([{text: 'Visible item', url: 'https://cards.example/item', card, summary: 'Visible statement 1.'}]);
          card.querySelector('[hidden]').removeAttribute('hidden');
          const revealed = cardTextProbe(card);
          card.hidden = true;
          return {initial, revealed, hidden: cardTextProbe(card), unchanged, rendered};
        })()
      JS
      expected = "#{(1..125).map { |i| "Visible statement #{i}." }.join}Visually present."
      expect(values.fetch("initial")).to eq(expected)
      expect(values.fetch("revealed")).to eq(expected.sub("Visually present.", "Hidden panel.Visually present."))
      expect(values.fetch("hidden")).to eq("")
      expect(values.fetch("unchanged")).to be(true)
      expect(values.fetch("rendered")).not_to match(/Hidden panel|Cloned slide|Transparent quote/)
      (1..125).each { |i| expect(values.fetch("rendered").scan("Visible statement #{i}.").length).to eq(1) }
    end
  end
end
