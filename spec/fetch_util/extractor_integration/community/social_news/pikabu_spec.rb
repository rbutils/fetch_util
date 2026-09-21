# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "classifies a Pikabu story and preserves every visible comment" do
    comments = (1..12).map do |index|
      <<~HTML
        <div id="comment_#{index}" class="comment" data-id="#{index}">
          <a class="comment__user" href="https://pikabu.ru/@reader#{index}">reader#{index}</a>
          <p>Visible reply #{format("%02d", index)} with source-owned discussion text.</p>
        </div>
      HTML
    end.join
    html = <<~HTML
      <html lang="ru">
        <head>
          <title>Пожалуй, хватит на сегодня интернета | Пикабу</title>
          <meta property="og:site_name" content="Пикабу">
          <meta name="description" content="Короткая видеозапись на Пикабу">
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
                     <p>Основной текст публикации остается рядом с автором, тегами и медиа.</p>
                     <div class="story-block story-block_type_video">
                      <div data-role="player" data-type="video-file" poster="https://cs18.pikabu.ru/s/2026/07/06/10/video-poster.jpg">
                        <div data-role="player-controls"><button>pause</button><span>00:05 / 00:10</span></div>
                  <video src="blob:https://pikabu.ru/example"></video>
                  <a href="/video/story/pozhaluy_khvatit_na_segodnya_interneta_14125196/1688958">Открыть видео</a>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="story__tags">
                  <a class="tags__tag" href="/tag/Видео/hot">Видео</a>
                   <a class="tags__tag" href="/tag/Короткие%20видео/hot">Короткая запись</a>
                </div>
                <footer class="story__footer"><a class="story__comments-link" href="#comments">215</a></footer>
              </section>
            </div>
            <div id="comments" class="comments__nav-point"></div>
            <section class="comments">
              #{comments}
            </section>
             <aside class="sidebar">Пикабу Игры +1000 бесплатных развлечений</aside>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://pikabu.ru/story/pozhaluy_khvatit_na_segodnya_interneta_14125196", html) do |payload|
      expect_content_type(payload, "social")
      expect(payload).to include("socialKind" => "post", "platform" => "Pikabu", "handle" => "rahatlykym")
      expect(payload.values_at("replyCount", "community", "score")).to all(be_nil)
      expect(payload["markdown"]).to include("# Пожалуй, хватит на сегодня интернета")
      expect(payload["markdown"]).to include("Основной текст публикации")
      expect(payload["markdown"]).to include("![Video poster](https://cs18.pikabu.ru/s/2026/07/06/10/video-poster.jpg)")
      expect(payload["markdown"]).to include("[Открыть видео](https://pikabu.ru/video/story/pozhaluy_khvatit_na_segodnya_interneta_14125196/1688958)")
      expect(payload["markdown"]).to include("Короткая запись")
      comment_texts = (1..12).map { |index| "Visible reply #{format("%02d", index)} with source-owned discussion text." }
      comment_texts.each { |text| expect(payload["markdown"].scan(text).length).to eq(1) }
      positions = comment_texts.map { |text| payload["markdown"].index(text) }
      expect(positions).to eq(positions.sort)
      expect(payload["markdown"]).not_to include("Пикабу Игры")
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end

  it "keeps a Pikabu homepage feed as a non-social list" do
    html = <<~HTML
      <html lang="ru">
        <head><title>Горячее | Пикабу</title></head>
        <body>
          <main class="stories feed">
            <h1>Горячее</h1>
            <article class="story"><h2><a href="/story/pervaya_istoriya_1">Первая интересная история дня</a></h2></article>
            <article class="story"><h2><a href="/story/vtoraya_istoriya_2">Вторая интересная история дня</a></h2></article>
            <article class="story"><h2><a href="/story/tretya_istoriya_3">Третья интересная история дня</a></h2></article>
            <article class="story"><h2><a href="/story/chetvertaya_istoriya_4">Четвертая интересная история дня</a></h2></article>
            <article class="story"><h2><a href="/story/pyataya_istoriya_5">Пятая интересная история дня</a></h2></article>
            <article class="story"><h2><a href="/story/shestaya_istoriya_6">Шестая интересная история дня</a></h2></article>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://pikabu.ru/", html) do |payload|
      expect_content_type(payload, "list")
      expect(payload["socialKind"]).to be_nil
      expect(payload["markdown"]).to include("Первая интересная история дня")
    end
  end

  it "keeps a Pikabu not-found story shell interstitial" do
    html = <<~HTML
      <html><head><title>404 Page not found | Пикабу</title></head><body><main>
        <h1>Page not found</h1><p>The page you requested cannot be accessed.</p>
      </main></body></html>
    HTML

    extract_from_url("https://pikabu.ru/story/missing_1", html) do |payload|
      expect_content_type(payload, "interstitial")
      expect(payload["socialKind"]).to be_nil
      expect(payload["warnings"]).to include("not_found_interstitial")
    end
  end

  it "keeps a Pikabu login story shell interstitial" do
    html = <<~HTML
      <html><head><title>Log in | Пикабу</title></head><body><main>
        <h1>Log in to continue</h1><form><input type="email"><input type="password"></form>
      </main></body></html>
    HTML

    extract_from_url("https://pikabu.ru/story/private_1", html) do |payload|
      expect_content_type(payload, "interstitial")
      expect(payload["socialKind"]).to be_nil
      expect(payload["warnings"]).to include("auth_or_login_interstitial")
    end
  end
end
