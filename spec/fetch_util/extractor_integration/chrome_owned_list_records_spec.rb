# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - chrome-owned list records" do
  include_context "extractor integration helpers"

  it "preserves structured records nested under a chrome-named wrapper" do
    records = [
      ["Alpha One", "7 fantasy pages"],
      ["Beta Tale", "12 mystery pages"],
      ["Gamma Arc", "5 adventure pages"],
      ["Delta Run", "18 comedy pages"],
      ["Epsilon Story", "9 drama pages"],
      ["Zeta Finale", "22 science fiction pages"]
    ]
    record_html = records.map.with_index do |(title, detail), index|
      <<~HTML
        <li class="item">
          <div class="record-inner">
            <a href="/works/#{index + 1}">
              <img src="/covers/#{index + 1}.jpg" alt="Cover of #{title}">
              <span class="number-of-pages">#{detail}</span>
              <h2 class="record-name">#{title}</h2>
            </a>
          </div>
        </li>
      HTML
    end.join
    navigation = 6.times.map do |index|
      %(<li><a href="/navigation/#{index + 1}">Long navigation destination #{index + 1}</a></li>)
    end.join
    short_unowned_records = ["Brief One", "Short Two", "Minor Three", "Tiny Four"].map.with_index do |title, index|
      <<~HTML
        <article class="related-item">
          <h3><a href="/related/#{index + 1}">#{title}</a></h3>
          <p>This separate collection has enough local evidence to resemble a record.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Independent works gallery</title></head><body>
        <main>
          <h1>Independent works gallery</h1>
          <div class="header-bottom">
            <div class="sort-controls">Sort by newest</div>
            <ul class="site-links">#{navigation}</ul>
            <div class="works-listing">
              <div class="works-grid">
                #{record_html}
                <div class="related-grid">#{short_unowned_records}</div>
              </div>
            </div>
          </div>
        </main>
      </body></html>
    HTML

    with_url_page("https://gallery.example/archive", html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      lines = payload.fetch("markdown").lines.grep(/^- \[/)

      expect(payload["contentType"]).to eq("list")
      expect(lines.map { |line| line[%r{/works/(\d+)}, 1].to_i }).to eq((1..6).to_a)
      records.each_with_index do |(title, detail), index|
        expect(lines[index]).to include(title, detail)
      end
      expect(payload.fetch("markdown")).not_to include("Long navigation destination", "Sort by newest")
      expect(payload.fetch("markdown")).not_to include("/related/")
      expect(payload.fetch("html")).not_to include("Long navigation destination")
    end
  end
end
