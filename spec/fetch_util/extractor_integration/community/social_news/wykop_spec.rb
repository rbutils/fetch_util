# frozen_string_literal: true

RSpec.describe "Wykop social feeds" do
  include_context "extractor integration helpers"

  def wykop_home_fixture
    cards = (1..16).map do |number|
      extras = number == 16 ? '<img src="javascript:unsafeMedia()" alt="Story 16 image"><span class="promoted">Wykop Poleca</span>' : ""
      <<~HTML
        <section class="link-block stream-home" id="link-#{number}">
          <h2 class="heading"><a href="/link/#{number}/story-#{number}">Wykop story #{number} with a meaningful title</a></h2>
          <p class="description">Summary for Wykop story #{number}.</p>
          <span class="author">author#{number}</span>
          <time datetime="2026-07-10T#{format("%02d", number)}:00:00Z">#{number} hours ago</time>
          <span class="score">#{number * 3} points</span>
          <a class="comment-counter" href="/link/#{number}/story-#{number}#comments">#{number} replies</a>
          <span class="tag">tag#{number}</span>
          #{extras}
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

  def wykop_headline_fixture
    cards = [
      "Kamil Stoch zwycięża w kwalifikacjach",
      "Robert Lewandowski z ważnym golem",
      "Iga Świątek awansuje do finału",
      "Nowe mieszkania drożeją w całym kraju",
      "Reprezentacja Polski poznała rywali"
    ].each_with_index.map do |title, index|
      <<~HTML
        <section class="link-block stream-home" id="link-headline-#{index}">
          <h2><a href="/link/#{index + 1}/headline-#{index + 1}">#{title}</a></h2>
        </section>
      HTML
    end.join

    "<html lang='pl'><head><title>Wykop</title></head><body><main>#{cards}</main></body></html>"
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
      expect(markdown).to include("Summary for Wykop story 16", "author16", "16 replies", "Story 16 image", "Wykop Poleca")
      expect(markdown).not_to include("javascript:")
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
      expect(payload["title"]).to eq("Nieruchomości")
      expect(payload["warnings"]).not_to include("url_content_mismatch")
      expect(payload["markdown"].lines.grep(/^- \[/).length).to eq(3)
      expect(payload["markdown"]).to match(/Pierwszy wpis.*Raport cen mieszkań.*Trzeci wpis/m)
      expect(payload["markdown"]).to include("domownik", "283", "example.org")
    end
  end

  it "keeps an interaction-free headline collection as a credible generic list" do
    with_url_page("https://wykop.pl/", wykop_headline_fixture) do |page|
      source = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload["contentType"]).to eq("list")
      expect(payload["socialKind"]).to be_nil
      (1..5).each do |number|
        expect(payload.fetch("markdown")).to include("https://wykop.pl/link/#{number}/headline-#{number}")
      end
      expect(payload["warnings"]).not_to include("url_content_mismatch")
      expect(payload["suspect"]).to eq(false)
      expect(page.evaluate('document.body.innerHTML')).to eq(source)
    end
  end

  it "does not treat incidental navigation as a primary headline collection" do
    links = (1..5).map do |number|
      %(<h2><a href="/menu/#{number}">English navigation resource #{number}</a></h2>)
    end.join
    html = <<~HTML
      <html lang="pl"><head><title>Wykop</title></head><body><main>
        <nav>#{links}</nav>
        <p>English account navigation, search instructions, and site controls fill this shell without any primary news records.</p>
        <p>These links are secondary routes, while the main public headline collection has not loaded on this page.</p>
      </main></body></html>
    HTML

    with_url_page("https://wykop.pl/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload["warnings"]).to include("url_content_mismatch")
    end
  end

  it "keeps the not-found warning for a short response with misleading headline links" do
    html = <<~HTML
      <html lang="pl"><head><title>Page not found</title></head><body><main>
        <h1>Page not found</h1><p>Sorry, we could not find the page you were looking for.</p>
        <section>
          <h2><a href="/link/1">Recent news entry one</a></h2>
          <h2><a href="/link/2">Recent news entry two</a></h2>
          <h2><a href="/link/3">Recent news entry three</a></h2>
        </section>
      </main></body></html>
    HTML

    with_url_page("https://wykop.pl/", html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "infers the same structural feed without host ownership" do
    with_url_page("https://example.test/tag/nieruchomosci", wykop_home_fixture) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload).to include(
        "contentType" => "social",
        "socialKind" => "feed",
        "platform" => "Example"
      )
    end
  end
end
