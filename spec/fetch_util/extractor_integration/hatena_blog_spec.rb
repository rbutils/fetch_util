# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts Hatena Blog entry content instead of sidebar intro text" do
    html = <<~HTML
      <html lang="ja">
        <head>
          <title>今週のはてなブログランキング〔2026年7月第1週〕 - 週刊はてなブログ</title>
          <meta property="og:site_name" content="週刊はてなブログ">
          <meta property="article:published_time" content="2026-07-06T12:00:00+09:00">
        </head>
        <body>
          <aside class="hatena-module hatena-module-about">
            <p class="module-about-description">週刊はてなブログは「はてなブログ」で書かれたさまざまなブログを、いろんな切り口で紹介するメディアです。</p>
            <a href="/about">詳しく見る</a>
          </aside>
          <article class="entry hentry">
            <header class="entry-header">
              <h1 class="entry-title"><a class="entry-title-link" href="/entry/2026/07/06/120000">今週のはてなブログランキング〔2026年7月第1週〕</a></h1>
            </header>
            <div class="entry-content">
              <p>はてなブログ独自の集計による人気記事のランキング。2026年6月28日（日）から2026年7月4日（土）〔2026年7月第1週〕のトップ30です。</p>
              <h2>タイトル／著者とブックマーク</h2>
              <ol>
                <li><a href="https://example.hateblo.jp/entry/ranking-1">週刊文春の佐藤二朗「ハラスメント」記事に何が書かれていたか</a> - rabbitbeatの日記 by id:rabbitbeat</li>
                <li><a href="https://example.hatenablog.com/entry/ranking-2">反移民の極右映画『Citizen Vigilante』を観たので解説するよ</a> - 破壊屋ブログ by id:hakaiya</li>
                <li><a href="https://example.hatenablog.net/entry/ranking-3">ClaudeCodeとObsidianで設計・作業メモを残す</a> - 虎の穴ラボ技術ブログ by id:toranoana-lab</li>
              </ol>
              <p>このランキングは、はてなブックマーク数などをもとに週刊はてなブログ編集部が集計しています。</p>
            </div>
            <footer class="entry-footer">
              <span class="author"><a href="/hatenablog/">はてなブログ</a></span>
              <div class="related-entries">You might also like 今週のはてなブログランキング〔2026年6月第4週〕</div>
            </footer>
          </article>
        </body>
      </html>
    HTML

    extract_from_url("https://blog.hatenablog.com/entry/2026/07/06/120000", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("# 今週のはてなブログランキング〔2026年7月第1週〕")
      expect(payload["markdown"]).to include("はてなブログ独自の集計による人気記事のランキング")
      expect(payload["markdown"]).to include("ClaudeCodeとObsidianで設計・作業メモを残す")
      expect(payload["markdown"]).not_to include("詳しく見る")
      expect(payload["markdown"]).not_to include("You might also like")
      expect_warnings(payload, exclude: %w[short_extraction empty_extraction url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end
end
