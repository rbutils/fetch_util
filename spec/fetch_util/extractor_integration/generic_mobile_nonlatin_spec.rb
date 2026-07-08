# frozen_string_literal: true

RSpec.describe 'FetchUtil generic mobile non-Latin extraction' do
  include_context 'extractor integration helpers'

  it 'extracts a Japanese mobile article without app chrome or short_extraction' do
    expect_fixture_article(
      url: 'https://news.example.test/asia/2026/07/09/tokyo-rail-revamp',
      fixture_path: File.expand_path('../../fixtures/generic_mobile_japanese_article.html', __dir__),
      includes: [
        '都市鉄道が新ダイヤを導入',
        '主要路線で新しいダイヤを導入した',
        '利用者は駅ごとの案内表示やスマートフォン通知を確認してほしい'
      ],
      excludes: [
        'アプリを開く',
        'AMPで表示中',
        '関連記事',
        '続きを読む'
      ],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial],
      suspect: false
    )
  end

  it 'extracts an Arabic AMP-style article without truncated_content or banner chrome' do
    expect_fixture_article(
      url: 'https://news.example.test/middle-east/2026/07/09/city-transport-update',
      fixture_path: File.expand_path('../../fixtures/generic_mobile_arabic_article.html', __dir__),
      includes: [
        'المدينة تعلن خطة نقل جديدة',
        'ستضيف رحلات إضافية',
        'وسيبدأ العمل بالخطة تدريجيا خلال الأسبوع المقبل'
      ],
      excludes: [
        'افتح التطبيق',
        'المواضيع ذات الصلة',
        'إشعارات الأخبار',
        'اقرأ المزيد'
      ],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial],
      suspect: false
    )
  end

  it 'extracts a Chinese mobile article from an AMP-style container without cleanup noise' do
    expect_fixture_article(
      url: 'https://news.example.test/china/2026/07/09/bridge-opening',
      fixture_path: File.expand_path('../../fixtures/generic_mobile_chinese_article.html', __dir__),
      includes: [
        '城市新桥今日通车',
        '新桥将两岸通勤时间缩短',
        '居民可以通过手机提示查看绕行信息'
      ],
      excludes: [
        '打开应用',
        '在应用中继续阅读',
        '相关阅读',
        '订阅通知'
      ],
      warning_excludes: %w[empty_extraction short_extraction truncated_content url_content_mismatch consent_interstitial],
      suspect: false
    )
  end
end
