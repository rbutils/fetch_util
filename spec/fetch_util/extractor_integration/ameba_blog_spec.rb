# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts Ameba Blog article bodies without multi-topic false positives" do
    html = <<~HTML
      <html lang="ja">
        <head>
          <title>【2026】久世福商店 夏の福袋を徹底紹介！人気商品8点入りのお得な中身とは？ | 琴子のハッピーバッグでごきげんな暮らし♪</title>
          <meta property="og:site_name" content="Ameba Blog">
          <meta property="article:published_time" content="2026-07-04T04:00:17+09:00">
        </head>
        <body>
          <div id="app">
            <nav>ホーム ピグ アメブロ 芸能人ブログ 人気ブログ</nav>
            <div class="skin-blogBody">
              <main id="main" class="skin-blogMain skinMainArea">
                <article class="skin-entry js-entryWrapper">
                  <h1 class="skin-entryTitle"><a class="skinArticleTitle" href="/happy-happybag/entry-12971651517.html">【2026】久世福商店 夏の福袋を徹底紹介！人気商品8点入りのお得な中身とは？</a></h1>
                  <time datetime="2026-07-04T04:00:17+09:00">2026年07月04日 04時00分17秒</time>
                  <div class="skin-entryThemes">テーマ：2026 夏の福袋</div>
                  <div id="entryBody" class="skin-entryBody _3NmYViIm">
                    <p>こんにちは♪ お得情報を探しながら毎日を楽しんでいる琴子です♡</p>
                    <p>今回は久世福商店の「2026夏の福袋」をご紹介します♪</p>
                    <div data-toc>
                      <a href="#84lp">久世福商店 夏の福袋2026とは？</a>
                      <a href="#7lpl">今回入っているのはこちら♪</a>
                      <a href="#9bw8">気になるセット内容を紹介♪</a>
                      <a href="#7z3c">こんな方におすすめ！</a>
                      <a href="#robq">販売情報まとめ</a>
                      <a href="#oaoh">楽天で買えるお得な福袋</a>
                      <a href="#">目次を開く</a>
                    </div>
                    <h2 id="84lp">久世福商店 夏の福袋2026とは？</h2>
                    <p>久世福商店で人気の定番商品に、夏限定らしい爽やかな商品を組み合わせたオンライン限定福袋が登場しました。</p>
                    <h2 id="7lpl">福袋の内容は全8点！</h2>
                    <p>万能だしやご飯のお供、爽やかな飲み物まで、家族で楽しみやすい商品がそろっています。</p>
                    <p><img src="https://stat100.ameba.jp/blog/ucs/img/char/char3/530.png" alt="四角オレンジ">送料込みで購入できるので、気になっていた商品をまとめて試したい方にもぴったりです。</p>
                    <h2 id="9bw8">気になるセット内容を紹介♪</h2>
                    <p>毎日の食卓に使いやすい定番品が中心で、初めて久世福商店を試す人にもおすすめできる内容です。</p>
                    <h2 id="7z3c">こんな方におすすめ！</h2>
                    <p>夏の贈り物や自宅用のお楽しみ袋を探している方に向いた、満足感のあるセットです。</p>
                    <h2 id="robq">販売情報まとめ</h2>
                    <p>オンライン限定で数量には限りがあります。気になる方は早めのチェックがおすすめです。</p>
                  </div>
                </article>
              </main>
              <aside id="subA" class="skin-blogSubA">
                <div id="profile" class="skin-widget">プロフィール 琴子 猫とマリメッコとお得が好き！</div>
                <div id="recentEntries" class="skin-widget">最新の記事 【ベローチェ夏の福袋】40周年記念！黒ねこサマーバッグ2026を購入レビュー♪</div>
              </aside>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url("https://ameblo.jp/happy-happybag/entry-12971651517.html", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("# 【2026】久世福商店 夏の福袋を徹底紹介！人気商品8点入りのお得な中身とは？")
      expect(payload["markdown"]).to include("久世福商店で人気の定番商品に、夏限定らしい爽やかな商品")
      expect(payload["markdown"]).to include("オンライン限定で数量には限りがあります")
      expect(payload["markdown"]).not_to include("目次を開く")
      expect(payload["markdown"]).not_to include("四角オレンジ")
      expect(payload["markdown"]).not_to include("プロフィール 琴子")
      expect_warnings(payload, exclude: %w[multi_topic_page empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end
end
