# frozen_string_literal: true

RSpec.describe "FetchUtil stale content retrospectives" do
  include_context "extractor integration helpers"

  it "does not flag stale_content for retrospective history articles" do
    body = 6.times.map do |i|
      "<p>Täna ajaloos meenutab lõik #{i + 1} Tartu vanglas hukatud 193 inimese lugu ja selle ajaloolist tausta.</p>"
    end.join("\n")

    html = <<~HTML
      <html>
        <head>
          <title>TÄNA AJALOOS Tartu vanglas hukati 193 inimest</title>
          <meta property="article:published_time" content="2017-07-08T08:00:26+03:00">
          <meta property="article:section" content="Ajalugu">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"TÄNA AJALOOS Tartu vanglas hukati 193 inimest","datePublished":"2017-07-08T08:00:26+03:00"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>TÄNA AJALOOS Tartu vanglas hukati 193 inimest</h1>
              #{body}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://teadus.postimees.ee/4170789/tana-ajaloos-tartu-vanglas-hukati-193-inimest", html) do |page|
      payload = extract(page)
      expect(payload["warnings"]).not_to include("stale_content")
    end
  end

  it "does not flag stale_content for retrospective Japanese sports features" do
    body = 6.times.map do |i|
      "<p>この特集 #{i + 1} は当時を振り返る証言と背景をまとめ、公式戦初ホームランのその瞬間を改めてたどる。</p>"
    end.join("\n")

    html = <<~HTML
      <html>
        <head>
          <title>球児・大谷翔平の公式戦初ホームラン 対戦校監督が振り返るその瞬間</title>
          <meta property="article:published_time" content="2024-11-22T09:01:23+09:00">
          <meta property="article:section" content="スポーツ">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"球児・大谷翔平の公式戦初ホームラン 対戦校監督が振り返るその瞬間","datePublished":"2024-11-22T09:01:23+09:00"}
          </script>
        </head>
        <body>
          <main>
            <article>
              <h1>球児・大谷翔平の公式戦初ホームラン 対戦校監督が振り返るその瞬間</h1>
              #{body}
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page("https://www.asahi.com/articles/ASSCP3Q0FSCPUTQP01KM.html", html) do |page|
      payload = extract(page)
      expect(payload["warnings"]).not_to include("stale_content")
    end
  end
end
