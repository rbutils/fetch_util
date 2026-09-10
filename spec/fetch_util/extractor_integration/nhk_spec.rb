# frozen_string_literal: true

RSpec.describe 'FetchUtil NHK extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts NHK news articles without homepage-list chrome or short_extraction' do
    expect_fixture_article(
      url: 'https://www3.nhk.or.jp/news/html/20260708/k10015171421000.html',
      fixture_path: File.expand_path('../../fixtures/nhk_article.html', __dir__),
      includes: [
        '大型で非常に強い台風9号は10日・金曜日から11日・土曜日ごろにかけて',
        '注目ワード'
      ],
      excludes: [
        '新着ニュース',
        '各地のニュース',
        '天気予報・防災情報'
      ],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'owns the headed article instead of a preceding alert and flags a materialized excerpt' do
    html = <<~HTML
      <!doctype html>
      <html lang="ja">
        <head><title>台風9号 沖縄 先島諸島に接近へ | NHKニュース</title></head>
        <body>
          <main>
            <div><div><div><div>
              <h2>JUST IN</h2>
              <p>別の記事についての速報です。これは対象記事の本文ではなく、先頭に表示されるニュース通知です。</p>
              <p>対象記事とは無関係な追加情報を含むため、抽出結果から除外される必要があります。</p>
            </div></div></div></div>
            <section>
              <div>
                <h1>台風9号 沖縄 先島諸島に接近へ</h1>
                <div>2026年7月8日 6:23</div>
                <p>大型で非常に強い台風9号は、非常に強い勢力を維持したまま沖縄県の先島諸島にかなり近づく見込みです。</p>
                <p>沖縄県ではしだいに風が強まり先島諸島では10日以…</p>
              </div>
              <aside><h2>深掘りコンテンツ</h2><a href="/unrelated">別の記事を読む</a></aside>
            </section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www3.nhk.or.jp/news/html/20260708/k10015171421000.html', html) do |payload|
      expect(payload['markdown']).to include('大型で非常に強い台風9号は')
      expect(payload['markdown']).not_to include('JUST IN', '深掘りコンテンツ', '別の記事を読む')
      expect_warnings(payload, include: 'truncated_content')
      expect(payload['suspect']).to be(true)
    end
  end
end
