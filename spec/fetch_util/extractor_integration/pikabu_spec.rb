# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts Pikabu story content instead of comments" do
    html = <<~HTML
      <html lang="ru">
        <head>
          <title>Пожалуй, хватит на сегодня интернета | Пикабу</title>
          <meta property="og:site_name" content="Пикабу">
          <meta name="description" content="Видео пост на Пикабу">
        </head>
        <body>
          <main class="main__inner">
            <div class="page-story" data-story-id="14125196" data-story-username="rahatlykym">
              <section class="story__main">
                <header class="story__header">
                  <a class="story__user-link user__nick" href="https://pikabu.ru/@rahatlykym">rahatlykym</a>
                  <a class="story__datetime-link" href="/new/06-07-2026">15 часов назад</a>
                  <h1 class="story__title"><span class="story__title-link">Пожалуй, хватит на сегодня интернета</span><span class="story-title-icons">Скопировать ссылку на пост</span></h1>
                </header>
                <div class="story__content story__typography">
                  <div class="story__content-inner">
                    <div class="story-block story-block_type_video">
                      <div data-role="player" data-type="video-file" poster="https://cs18.pikabu.ru/s/2026/07/06/10/video-poster.jpg">
                        <div data-role="player-controls"><button>pause</button><span>00:05 / 00:10</span></div>
                        <video src="blob:https://pikabu.ru/example"></video>
                        <a href="/video/story/pozhaluy_khvatit_na_segodnya_interneta_14125196/1688958">Перейти к видео</a>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="story__tags">
                  <a class="tags__tag" href="/tag/Видео/hot">Видео</a>
                  <a class="tags__tag" href="/tag/Короткие%20видео/hot">Короткие видео</a>
                </div>
                <footer class="story__footer"><a class="story__comments-link" href="#comments">215</a></footer>
              </section>
            </div>
            <div id="comments" class="comments__nav-point"></div>
            <section class="comments">
              <div id="comment_397677707" class="comment" data-id="397677707">
                <p>13 часов назад</p>
                <p>Странно, но эта футболка сухая и совсем не пахнет</p>
                <button>Ещё 0 раскрыть ветку (2)</button>
              </div>
            </section>
            <aside class="sidebar">Пикабу Игры +1000 бесплатных онлайн игр</aside>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://pikabu.ru/story/pozhaluy_khvatit_na_segodnya_interneta_14125196", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("# Пожалуй, хватит на сегодня интернета")
      expect(payload["markdown"]).to include("Перейти к видео")
      expect(payload["markdown"]).to include("Короткие видео")
      expect(payload["markdown"]).not_to include("Странно, но эта футболка сухая")
      expect(payload["markdown"]).not_to include("Пикабу Игры")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end
end
