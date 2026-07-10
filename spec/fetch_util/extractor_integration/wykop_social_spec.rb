# frozen_string_literal: true

RSpec.describe "Wykop social feeds" do
  include_context "extractor integration helpers"

  def wykop_home_fixture
    cards = (1..16).map do |number|
      <<~HTML
        <section class="link-block stream-home" id="link-#{number}">
          <h2 class="heading"><a href="/link/#{number}/story-#{number}">Wykop story #{number} with a meaningful title</a></h2>
          <p class="description">Summary for Wykop story #{number}.</p>
          <span class="author">author#{number}</span>
          <time datetime="2026-07-10T#{format('%02d', number)}:00:00Z">#{number} hours ago</time>
          <span class="score">#{number * 3} points</span>
          <a class="comment-counter" href="/link/#{number}/story-#{number}#comments">#{number} replies</a>
          <span class="tag">tag#{number}</span>
        </section>
      HTML
    end.join

    <<~HTML
      <html>
        <head><title>Hity Wykopu</title><meta property="og:site_name" content="Wykop.pl"></head>
        <body>
          <header><a href="/login">Zaloguj się</a></header>
          <main><section class="stream home-stream">#{cards}</section></main>
          <footer><a href="/zaloz-konto">Załóż konto</a></footer>
        </body>
      </html>
    HTML
  end

  it "preserves every homepage card in DOM order" do
    with_url_page("https://wykop.pl/", wykop_home_fixture) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include(
        "contentType" => "social",
        "socialKind" => "feed",
        "platform" => "Wykop"
      )
      markdown = payload["markdown"]
      expect(markdown.lines.grep(/^- \[/).length).to eq(16)
      positions = (1..16).map { |number| markdown.index("Wykop story #{number} with a meaningful title") }
      expect(positions).to all(be >= 0)
      expect(positions).to eq(positions.sort)
      expect(markdown).to include("Summary for Wykop story 16", "author16", "16 replies")
      expect(markdown).not_to include("Zaloguj się", "Załóż konto")
    end
  end

  it "extracts a mixed tag feed with its topic heading" do
    html = <<~HTML
      <html><head><title>Nieruchomości</title></head><body>
        <main class="tag-page"><h1>#nieruchomosci</h1><section class="stream">
          <section class="entry stream-tag" id="comment-1"><a class="permalink" href="/wpis/1">Pierwszy wpis o mieszkaniu</a><p class="body">Treść pierwszego wpisu.</p><span class="author">domownik</span><time>5 min temu</time><span class="score">9</span><span class="reply-count">2</span></section>
          <section class="link-block stream-tag" id="link-2"><h2><a href="/link/2/raport-cen">Raport cen mieszkań</a></h2><p class="description">Opis raportu.</p><span class="author">analityk</span><time>1 godz. temu</time><span class="score">283</span><a class="comment-counter">17</a><span class="source">example.org</span></section>
          <section class="entry stream-tag" id="comment-3"><a class="permalink" href="/wpis/3">Trzeci wpis o remoncie</a><p class="body">Treść trzeciego wpisu.</p><span class="author">remontujacy</span><time>2 godz. temu</time><span class="score">4</span><span class="reply-count">1</span></section>
        </section></main>
      </body></html>
    HTML

    with_url_page("https://wykop.pl/tag/nieruchomosci", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include(
        "contentType" => "social",
        "socialKind" => "feed",
        "platform" => "Wykop",
        "community" => "nieruchomosci"
      )
      expect(payload["title"]).to include("nieruchomosci")
      expect(payload["markdown"].lines.grep(/^- \[/).length).to eq(3)
      expect(payload["markdown"]).to match(/Pierwszy wpis.*Raport cen mieszkań.*Trzeci wpis/m)
      expect(payload["markdown"]).to include("domownik", "283", "example.org")
    end
  end

  it "does not claim Wykop-looking markup on another host" do
    with_url_page("https://example.test/tag/nieruchomosci", wykop_home_fixture) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["platform"]).not_to eq("Wykop")
      expect(payload["contentType"]).not_to eq("social")
    end
  end
end
