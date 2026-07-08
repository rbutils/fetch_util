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
end
